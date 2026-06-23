import Foundation
import SwiftData

@MainActor
struct ReportService {
    typealias ProgressHandler = (ReportLoadingStage) async -> Void
    typealias SubProgressHandler = (Double) async -> Void

    /// Returns a fresh cached report for `rawAddress` without touching the network, or nil on
    /// a miss. Lets the UI open instantly (no loading animation) when a report is still warm.
    func cachedReport(for rawAddress: String, modelContext: ModelContext) -> AddressReport? {
        let registry = CityRegistry.shared
        guard let provider = registry.provider(for: rawAddress),
              provider.implementationState == .live else { return nil }
        let normalized = provider.addressNormalizer.normalize(rawAddress)
        return ReportCacheStore.read(providerID: provider.cityID, address: normalized, modelContext: modelContext)
    }

    func report(
        for rawAddress: String,
        modelContext: ModelContext? = nil,
        forceRefresh: Bool = false,
        progress: ProgressHandler? = nil,
        subProgress: SubProgressHandler? = nil
    ) async -> AddressReport {
        let registry = CityRegistry.shared
        await progress?(.normalizing)
        let provider = registry.provider(for: rawAddress) ?? WinnipegProvider()
        let normalized = provider.addressNormalizer.normalize(rawAddress)
        if provider.implementationState == .comingSoon {
            return .comingSoon(address: normalized, provider: provider)
        }

        // Serve from cache unless the caller explicitly asked for fresh data (pull-to-refresh).
        if let modelContext, !forceRefresh,
           let cached = ReportCacheStore.read(providerID: provider.cityID, address: normalized, modelContext: modelContext) {
            return cached
        }

        let report: AddressReport
        if let winnipegProvider = provider as? WinnipegProvider {
            report = await winnipegProvider.fetchReport(for: normalized, progress: progress, subProgress: subProgress)
        } else {
            report = await provider.fetchReport(for: normalized)
        }

        if let modelContext {
            ReportCacheStore.write(report, providerID: provider.cityID, address: normalized, modelContext: modelContext)
        }
        return report
    }
}
