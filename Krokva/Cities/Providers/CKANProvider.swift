import Foundation

class CKANProvider {
    let baseURL: URL
    let client: OpenDataClient

    init(baseURL: URL, client: OpenDataClient = OpenDataClient()) {
        self.baseURL = baseURL
        self.client = client
    }

    func packageShowURL(id: String) throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/3/action/package_show"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: id)]
        guard let url = components?.url else { throw OpenDataError.invalidURL }
        return url
    }
}
