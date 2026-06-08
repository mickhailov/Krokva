import Foundation

struct DossierService {
    typealias ProgressHandler = (DossierLoadingStage) async -> Void

    func dossier(for rawAddress: String, progress: ProgressHandler? = nil) async -> AddressDossier {
        let registry = CityRegistry.shared
        await progress?(.normalizing)
        let provider = registry.provider(for: rawAddress) ?? WinnipegProvider()
        let normalized = provider.addressNormalizer.normalize(rawAddress)
        if provider.implementationState == .comingSoon {
            return .comingSoon(address: normalized, provider: provider)
        }
        if let winnipegProvider = provider as? WinnipegProvider {
            return await winnipegProvider.fetchDossier(for: normalized, progress: progress)
        }
        return await provider.fetchDossier(for: normalized)
    }
}
