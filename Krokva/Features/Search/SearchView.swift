import SwiftData
import SwiftUI

struct SearchView: View {
    var initialQuery: String? = nil
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecentSearch.createdAt, order: .reverse) private var recentSearches: [RecentSearch]
    @Query(sort: \SavedReport.savedAt, order: .reverse) private var savedReports: [SavedReport]
    @State private var viewModel = SearchViewModel()
    @State private var showReport = false
    @State private var selectedReport: AddressReport?
    @State private var refreshingAddress: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Color.cleanBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    brandBar
                    header
                    searchField
                    cityPill

                    if !viewModel.completions.isEmpty {
                        completionsList
                    }

                    if !recentSearches.isEmpty {
                        recentsSection
                    }

                    if !savedReports.isEmpty {
                        savedReportsSection
                    }

                    footer
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showReport) {
            if let selectedReport {
                ReportView(report: selectedReport)
            }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingScreenAnimation(
                    addressText: viewModel.query,
                    cityName: viewModel.detectedProvider?.displayName ?? "Winnipeg, MB",
                    stage: viewModel.loadingStage,
                    subStageFraction: viewModel.loadingSubFraction,
                    onCancel: { cancelSearch() }
                )
                .ignoresSafeArea()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if let q = initialQuery, viewModel.query.isEmpty {
                viewModel.updateQuery(q)
                runSearch()
            }
        }
    }

    // MARK: - Top bar

    private var brandBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                BrandMarkView(color: .cleanLabel, lineWidth: 2.6)
                    .frame(width: 22, height: 22)
                Text("Krokva")
                    .font(KrokvaTypography.wordmark)
                    .foregroundStyle(Color.cleanLabel)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(Color.cleanGreen).frame(width: 7, height: 7)
                Text("WPG LIVE")
            }
            .font(KrokvaTypography.monoSmall)
            .tracking(1.8)
            .foregroundStyle(Color.cleanLabel2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.55))
            .background(.ultraThinMaterial, in: Capsule())
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Krokva Winnipeg live")
    }

    // MARK: - Headline

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Municipal address report")
                .eyebrow(color: .cleanLabel3)
            Text("Where does\nthis address\nstand?")
                .font(.system(size: 36, weight: .bold)).foregroundStyle(Color.cleanLabel).tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text("Assessment, permits, map context, infrastructure, parks, transit, and public records — from city open data.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.cleanLabel.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
    }

    // MARK: - Search field (glass + blue glow)

    private var searchField: some View {
        ZStack {
            Circle()
                .fill(Color.cleanSky.opacity(0.20))
                .frame(width: 240, height: 80)
                .blur(radius: 20)
                .offset(x: 80)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanSky)

                TextField("Street address or roll #", text: Binding(
                    get: { viewModel.query },
                    set: { viewModel.updateQuery($0) }
                ))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.cleanLabel)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit { runSearch() }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.updateQuery("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.cleanLabel.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }

                Button { runSearch() } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.query.isEmpty ? Color.cleanLabel.opacity(0.18) : Color.cleanSky)
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
            .background(Color.white.opacity(0.6))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
            .shadow(color: Color.cleanLabel.opacity(0.07), radius: 16, x: 0, y: 10)
        }
    }

    // MARK: - City pill

    private var cityPill: some View {
        let provider = viewModel.detectedProvider
        return HStack(spacing: 10) {
            Circle()
                .fill(provider?.implementationState == .live ? Color.cleanGreen : Color.cleanAmber)
                .frame(width: 8, height: 8)
            Text(provider?.displayName ?? "Detected city appears here")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(provider == nil ? Color.cleanLabel.opacity(0.45) : Color.cleanLabel)
            Spacer()
            if provider?.implementationState == .comingSoon {
                Text("Request").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.cleanAmber)
            } else if provider?.implementationState == .live {
                Text("Live").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.cleanGreen)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.5))
        .background(.ultraThinMaterial, in: Capsule())
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
    }

    // MARK: - Completions

    private var completionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.completions.enumerated()), id: \.offset) { index, completion in
                Button {
                    viewModel.updateQuery("\(completion.title), \(completion.subtitle)")
                    searchFocused = false
                    runSearch()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle")
                            .foregroundStyle(Color.cleanAmber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title).foregroundStyle(Color.cleanLabel)
                            Text(completion.subtitle).font(.caption).foregroundStyle(Color.cleanLabel.opacity(0.55))
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
                if index < viewModel.completions.count - 1 {
                    Divider().padding(.leading, 44).foregroundStyle(Color.cleanSep)
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.55))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.6), lineWidth: 1))
    }

    // MARK: - Recents (Editorial stacked pills)

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent").eyebrow(color: .cleanLabel3)
                Spacer()
                Text("\(min(recentSearches.count, 5)) lookups")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel.opacity(0.45))
            }

            VStack(spacing: 8) {
                ForEach(Array(recentSearches.prefix(5).enumerated()), id: \.offset) { index, search in
                    Button {
                        viewModel.updateQuery(search.address)
                        runSearch()
                    } label: {
                        recentRow(search.address, tint: recentTint(index))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4)
    }

    private func recentRow(_ address: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white).frame(width: 36, height: 36)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(address)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.cleanLabel)
                .lineLimit(1)
            Spacer(minLength: 8)
            ZStack {
                Circle().fill(Color.cleanLabel).frame(width: 34, height: 34)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(tint.opacity(0.16))
        .background(.ultraThinMaterial, in: Capsule())
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
    }

    private func recentTint(_ index: Int) -> Color {
        [.cleanLabel2, .cleanAmber, .cleanGreen, .cleanRed, .cleanSky][index % 5]
    }

    // MARK: - Saved Reports

    private var savedReportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved").eyebrow(color: .cleanLabel3)
                Spacer()
                Text("\(min(savedReports.count, 5)) reports")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel.opacity(0.45))
            }
            VStack(spacing: 8) {
                ForEach(Array(savedReports.prefix(5))) { saved in
                    savedReportRow(saved)
                }
            }
        }
        .padding(.top, 4)
    }

    private func savedReportRow(_ saved: SavedReport) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.cleanSky.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.cleanSky)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(saved.address)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                    .lineLimit(1)
                if !saved.neighbourhood.isEmpty {
                    Text("\(saved.neighbourhood) · \(saved.cityName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.cleanLabel3)
                    Text("Updated \(saved.savedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.cleanLabel3)
                }
            }

            Spacer(minLength: 4)

            Button {
                Task { await refreshSavedReport(saved) }
            } label: {
                if refreshingAddress == saved.address {
                    ProgressView()
                        .frame(width: 34, height: 34)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.cleanTrack)
                            .frame(width: 34, height: 34)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.cleanLabel2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(Color.cleanSky.opacity(0.07))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.4), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            if let report = saved.decodedReport(), !shouldRefetchSavedReport(report) {
                selectedReport = report
                showReport = true
            } else {
                viewModel.updateQuery(saved.address)
                runSearch()
            }
        }
    }

    private func shouldRefetchSavedReport(_ report: AddressReport) -> Bool {
        report.providerID == "winnipeg" && report.serviceRequests == nil
    }

    private func refreshSavedReport(_ saved: SavedReport) async {
        guard refreshingAddress == nil else { return }
        refreshingAddress = saved.address
        defer { refreshingAddress = nil }
        let service = ReportService()
        let report = await service.report(for: saved.address, modelContext: modelContext, forceRefresh: true)
        saved.update(from: report)
        try? modelContext.save()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            BrandMarkView(lineWidth: 2).frame(width: 14, height: 14)
            Text("Krokva · structural facts for Canadian addresses.")
                .font(.caption)
                .foregroundStyle(Color.cleanLabel.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Search

    private func runSearch() {
        searchFocused = false
        searchTask?.cancel()
        searchTask = Task {
            guard let report = await viewModel.fetchReport(modelContext: modelContext) else { return }
            if Task.isCancelled { return }
            selectedReport = report
            modelContext.insert(RecentSearch(address: report.address.displayAddress, cityID: report.providerID))
            await MainActor.run { showReport = true }
        }
    }

    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        viewModel.cancelLoading()
    }
}
