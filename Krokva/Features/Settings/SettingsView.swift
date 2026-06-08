import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var votes: [CityVote]
    @Query private var cachedDatasets: [CachedDataset]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.krokvaPaper.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        aboutCard
                        cityCard
                        datasetCard
                        licencesCard
                        actionsCard

                        HStack(spacing: 6) {
                            BrandMarkView(lineWidth: 2).frame(width: 12, height: 12)
                            Text("Krokva · Civic data for Canadian addresses.")
                                .font(KrokvaTypography.caption)
                                .foregroundStyle(Color.krokvaInk3)
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(Color.krokvaSurface, for: .navigationBar)
        }
    }

    // MARK: - Cards

    private var aboutCard: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    BrandMarkView(lineWidth: 3).frame(width: 20, height: 20)
                    Text("About")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                }
                Divider().foregroundStyle(Color.krokvaLineSoft)
                Text("Krokva (Ukrainian: krokva) is the rafter beam that holds up a roof — the structural element on which a home rests. We surface the structural facts the city already knows about your address.")
                    .font(KrokvaTypography.body)
                    .foregroundStyle(Color.krokvaInk2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var cityCard: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "map")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("City coverage")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                }
                Divider().foregroundStyle(Color.krokvaLineSoft)
                VStack(spacing: 0) {
                    ForEach(Array(CityRegistry.shared.providers.enumerated()), id: \.offset) { index, provider in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(provider.implementationState == .live ? Color.krokvaGreen : Color.krokvaGold)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(KrokvaTypography.body)
                                    .foregroundStyle(Color.krokvaInk)
                                Text(provider.implementationState == .live ? "Live" : "Coming soon")
                                    .font(KrokvaTypography.caption)
                                    .foregroundStyle(Color.krokvaInk3)
                            }
                            Spacer()
                            if provider.implementationState == .comingSoon {
                                Button {
                                    vote(for: provider.cityID)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "hand.thumbsup.fill").imageScale(.small)
                                        Text("\(voteCount(for: provider.cityID))")
                                    }
                                    .font(KrokvaTypography.monoSmall)
                                    .foregroundStyle(Color.krokvaGoldDeep)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.krokvaGoldSoft))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 9)
                        if index < CityRegistry.shared.providers.count - 1 {
                            Divider().foregroundStyle(Color.krokvaLineSoft)
                        }
                    }
                }
            }
        }
    }

    private var datasetCard: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Dataset health")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                }
                Divider().foregroundStyle(Color.krokvaLineSoft)
                if cachedDatasets.isEmpty {
                    Text("No cached datasets yet.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(cachedDatasets.enumerated()), id: \.offset) { index, cache in
                            HStack {
                                Text(cache.key)
                                    .font(KrokvaTypography.bodySecondary)
                                    .foregroundStyle(Color.krokvaInk2)
                                Spacer()
                                Text(cache.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(KrokvaTypography.monoSmall)
                                    .foregroundStyle(Color.krokvaInk3)
                            }
                            .padding(.vertical, 8)
                            if index < cachedDatasets.count - 1 {
                                Divider().foregroundStyle(Color.krokvaLineSoft)
                            }
                        }
                    }
                }
            }
        }
    }

    private var licencesCard: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Licences")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                }
                Divider().foregroundStyle(Color.krokvaLineSoft)
                VStack(spacing: 0) {
                    ForEach(Array(CityRegistry.shared.providers.enumerated()), id: \.offset) { index, provider in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName)
                                .font(KrokvaTypography.body)
                                .foregroundStyle(Color.krokvaInk)
                            Text(provider.attribution)
                                .font(KrokvaTypography.caption)
                                .foregroundStyle(Color.krokvaInk3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        if index < CityRegistry.shared.providers.count - 1 {
                            Divider().foregroundStyle(Color.krokvaLineSoft)
                        }
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        KrokvaCard {
            VStack(spacing: 0) {
                Button("Clear cache") {
                    cachedDatasets.forEach(modelContext.delete)
                }
                .font(KrokvaTypography.body)
                .foregroundStyle(Color.krokvaAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)

                Divider().foregroundStyle(Color.krokvaLineSoft)

                Link(destination: URL(string: "mailto:feedback@krokva.ca")!) {
                    HStack {
                        Text("Send feedback")
                            .font(KrokvaTypography.body)
                            .foregroundStyle(Color.krokvaInk)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.krokvaInk3)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Vote helpers

    private func voteCount(for cityID: String) -> Int {
        votes.first { $0.cityID == cityID }?.count ?? 0
    }

    private func vote(for cityID: String) {
        if let vote = votes.first(where: { $0.cityID == cityID }) {
            vote.count += 1
        } else {
            modelContext.insert(CityVote(cityID: cityID, count: 1))
        }
    }
}
