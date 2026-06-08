import Foundation

final class CityRegistry {
    static let shared = CityRegistry()

    let providers: [any CityDataProvider]

    private init() {
        providers = [
            WinnipegProvider(),
            CalgaryProvider(),
            TorontoProvider(),
            EdmontonProvider(),
            VancouverProvider(),
            OttawaProvider()
        ]
    }

    func provider(forCityName cityName: String) -> (any CityDataProvider)? {
        let normalized = cityName.lowercased()
        return providers.first {
            normalized.contains($0.cityID) || normalized.contains($0.displayName.lowercased().split(separator: ",").first.map(String.init) ?? "")
        }
    }

    func provider(for address: String) -> (any CityDataProvider)? {
        provider(forCityName: address)
    }
}
