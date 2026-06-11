import Foundation
import MapKit
import Observation
import SwiftUI

@Observable
final class SearchViewModel {
    var query = ""
    var completions: [MKLocalSearchCompletion] = []
    var detectedProvider: (any CityDataProvider)?
    var isLoading = false
    var loadingStage: ReportLoadingStage = .normalizing
    var errorMessage: String?

    private let completer = AddressCompleter()
    private let service = ReportService()
    private let stageDelay: UInt64 = 3_000_000_000

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

    func fetchReport() async -> AddressReport? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        isLoading = true
        loadingStage = .normalizing
        errorMessage = nil
        defer { isLoading = false }

        async let report = service.report(for: trimmed)
        await playFixedLoadingSequence()
        guard !Task.isCancelled else { return nil }
        await setLoadingStage(.assembling)
        try? await Task.sleep(nanoseconds: stageDelay)
        guard !Task.isCancelled else { return nil }
        return await report
    }

    private func playFixedLoadingSequence() async {
        let preFinalStages = ReportLoadingStage.allCases.filter { $0 != .assembling }
        for stage in preFinalStages {
            if Task.isCancelled { return }
            await setLoadingStage(stage)
            try? await Task.sleep(nanoseconds: stageDelay)
        }
    }

    private func setLoadingStage(_ stage: ReportLoadingStage) async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.28)) {
                loadingStage = stage
            }
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
