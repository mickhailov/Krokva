import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \SavedAddress.savedAt, order: .reverse) private var saved: [SavedAddress]
    @Environment(\.modelContext) private var modelContext
    @Environment(ReportRouter.self) private var router
    @State private var viewModel = SearchViewModel()
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var notFoundAddress: String? = nil
    @FocusState private var searchFocused: Bool
    @StateObject private var dataStatus = DataStatusService()
    @State private var animatedRows: Double = 0
    @State private var animatedTables: Double = 0

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cleanBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .center, spacing: 0) {
                        if !searchFocused {
                            logoBanner
                                .padding(.bottom, 32)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        searchSection
                            .padding(.horizontal, 22)
                            .padding(.top, searchFocused ? 56 : 0)
                            .padding(.bottom, 16)

                        if !searchFocused && !saved.isEmpty {
                            savedSection
                                .padding(.top, 8)
                                .padding(.bottom, 40)
                                .transition(.opacity)
                        }
                    }
                    .padding(.bottom, 40)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: searchFocused)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if viewModel.isLoading {
                    LoadingScreenAnimation(
                        addressText: viewModel.query,
                        cityName: viewModel.detectedProvider?.displayName ?? "Winnipeg, MB",
                        stage: viewModel.loadingStage,
                        subStageFraction: viewModel.loadingSubFraction,
                        onCancel: { cancelSearch() }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
    }

    // MARK: - Logo Banner

    private var logoBanner: some View {
        VStack(spacing: 0) {
            AnimatedBrandMark(size: 96, markLineWidth: 4.5)
                .frame(width: 120, height: 120)
                .padding(.top, 52)

            Text("Krokva")
                .font(.system(size: 38, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Color.cleanLabel)
                .padding(.top, 14)

            Text("The foundation of every address.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.cleanLabel3)
                .padding(.top, 4)

            Text("v\(appVersion)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cleanLabel.opacity(0.38))
                .padding(.top, 8)

            Text("Search any address to instantly uncover permit history, zoning info, assessment data, and neighbourhood insights.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.cleanLabel.opacity(0.48))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 38)
                .padding(.top, 14)

            dataStatusBadge
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .task { dataStatus.refresh() }
        .onChange(of: dataStatus.status) { _, s in
            guard let s else { return }
            animatedRows = 0; animatedTables = 0
            withAnimation(.easeOut(duration: 4)) {
                animatedRows = Double(s.totalRows)
                animatedTables = Double(s.tableCount)
            }
        }
    }

    @ViewBuilder
    private var dataStatusBadge: some View {
        if let s = dataStatus.status {
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    Text("Database contain ")
                    AnimatedNumber(value: animatedRows)
                        .fontWeight(.semibold)
                    Text(" records in ")
                    AnimatedNumber(value: animatedTables)
                        .fontWeight(.semibold)
                    Text(" databases.")
                }
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.cleanLabel.opacity(0.55))

                if let date = s.lastUpdated {
                    Text("Last update on \(statusDateString(date)).")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.cleanLabel.opacity(0.35))
                }
            }
            .multilineTextAlignment(.center)
        }
    }

    private func statusDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(spacing: 10) {
            // Glass pill with blue glow
            ZStack {
                Circle()
                    .fill(Color.cleanSky.opacity(0.18))
                    .frame(width: 240, height: 80)
                    .blur(radius: 22)
                    .offset(x: 80)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cleanSky)

                    TextField("Street address", text: Binding(
                        get: { viewModel.query },
                        set: { notFoundAddress = nil; viewModel.updateQuery($0) }
                    ))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.cleanLabel)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { runSearch() }

                    if !viewModel.query.isEmpty {
                        Button { viewModel.updateQuery("") } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.cleanLabel.opacity(0.38))
                        }
                        .buttonStyle(.plain)
                    }

                    Button { runSearch() } label: {
                        ZStack {
                            Circle()
                                .fill(viewModel.query.isEmpty ? Color.cleanLabel.opacity(0.15) : Color.cleanSky)
                                .frame(width: 38, height: 38)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.query.isEmpty || viewModel.isLoading)
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.65))
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
                .shadow(color: Color.cleanLabel.opacity(0.08), radius: 18, x: 0, y: 10)
            }

            // Completions
            if !viewModel.completions.isEmpty {
                completionsDropdown
            }

            // No-data banner
            if let notFoundAddress {
                notFoundBanner(notFoundAddress)
            }
        }
    }

    private func notFoundBanner(_ address: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.cleanAmber)
            VStack(alignment: .leading, spacing: 2) {
                Text("No records found")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                Text("The city has no open data for \(address). Check the address and try again.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.cleanLabel2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cleanAmber.opacity(0.10))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.cleanAmber.opacity(0.3), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var completionsDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.completions.prefix(5).enumerated()), id: \.offset) { idx, c in
                Button {
                    viewModel.updateQuery(c.title + ", " + c.subtitle)
                    searchFocused = false
                    runSearch()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle")
                            .foregroundStyle(Color.cleanAmber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.title).foregroundStyle(Color.cleanLabel)
                            Text(c.subtitle).font(.caption).foregroundStyle(Color.cleanLabel.opacity(0.55))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.cleanLabel.opacity(0.35))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx < min(viewModel.completions.count, 5) - 1 {
                    Divider().padding(.leading, 44).foregroundStyle(Color.cleanSep)
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.55))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.6), lineWidth: 1))
    }

    // MARK: - Saved Addresses

    private var savedSection: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Text("Saved").eyebrow(color: .cleanLabel3)
                Spacer()
                Text("\(saved.count) addresses")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel.opacity(0.45))
            }
            .padding(.horizontal, 22)

            VStack(spacing: 8) {
                ForEach(Array(saved.enumerated()), id: \.element.savedAt) { idx, fav in
                    savedRow(fav: fav)
                        .padding(.horizontal, 22)
                }
            }
        }
    }

    private func savedRow(fav: SavedAddress) -> some View {
        Button(action: { openReport(for: fav) }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cleanAmber.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.cleanAmber)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(fav.address)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                        .lineLimit(1)
                    Text(CityRegistry.shared.provider(for: fav.cityID)?.displayName ?? fav.cityID)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle().fill(Color.cleanLabel).frame(width: 34, height: 34)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 10)
            .background(Color.cleanAmber.opacity(0.07))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { modelContext.delete(fav) } label: {
                Label("Remove", systemImage: "bookmark.slash.fill")
            }
        }
    }

    // MARK: - Actions

    private func runSearch() {
        searchFocused = false
        notFoundAddress = nil
        searchTask?.cancel()
        searchTask = Task {
            guard let report = await viewModel.fetchReport() else { return }
            if Task.isCancelled { return }
            // The city has no data for this address — keep the user on Home so they can
            // correct the address, rather than pushing them to an empty Report tab.
            if report.addressNotFound {
                notFoundAddress = report.address.displayAddress
                return
            }
            modelContext.insert(RecentSearch(address: report.address.displayAddress, cityID: report.providerID))
            router.pendingReport = report
        }
    }

    private func openReport(for fav: SavedAddress) {
        viewModel.updateQuery(fav.address)
        notFoundAddress = nil
        searchTask?.cancel()
        searchTask = Task {
            guard let report = await viewModel.fetchReport() else { return }
            if Task.isCancelled { return }
            if report.addressNotFound {
                notFoundAddress = report.address.displayAddress
                return
            }
            router.pendingReport = report
        }
    }

    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        viewModel.cancelLoading()
    }
}

private struct AnimatedNumber: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Int(value).formatted(.number))
    }
}
