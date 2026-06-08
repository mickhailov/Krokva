import Foundation

enum PropertyPermitCategory: String, CaseIterable, Codable, Identifiable {
    case electrical = "Electrical Work"
    case plumbing = "Plumbing Work"
    case hvac = "HVAC / Mechanical"
    case basement = "Basement Development"
    case garage = "Garage Construction"
    case addition = "Addition / Expansion"
    case structural = "Structural Work"
    case renovation = "Renovation"
    case demolition = "Demolition"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .electrical: "bolt.fill"
        case .plumbing: "drop.fill"
        case .hvac: "snowflake"
        case .basement: "house.fill"
        case .garage: "car.fill"
        case .addition: "building.2.fill"
        case .structural: "bricks"
        case .renovation: "hammer.fill"
        case .demolition: "exclamationmark.triangle.fill"
        }
    }
}

struct PropertyPermitRecord: Identifiable, Codable, Hashable {
    var id: String
    var permitNumber: String?
    var source: String
    var permitType: String
    var category: PropertyPermitCategory
    var issueDate: Date?
    var status: String?
    var description: String?
    var address: String
    // Detail fields extracted from the trade / building permit datasets.
    var workType: String?
    var workDone: String?
    var performedBy: String?
    var contractor: String?
    var appliedDate: Date?
    var completedDate: Date?
    var parentPermitNumber: String?
    var dwellingUnitsDelta: Int?
    var majorProject: Bool?

    var year: Int? {
        issueDate.map { Calendar.current.component(.year, from: $0) }
    }

    /// True when the work was filed by the homeowner rather than a licensed contractor.
    var isHomeownerFiled: Bool {
        performedBy?.localizedCaseInsensitiveContains("homeowner") == true
    }
}

struct PermitHistoryAnalytics: Equatable {
    var firstPermitYear: Int?
    var mostRecentPermitYear: Int?
    var permitCount: Int
    var majorRenovationDetected: Bool
    var electricalPermitDetected: Bool
    var plumbingPermitDetected: Bool
    /// Number of permits filed by a homeowner rather than a licensed contractor.
    var homeownerFiledCount: Int
    var homeownerFiledDetected: Bool { homeownerFiledCount > 0 }
}

struct PermitHistoryResult {
    var permits: [PropertyPermitRecord]
    var categories: [PropertyPermitCategory]
    var groupedByYear: [(year: Int, permits: [PropertyPermitRecord])]
    var analytics: PermitHistoryAnalytics
    var summary: String
    var attribution: String
}

enum PermitAnalyticsEngine {
    static func analyze(_ permits: [PropertyPermitRecord]) -> PermitHistoryAnalytics {
        let years = permits.compactMap(\.year)
        let categories = Set(permits.map(\.category))
        return PermitHistoryAnalytics(
            firstPermitYear: years.min(),
            mostRecentPermitYear: years.max(),
            permitCount: permits.count,
            majorRenovationDetected: categories.contains(.addition) || categories.contains(.structural) || categories.contains(.basement) || categories.contains(.garage),
            electricalPermitDetected: categories.contains(.electrical),
            plumbingPermitDetected: categories.contains(.plumbing),
            homeownerFiledCount: permits.filter(\.isHomeownerFiled).count
        )
    }

    static func categories(from permits: [PropertyPermitRecord]) -> [PropertyPermitCategory] {
        PropertyPermitCategory.allCases.filter { category in
            permits.contains { $0.category == category }
        }
    }

    static func groupedByYear(_ permits: [PropertyPermitRecord]) -> [(year: Int, permits: [PropertyPermitRecord])] {
        let grouped = Dictionary(grouping: permits) { $0.year ?? 0 }
        return grouped
            .filter { $0.key > 0 }
            .map { year, permits in
                (year, permits.sorted { ($0.issueDate ?? .distantPast) > ($1.issueDate ?? .distantPast) })
            }
            .sorted { $0.year > $1.year }
    }

    static func summary(for permits: [PropertyPermitRecord]) -> String {
        guard !permits.isEmpty else {
            return "No renovation permits were found for this property."
        }
        let categories = categories(from: permits)
        let readable = categories.prefix(4).map { $0.rawValue.lowercased() }
        if readable.isEmpty {
            return "Official permit records indicate permitted work has been recorded for this property."
        }
        let categoryText = list(readable)
        var sentence = "Official permit records indicate \(categoryText) have been performed on this property."
        let homeownerCount = permits.filter(\.isHomeownerFiled).count
        if homeownerCount > 0 {
            let permitWord = homeownerCount == 1 ? "permit was" : "permits were"
            sentence += " \(homeownerCount) \(permitWord) filed by a homeowner rather than a licensed contractor."
        }
        return sentence
    }

    static func category(for text: String) -> PropertyPermitCategory {
        let value = text.lowercased()
        if value.contains("electrical") || value.contains("wiring") || value.contains("service upgrade") { return .electrical }
        if value.contains("plumb") || value.contains("water") || value.contains("sewer") { return .plumbing }
        if value.contains("mechanical") || value.contains("hvac") || value.contains("furnace") || value.contains("air condition") || value.contains("ac ") { return .hvac }
        if value.contains("basement") { return .basement }
        if value.contains("garage") { return .garage }
        if value.contains("addition") || value.contains("expand") || value.contains("extension") { return .addition }
        if value.contains("structural") || value.contains("foundation") || value.contains("beam") { return .structural }
        if value.contains("demolition") || value.contains("demo") { return .demolition }
        return .renovation
    }

    /// Maps a raw `work_type` value into a human-readable description of what was done.
    /// Trade permits (electrical / plumbing / mechanical) share this field, so phrasing stays generic.
    static func workDone(from rawWorkType: String?) -> String? {
        guard let raw = rawWorkType?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let key = raw.lowercased()
        let known: [String: String] = [
            "service only": "Service upgrade",
            "rewire": "Full rewire",
            "additional wiring": "Additional wiring",
            "wire bldg alteration": "Wiring alteration",
            "wire new bldg": "New building wiring",
            "other electrical": "Other electrical work",
            "repair": "Repair",
            "fire repair": "Fire-damage repair",
            "air conditioner": "Air conditioner",
            "heating, ventilation, and air conditioning (hvac)": "HVAC",
            "hvac": "HVAC",
            "pool/hot tub": "Pool / hot tub",
            "lower level": "Basement / lower level",
            "garage/acc. struct.": "Garage / accessory structure",
            "sfd new": "New single-family dwelling",
            "single-family dwelling new": "New single-family dwelling",
            "sfd addition": "Addition",
            "temporary installation": "Temporary installation"
        ]
        if let mapped = known[key] { return mapped }
        // Fallback: expand common abbreviations and tidy casing.
        return raw
            .replacingOccurrences(of: "Acc. Struct.", with: "Accessory Structure")
            .replacingOccurrences(of: "SFD", with: "Single-Family Dwelling")
            .replacingOccurrences(of: "Bldg", with: "Building")
    }

    private static func list(_ values: [String]) -> String {
        guard let first = values.first else { return "" }
        if values.count == 1 { return first }
        if values.count == 2 { return "\(values[0]) and \(values[1])" }
        return "\(values.dropLast().joined(separator: ", ")), and \(values.last ?? first)"
    }
}
