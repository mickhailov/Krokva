import Foundation

struct DataStatus: Sendable, Equatable {
    let totalRows: Int
    let lastUpdated: Date?
    let tableCount: Int
}

@MainActor
final class DataStatusService: ObservableObject {
    @Published var status: DataStatus?

    private static let url = URL(string: "https://krokva.144.217.5.174.sslip.io/api/status")!

    // One shared session — sessions hold their connection pools until invalidated,
    // and refresh() runs on every screen appearance.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
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
        let rows = json?["total_rows"] as? Int ?? 0
        let count = json?["table_count"] as? Int ?? 0
        var date: Date?
        if let iso = json?["last_updated"] as? String {
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
