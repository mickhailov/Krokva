import SwiftData
import SwiftUI

struct SearchView: View {
    @Binding var selectedDossier: AddressDossier?
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecentSearch.createdAt, order: .reverse) private var recentSearches: [RecentSearch]
    @State private var viewModel = SearchViewModel()
    @State private var showDossier = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.krokvaPaper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        brandBar

                        header

                        searchField

                        cityPill

                        if !viewModel.completions.isEmpty {
                            completionsList
                        }

                        actions

                        if !recentSearches.isEmpty {
                            recentsSection
                        }

                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showDossier) {
                if let selectedDossier {
                    DossierView(dossier: selectedDossier)
                }
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
            .toolbarBackground(Color.krokvaSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var brandBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                BrandMarkView(color: .krokvaNavy, lineWidth: 2.6)
                    .frame(width: 22, height: 22)
                Text("Krokva")
                    .font(KrokvaTypography.wordmark)
                    .foregroundStyle(Color.krokvaNavy)
            }

            Spacer()

            HStack(spacing: 10) {
                Text("WPG")
                Text("·")
                Text("LIVE")
            }
            .font(KrokvaTypography.monoSmall)
            .tracking(3.4)
            .foregroundStyle(Color.krokvaInk3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Krokva Winnipeg live")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The structural truth")
                .eyebrow(color: Color.krokvaInk3)
            Text("What does the city know about\nyour address?")
                .font(KrokvaTypography.displayLarge)
                .foregroundStyle(Color.krokvaInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .background(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color.krokvaGoldSoft)
                        .frame(width: 220, height: 9)
                        .offset(y: -2)
                }
            Text("A dossier from municipal open data. No listings. No estimates. Just the records.")
                .font(KrokvaTypography.body)
                .foregroundStyle(Color.krokvaInk2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.krokvaInk3)
            TextField("Enter a Canadian address", text: Binding(
                get: { viewModel.query },
                set: { viewModel.updateQuery($0) }
            ))
            .foregroundStyle(Color.krokvaInk)
            .textInputAutocapitalization(.words)
            .submitLabel(.search)
            .focused($searchFocused)
            .onSubmit { runSearch() }
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.updateQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.krokvaInk3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.krokvaSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.krokvaLine, lineWidth: 1)
        )
    }

    private var completionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.completions.enumerated()), id: \.offset) { index, completion in
                Button {
                    viewModel.updateQuery("\(completion.title), \(completion.subtitle)")
                    searchFocused = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle")
                            .foregroundStyle(Color.krokvaGold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title).foregroundStyle(Color.krokvaInk)
                            Text(completion.subtitle).font(.caption).foregroundStyle(Color.krokvaInk3)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
                if index < viewModel.completions.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .background(Color.krokvaSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.krokvaLine, lineWidth: 1)
        )
    }

    private var actions: some View {
        Button {
            runSearch()
        } label: {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("Open dossier")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.krokvaNavy, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
            .opacity(viewModel.query.isEmpty ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.query.isEmpty || viewModel.isLoading)
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent searches")
                .eyebrow(color: .krokvaInk3)
            VStack(spacing: 0) {
                ForEach(Array(recentSearches.prefix(5).enumerated()), id: \.offset) { index, search in
                    Button {
                        viewModel.updateQuery(search.address)
                        runSearch()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(Color.krokvaGold)
                            Text(search.address)
                                .foregroundStyle(Color.krokvaInk)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.krokvaInk3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if index < min(recentSearches.count, 5) - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color.krokvaSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.krokvaLine, lineWidth: 1)
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            BrandMarkView(lineWidth: 2).frame(width: 14, height: 14)
            Text("Krokva · the foundation of every address.")
                .font(.caption)
                .foregroundStyle(Color.krokvaInk3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }

    private var cityPill: some View {
        let provider = viewModel.detectedProvider
        return HStack(spacing: 8) {
            Circle()
                .fill(provider?.implementationState == .live ? Color.krokvaGreen : Color.krokvaGold)
                .frame(width: 8, height: 8)
            Text(provider?.displayName ?? "Detected city appears here")
                .foregroundStyle(provider == nil ? Color.krokvaInk3 : Color.krokvaInk)
            Spacer()
            if provider?.implementationState == .comingSoon {
                Text("Tap to request").foregroundStyle(Color.krokvaGold)
            } else if provider?.implementationState == .live {
                Text("Live").font(.caption2.weight(.semibold)).foregroundStyle(Color.krokvaGreen)
            }
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.krokvaSurface, in: Capsule())
        .overlay(Capsule().stroke(Color.krokvaLine, lineWidth: 1))
    }

    private func runSearch() {
        searchFocused = false
        Task {
            guard let dossier = await viewModel.fetchDossier() else { return }
            selectedDossier = dossier
            modelContext.insert(RecentSearch(address: dossier.address.displayAddress, cityID: dossier.providerID))
            showDossier = true
        }
    }
}
