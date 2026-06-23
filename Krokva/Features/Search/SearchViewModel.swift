import Foundation
import MapKit
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var completions: [MKLocalSearchCompletion] = []
    var detectedProvider: (any CityDataProvider)?
    var isLoading = false
    var loadingStage: ReportLoadingStage = .normalizing
    var loadingSubFraction: Double = 0
    var errorMessage: String?

    private let completer = AddressCompleter()
    private let service = ReportService()
    init() {
        completer.onUpdate = { [weak self] completions in
            self?.completions = completions
        }
        completer.searchRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 49.8954, longitude: -97.1385),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.55)
        )
    }

    func updateQuery(_ value: String) {
        query = value
        detectedProvider = CityRegistry.shared.provider(for: value)
        completer.queryFragment = value
    }

    func useExample() {
        updateQuery("196 Arnold Avenue, Winnipeg")
    }

    func cancelLoading() {
        isLoading = false
        loadingStage = .normalizing
    }

    func fetchReport(modelContext: ModelContext? = nil, forceRefresh: Bool = false) async -> AddressReport? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Warm cache hit: open instantly, skipping the loading animation entirely.
        if !forceRefresh, let modelContext, let cached = service.cachedReport(for: trimmed, modelContext: modelContext) {
            return cached
        }

        isLoading = true
        loadingStage = .normalizing
        errorMessage = nil
        defer { isLoading = false }

        return await service.report(for: trimmed, modelContext: modelContext, forceRefresh: forceRefresh, progress: { [weak self] stage in
            guard !Task.isCancelled else { return }
            await self?.setLoadingStage(stage)
        }, subProgress: { [weak self] fraction in
            guard !Task.isCancelled else { return }
            await self?.setLoadingSubFraction(fraction)
        })
    }

    private func setLoadingStage(_ stage: ReportLoadingStage) async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.28)) {
                loadingStage = stage
                loadingSubFraction = 0
            }
        }
    }

    private func setLoadingSubFraction(_ fraction: Double) async {
        await MainActor.run {
            loadingSubFraction = fraction
        }
    }
}

final class AddressCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var onUpdate: ([MKLocalSearchCompletion]) -> Void = { _ in }
    private let completer = MKLocalSearchCompleter()

    var queryFragment: String {
        get { completer.queryFragment }
        set { completer.queryFragment = newValue }
    }

    var searchRegion: MKCoordinateRegion {
        get { completer.region }
        set { completer.region = newValue }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let winnipeg = completer.results.filter { $0.subtitle.localizedCaseInsensitiveContains("Winnipeg") }
        onUpdate(Array(winnipeg.prefix(5)))
    }
}
