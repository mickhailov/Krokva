import SwiftData
import SwiftUI

struct FavoritesView: View {
    @Query(sort: \SavedAddress.savedAt, order: .reverse) private var saved: [SavedAddress]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedReport: AddressReport?
    @State private var showReport = false
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cleanBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerBar
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 20)

                        if saved.isEmpty {
                            emptyState
                        } else {
                            savedSection
                                .padding(.bottom, 32)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showReport) {
                if let d = selectedReport { ReportView(report: d) }
            }
            .overlay {
                if viewModel.isLoading {
                    LoadingScreenAnimation(
                        addressText: viewModel.query,
                        cityName: viewModel.detectedProvider?.displayName ?? "Winnipeg, MB",
                        stage: viewModel.loadingStage
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("KROKVA")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(
                        LinearGradient(colors: [.cleanSky, .cleanIndigo],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                Text("Favorites")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.cleanLabel)
                    .tracking(-0.8)
            }
            Spacer()
            if !saved.isEmpty {
                Text("\(saved.count)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.cleanLabel3)
            Text("No saved addresses")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.cleanLabel)
            Text("Tap the bookmark on any address in Discover to save it here.")
                .font(.system(size: 14))
                .foregroundStyle(Color.cleanLabel2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: Saved list

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CleanSectionHeader(title: "Saved")
                .padding(.horizontal, 16)

            CleanCard(padding: 0) {
                ForEach(Array(saved.enumerated()), id: \.element.savedAt) { idx, fav in
                    savedRow(fav: fav, index: idx, total: saved.count)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func savedRow(fav: SavedAddress, index: Int, total: Int) -> some View {
        Button(action: { openReport(for: fav) }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cleanAmberWash)
                        .frame(width: 42, height: 42)
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.cleanAmber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(fav.address)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                        .lineLimit(1)
                    Text(CityRegistry.shared.provider(for: fav.cityID)?.displayName ?? fav.cityID)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cleanLabel2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel3)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(fav)
            } label: {
                Label("Remove", systemImage: "bookmark.slash.fill")
            }
        }
        .background {
            if index < total - 1 {
                VStack {
                    Spacer()
                    Divider().padding(.leading, 70)
                }
            }
        }
    }

    // MARK: Navigation

    private func openReport(for fav: SavedAddress) {
        viewModel.updateQuery(fav.address)
        Task {
            guard let report = await viewModel.fetchReport() else { return }
            selectedReport = report
            showReport = true
        }
    }
}
