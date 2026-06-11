import Foundation
import SwiftData

@MainActor
protocol PermitHistoryService {
    func history(for report: AddressReport, modelContext: ModelContext, forceRefresh: Bool) async -> PermitHistoryResult
}

@MainActor
struct WinnipegPermitHistoryService: PermitHistoryService {
    private let provider = SocrataProvider(domain: "data.winnipeg.ca")
    private let buildingPermitsDataset = "it4w-cpf4"
    private let tradePermitsDataset = "urbd-qygv"
    private let attribution = "Contains information licensed under the Open Government Licence - Winnipeg."
    private let cacheTTL: TimeInterval = 60 * 60 * 24 * 7

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func history(for report: AddressReport, modelContext: ModelContext, forceRefresh: Bool = false) async -> PermitHistoryResult {
        // Bump the schema version whenever PropertyPermitRecord gains fields so stale
        // payloads (which decode with the new fields nil) are bypassed automatically.
        let cacheKey = "permit-history:v2:\(report.providerID):\(report.address.displayAddress.lowercased())"
        if !forceRefresh, let cached = readCache(key: cacheKey, modelContext: modelContext) {
            return result(from: cached)
        }

        guard report.providerID == "winnipeg" else {
            return result(from: [])
        }

        async let building = fetchBuildingPermits(for: report)
        async let trade = fetchTradePermits(for: report)
        let permits = await (building + trade)
            .sorted { ($0.issueDate ?? .distantPast) > ($1.issueDate ?? .distantPast) }
        writeCache(permits, key: cacheKey, modelContext: modelContext)
        return result(from: permits)
    }

    private func result(from permits: [PropertyPermitRecord]) -> PermitHistoryResult {
        PermitHistoryResult(
            permits: permits,
            categories: PermitAnalyticsEngine.categories(from: permits),
            groupedByYear: PermitAnalyticsEngine.groupedByYear(permits),
            analytics: PermitAnalyticsEngine.analyze(permits),
            summary: PermitAnalyticsEngine.summary(for: permits),
            attribution: attribution
        )
    }

    private func readCache(key: String, modelContext: ModelContext) -> [PropertyPermitRecord]? {
        let descriptor = FetchDescriptor<CachedDataset>(
            predicate: #Predicate { $0.key == key }
        )
        guard let cached = try? modelContext.fetch(descriptor).first,
              cached.expiresAt > .now,
              let permits = try? decoder.decode([PropertyPermitRecord].self, from: cached.payload) else {
            return nil
        }
        return permits
    }

    private func writeCache(_ permits: [PropertyPermitRecord], key: String, modelContext: ModelContext) {
        guard let payload = try? encoder.encode(permits) else { return }
        let descriptor = FetchDescriptor<CachedDataset>(
            predicate: #Predicate { $0.key == key }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            cached.payload = payload
            cached.expiresAt = Date(timeIntervalSinceNow: cacheTTL)
            cached.updatedAt = .now
        } else {
            modelContext.insert(CachedDataset(key: key, payload: payload, expiresAt: Date(timeIntervalSinceNow: cacheTTL)))
        }
    }

    private func fetchBuildingPermits(for report: AddressReport) async -> [PropertyPermitRecord] {
        let rows = (try? await provider.fetch(buildingPermitsDataset, queryItems: [
            URLQueryItem(name: "$where", value: "\(addressWhereClause(for: report, streetField: "street_name")) AND issue_date >= '2000-01-01T00:00:00'"),
            URLQueryItem(name: "$order", value: "issue_date DESC"),
            URLQueryItem(name: "$limit", value: "100")
        ])) ?? []
        return rows.map { row in
            makeRecord(row: row, source: "Detailed Building Permit Data", defaultAddress: report.address.displayAddress)
        }
    }

    private func fetchTradePermits(for report: AddressReport) async -> [PropertyPermitRecord] {
        let rows = (try? await provider.fetch(tradePermitsDataset, queryItems: [
            URLQueryItem(name: "$where", value: "\(addressWhereClause(for: report, streetField: "street_name")) AND issue_date >= '2000-01-01T00:00:00'"),
            URLQueryItem(name: "$order", value: "issue_date DESC"),
            URLQueryItem(name: "$limit", value: "160")
        ])) ?? []
        return rows.map { row in
            makeRecord(row: row, source: "Trade Permits", defaultAddress: report.address.displayAddress)
        }
    }

    private func makeRecord(row: [String: Any], source: String, defaultAddress: String) -> PropertyPermitRecord {
        let permitType = row.string("permit_type") ?? row.string("permit_group") ?? "Permit"
        let workType = row.string("work_type")
        let subType = row.string("sub_type")
        let workDone = PermitAnalyticsEngine.workDone(from: workType)
        let description = [workDone, subType]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
        let combinedText = "\(permitType) \(workType ?? "") \(subType ?? "")"
        let address = row.string("address") ?? composeAddress(row: row) ?? defaultAddress
        let unitsDelta: Int? = {
            let created = row.int("dwelling_units_created") ?? 0
            let lost = row.int("dwelling_units_lost") ?? 0
            let delta = created - lost
            return delta == 0 ? nil : delta
        }()
        let majorProject = row.string("major_project").map { $0.localizedCaseInsensitiveContains("yes") }
        return PropertyPermitRecord(
            id: row.string("permit_number") ?? UUID().uuidString,
            permitNumber: row.string("permit_number"),
            source: source,
            permitType: permitType,
            category: PermitAnalyticsEngine.category(for: combinedText),
            issueDate: parseDate(row.string("issue_date")),
            status: row.string("status") ?? row.string("permit_status"),
            description: description.isEmpty ? nil : description,
            address: address,
            workType: workType,
            workDone: workDone,
            performedBy: subType,
            contractor: row.string("applicant_business_name"),
            appliedDate: parseDate(row.string("application_received_date")),
            completedDate: parseDate(row.string("final_date")),
            parentPermitNumber: row.string("parent_permit_number"),
            dwellingUnitsDelta: unitsDelta,
            majorProject: majorProject
        )
    }

    private func addressWhereClause(for report: AddressReport, streetField: String) -> String {
        let number = report.address.civicNumber.map(String.init) ?? report.property?.fullAddress.split(separator: " ").first.map(String.init) ?? ""
        let street = streetCore(report.address.streetName)
        let clauses = [
            number.isEmpty ? nil : "street_number='\(number)'",
            street.isEmpty ? nil : "upper(\(streetField))='\(escaped(street))'"
        ].compactMap { $0 }
        return clauses.isEmpty ? "1=0" : clauses.joined(separator: " AND ")
    }

    private func composeAddress(row: [String: Any]) -> String? {
        let parts = [
            row.string("street_number"),
            row.string("street_name"),
            row.string("street_type"),
            row.string("street_direction")
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func streetCore(_ name: String) -> String {
        name.replacingOccurrences(of: #"(?i)\s+(avenue|ave|av|street|st|road|rd|drive|dr|boulevard|blvd|crescent|cres|place|pl|way|bay|bv)\.?$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_CA")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter.date(from: value)
    }
}
