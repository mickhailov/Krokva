import Foundation

struct ReportService {
    typealias ProgressHandler = (ReportLoadingStage) async -> Void

    func report(for rawAddress: String, progress: ProgressHandler? = nil) async -> AddressReport {
        let registry = CityRegistry.shared
        await progress?(.normalizing)
        let provider = registry.provider(for: rawAddress) ?? WinnipegProvider()
        let normalized = provider.addressNormalizer.normalize(rawAddress)
        if provider.implementationState == .comingSoon {
            return .comingSoon(address: normalized, provider: provider)
        }
        if let winnipegProvider = provider as? WinnipegProvider {
            return await winnipegProvider.fetchReport(for: normalized, progress: progress)
        }
        return await provider.fetchReport(for: normalized)
    }
}
