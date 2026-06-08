import Foundation

class SocrataProvider {
    let domain: String
    let client: OpenDataClient

    init(domain: String, client: OpenDataClient = OpenDataClient()) {
        self.domain = domain
        self.client = client
    }

    func resourceURL(_ datasetID: String, queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/resource/\(datasetID).json"
        components.queryItems = queryItems
        guard let url = components.url else { throw OpenDataError.invalidURL }
        return url
    }

    func fetch(_ datasetID: String, queryItems: [URLQueryItem] = []) async throws -> [[String: Any]] {
        try await client.getJSON(url: resourceURL(datasetID, queryItems: queryItems))
    }
}
