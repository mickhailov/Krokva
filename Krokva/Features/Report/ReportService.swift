import Foundation

struct ReportService {
    typealias ProgressHandler = (ReportLoadingStage) async -> Void
    typealias SubProgressHandler = (Double) async -> Void

    /// Hard ceiling on how long a report may take. When it elapses, the in-flight
    /// fetch is cancelled: modules still running drop to "no data" and the report
    /// is assembled from whatever finished, so loading never exceeds this.
    static let timeout: Duration = .seconds(10)

    func report(
        for rawAddress: String,
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

        let fetchTask = Task { () -> AddressReport in
            if let winnipegProvider = provider as? WinnipegProvider {
                return await winnipegProvider.fetchReport(for: normalized, progress: progress, subProgress: subProgress)
            }
            return await provider.fetchReport(for: normalized)
        }
        // Watchdog: cancel the fetch once the timeout passes. If the fetch finishes
        // first, awaiting its value returns early and the watchdog is cancelled.
        let watchdog = Task {
            try? await Task.sleep(for: Self.timeout)
            fetchTask.cancel()
        }
        let report = await fetchTask.value
        watchdog.cancel()
        return report
    }
}
