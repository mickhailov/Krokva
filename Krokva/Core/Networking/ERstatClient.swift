import Foundation

struct ERstatClosuresResponse: Decodable {
    var attribution: String
    var closures: [ERstatClosure]
}

struct ERstatClosure: Decodable {
    var id: Int
    var name: String
    var city: String
    var province: String
    var status: String
    var message: String
    var updatedAt: Date?
    var expectedReopen: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case city
        case province
        case status
        case message
        case updatedAt = "updated_at"
        case expectedReopen = "expected_reopen"
    }

    var emergencyRoomStatus: EmergencyRoomStatus {
        EmergencyRoomStatus(
            id: id,
            name: name,
            city: city,
            province: province,
            status: status,
            message: message,
            updatedAt: updatedAt,
            expectedReopen: expectedReopen
        )
    }
}

final class ERstatClient {
    private let session: URLSession
    private let apiKey: String?
    private let decoder: JSONDecoder

    init(apiKey: String? = Bundle.main.erstatAPIKey) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        self.session = URLSession(configuration: configuration)
        self.apiKey = apiKey

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func closures(province: String?) async throws -> ERstatClosuresResponse? {
        guard let apiKey, !apiKey.isEmpty else { return nil }

        var components = URLComponents(string: "https://erstat.ca/api/v1/closures")
        if let province, !province.isEmpty {
            components?.queryItems = [URLQueryItem(name: "province", value: province)]
        }
        guard let url = components?.url else { throw OpenDataError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return nil }
        guard 200..<300 ~= http.statusCode else { throw OpenDataError.badResponse(http.statusCode) }
        return try decoder.decode(ERstatClosuresResponse.self, from: data)
    }
}

private extension Bundle {
    var erstatAPIKey: String? {
        guard let value = object(forInfoDictionaryKey: "ERstatAPIKey") as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
