import Foundation

struct DataStatus: Sendable, Equatable {
    let totalRows: Int
    let lastUpdated: Date?
    let tableCount: Int
}

@MainActor
final class DataStatusService: ObservableObject {
    @Published var status: DataStatus?

    private static let url = URL(string: "http://3.99.123.190:8889/api/status")!

    func refresh() {
        Task {
            guard let status = try? await fetch() else { return }
            self.status = status
        }
    }

    private func fetch() async throws -> DataStatus {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)
        let (data, _) = try await session.data(from: Self.url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rows = json?["total_rows"] as? Int ?? 0
        let count = json?["table_count"] as? Int ?? 0
        var date: Date?
        if let iso = json?["last_updated"] as? String {
            date = ISO8601DateFormatter().date(from: iso)
        }
        return DataStatus(totalRows: rows, lastUpdated: date, tableCount: count)
    }
}
