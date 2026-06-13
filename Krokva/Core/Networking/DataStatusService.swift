import Foundation

struct DataStatus: Sendable {
    let totalRows: Int
    let lastUpdated: Date?
    let tableCount: Int
}

@MainActor
final class DataStatusService: ObservableObject {
    @Published var status: DataStatus?

    private static let url = URL(string: "http://16.52.129.61:8889/api/status")!

    func refresh() {
        Task {
            guard let status = try? await fetch() else { return }
            self.status = status
        }
    }

    private func fetch() async throws -> DataStatus {
        let (data, _) = try await URLSession.shared.data(from: Self.url)
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
