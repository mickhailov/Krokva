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
    var loadingStage: DossierLoadingStage = .normalizing
    var errorMessage: String?

    private let completer = AddressCompleter()
    private let service = DossierService()
    private let stageDelay: UInt64 = 3_000_000_000

    init() {
        completer.onUpdate = { [weak self] completions in
            self?.completions = completions
        }
        completer.searchRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 56.1304, longitude: -106.3468),
            span: MKCoordinateSpan(latitudeDelta: 45, longitudeDelta: 75)
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

    func fetchDossier() async -> AddressDossier? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        isLoading = true
        loadingStage = .normalizing
        errorMessage = nil
        defer { isLoading = false }

        async let dossier = service.dossier(for: trimmed)
        await playFixedLoadingSequence()
        await setLoadingStage(.assembling)
        try? await Task.sleep(nanoseconds: stageDelay)
        return await dossier
    }

    private func playFixedLoadingSequence() async {
        let preFinalStages = DossierLoadingStage.allCases.filter { $0 != .assembling }
        for stage in preFinalStages {
            await setLoadingStage(stage)
            try? await Task.sleep(nanoseconds: stageDelay)
        }
    }

    private func setLoadingStage(_ stage: DossierLoadingStage) async {
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
        onUpdate(Array(completer.results.prefix(5)))
    }
}
