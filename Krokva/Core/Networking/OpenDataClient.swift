import Foundation

enum OpenDataError: Error {
    case invalidURL
    case badResponse(Int)
}

final class OpenDataClient {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        // The self-hosted Socrata-compatible mirror can take 10-20 seconds for
        // aggregate/geospatial queries while it warms up or lacks city indexes.
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: configuration)
    }

    func getJSON(url: URL) async throws -> [[String: Any]] {
        do {
            return try await perform(url: url)
        } catch let error as URLError {
            // Only transport-level failures (timeout, connection lost) are worth a
            // single retry. HTTP error codes (badResponse) and decode errors will
            // just fail again, so those propagate without a wasted second request.
            guard error.code != .cancelled else { throw error }
            return try await perform(url: url)
        }
    }

    private func perform(url: URL) async throws -> [[String: Any]] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { return [] }
        guard 200..<300 ~= http.statusCode else { throw OpenDataError.badResponse(http.statusCode) }
        return (try JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }
}

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? {
        if let value = self[key] as? String { return value }
        if let value = self[key] { return "\(value)" }
        return nil
    }

    func int(_ key: String) -> Int? {
        if let value = self[key] as? Int { return value }
        if let value = self[key] as? String { return Int(value) }
        return nil
    }

    func double(_ key: String) -> Double? {
        if let value = self[key] as? Double { return value }
        if let value = self[key] as? Int { return Double(value) }
        if let value = self[key] as? String { return Double(value) }
        return nil
    }

    func bool(_ key: String) -> Bool {
        if let value = self[key] as? Bool { return value }
        if let value = self[key] as? String {
            return ["true", "yes", "1"].contains(value.lowercased())
        }
        if let value = self[key] as? Int { return value != 0 }
        return false
    }
}
