import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var votes: [CityVote]
    @Query private var cachedDatasets: [CachedDataset]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cleanBg.ignoresSafeArea()

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
                                .foregroundStyle(Color.cleanLabel2.opacity(0.56))
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(Color.cleanBg, for: .navigationBar)
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                BrandMarkView(lineWidth: 3).frame(width: 20, height: 20)
                Text("About")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
            }
            Divider().foregroundStyle(Color.cleanSep)
            Text("Krokva (Ukrainian: krokva) is the rafter beam that holds up a roof — the structural element on which a home rests. We surface the structural facts the city already knows about your address.")
                .font(KrokvaTypography.body)
                .foregroundStyle(Color.cleanLabel2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.cleanCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 1)
    }

    private var cityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanSky)
                Text("City coverage")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
            }
            Divider().foregroundStyle(Color.cleanSep)
            VStack(spacing: 0) {
                ForEach(Array(CityRegistry.shared.providers.enumerated()), id: \.offset) { index, provider in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(provider.implementationState == .live ? Color.cleanGreen : Color.cleanAmber)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName)
                                .font(KrokvaTypography.body)
                                .foregroundStyle(Color.cleanLabel)
                            Text(provider.implementationState == .live ? "Live" : "Coming soon")
                                .font(KrokvaTypography.caption)
                                .foregroundStyle(Color.cleanLabel2.opacity(0.68))
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
                                .foregroundStyle(Color.cleanLabel)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.cleanAmber))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 9)
                    if index < CityRegistry.shared.providers.count - 1 {
                        Divider().foregroundStyle(Color.cleanSep)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cleanCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 1)
    }

    private var datasetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanSky)
                Text("Dataset health")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
            }
            Divider().foregroundStyle(Color.cleanSep)
            if cachedDatasets.isEmpty {
                Text("No cached datasets yet.")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.cleanLabel2.opacity(0.68))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(cachedDatasets.enumerated()), id: \.offset) { index, cache in
                        HStack {
                            Text(cache.key)
                                .font(KrokvaTypography.bodySecondary)
                                .foregroundStyle(Color.cleanLabel2)
                            Spacer()
                            Text(cache.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(KrokvaTypography.monoSmall)
                                .foregroundStyle(Color.cleanLabel2.opacity(0.68))
                        }
                        .padding(.vertical, 8)
                        if index < cachedDatasets.count - 1 {
                            Divider().foregroundStyle(Color.cleanSep)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cleanCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 1)
    }

    private var licencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanSky)
                Text("Licences")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
            }
            Divider().foregroundStyle(Color.cleanSep)
            VStack(spacing: 0) {
                ForEach(Array(CityRegistry.shared.providers.enumerated()), id: \.offset) { index, provider in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.displayName)
                            .font(KrokvaTypography.body)
                            .foregroundStyle(Color.cleanLabel)
                        Text(provider.attribution)
                            .font(KrokvaTypography.caption)
                            .foregroundStyle(Color.cleanLabel2.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    if index < CityRegistry.shared.providers.count - 1 {
                        Divider().foregroundStyle(Color.cleanSep)
                    }
                }
                Divider().foregroundStyle(Color.cleanSep)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Winnipeg Regional Health Authority")
                        .font(KrokvaTypography.body)
                        .foregroundStyle(Color.cleanLabel)
                    Text("Current Winnipeg emergency department wait times from WRHA (https://wrha.mb.ca/wait-times/emergency/).")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.cleanLabel2.opacity(0.68))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color.cleanCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 1)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            Button("Clear cache") {
                cachedDatasets.forEach(modelContext.delete)
            }
            .font(KrokvaTypography.body)
            .foregroundStyle(Color.cleanSky)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)

            Divider().foregroundStyle(Color.cleanSep)

            Link(destination: URL(string: "mailto:feedback@krokva.ca")!) {
                HStack {
                    Text("Send feedback")
                        .font(KrokvaTypography.body)
                        .foregroundStyle(Color.cleanLabel)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel2.opacity(0.68))
                }
                .padding(.vertical, 10)
            }
        }
        .padding(16)
        .background(Color.cleanCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 1)
    }

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
