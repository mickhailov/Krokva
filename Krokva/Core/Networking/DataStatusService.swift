import Foundation

struct DataStatus: Sendable, Equatable {
    let totalRows: Int
    let lastUpdated: Date?
    let tableCount: Int
}

@MainActor
final class DataStatusService: ObservableObject {
    @Published var status: DataStatus?

    // The old self-hosted mirror's custom /api/status endpoint was decommissioned
    // 2026-07-05. CDS exposes an equivalent service summary at /v1/health (a `summary`
    // object with totalRows / datasetsEnabled / serverTime). It aggregates all datasets
    // so it can take ~10s — fine here since the badge loads async and animates in.
    private static let url = URL(string: "https://civic.144.217.5.174.sslip.io/v1/health")!

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }()

    func refresh() {
        Task {
            guard let status = try? await fetch() else { return }
            self.status = status
        }
    }

    private func fetch() async throws -> DataStatus {
        let (data, _) = try await Self.session.data(from: Self.url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let summary = json?["summary"] as? [String: Any]
        let rows = summary?["totalRows"] as? Int ?? 0
        let count = summary?["datasetsEnabled"] as? Int ?? 0
        var date: Date?
        if let iso = summary?["serverTime"] as? String {
            date = Self.parseISODate(iso)
        }
        return DataStatus(totalRows: rows, lastUpdated: date, tableCount: count)
    }

    /// The status API returns timestamps with fractional seconds
    /// (e.g. "2026-06-15T01:39:10.379874+00:00"), which a default
    /// ISO8601DateFormatter rejects. Try the fractional variant first.
    private static func parseISODate(_ iso: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: iso) { return date }
        return ISO8601DateFormatter().date(from: iso)
    }
}
