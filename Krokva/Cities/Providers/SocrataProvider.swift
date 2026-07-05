import Foundation

class SocrataProvider {
    let domain: String
    let client: OpenDataClient
    /// Tracks which report modules failed to load during the current report build, so cards
    /// can distinguish a loaded-but-empty dataset from a database error.
    let dataSourceHealth = DataSourceHealth()

    let scheme: String

    init(domain: String, scheme: String = "https", client: OpenDataClient = OpenDataClient()) {
        self.domain = domain
        self.scheme = scheme
        self.client = client
    }

    func resourceURL(_ datasetID: String, queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents()
        components.scheme = scheme
        // Split host and port if present (e.g. "16.52.129.61:8889")
        let parts = domain.split(separator: ":", maxSplits: 1)
        components.host = String(parts[0])
        if parts.count == 2, let port = Int(parts[1]) { components.port = port }
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
            // attribute it to the module currently being fetched before rethrowing. A
            // cancellation, however, is the report's 10-second timeout cutting the module
            // off — not a source error — so that module degrades to "no data", not an error.
            if !Task.isCancelled {
                await dataSourceHealth.recordCurrentModuleFailure()
            }
            throw error
        }
    }
}
