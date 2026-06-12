import Foundation

class SocrataProvider {
    let domain: String
    let client: OpenDataClient
    /// Tracks which report modules failed to load during the current report build, so cards
    /// can distinguish a loaded-but-empty dataset from a database error.
    let dataSourceHealth = DataSourceHealth()

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
        do {
            return try await client.getJSON(url: resourceURL(datasetID, queryItems: queryItems))
        } catch {
            // A thrown request is a transport/HTTP failure (an empty result returns []), so
            // attribute it to the module currently being fetched before rethrowing.
            await dataSourceHealth.recordCurrentModuleFailure()
            throw error
        }
    }
}
