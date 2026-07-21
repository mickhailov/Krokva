import SwiftData
import SwiftUI

struct PropertyCompareView: View {
    @Binding var selectedTab: Int
    @Query(sort: \SavedReport.savedAt, order: .reverse) private var saved: [SavedReport]
    @Environment(\.modelContext) private var modelContext

    @State private var isExporting = false
    @State private var shareItem: ShareItem?

    private struct ShareItem: Identifiable {
        let url: URL
        var id: String { url.path }
    }

    /// Saved reports capped at the pin limit, current/home address first so it
    /// anchors the leftmost comparison column.
    private var props: [SavedReport] {
        Array(saved.prefix(SavedReport.maxSaved))
            .sorted { ($0.isCurrentAddress ? 0 : 1) < ($1.isCurrentAddress ? 0 : 1) }
    }
    private var reports: [AddressReport?] { props.map { $0.decodedReport() } }
    private var currentIndex: Int? { props.firstIndex(where: \.isCurrentAddress) }

    private var verdict: RelocationVerdict? {
        guard let currentIndex, props.count >= 2 else { return nil }
        let current = props[currentIndex]
        let currentMetrics = RelocationMetrics.from(saved: current, report: reports[currentIndex])
        let candidates = props.indices.filter { $0 != currentIndex }.map { i in
            (address: props[i].address,
             metrics: RelocationMetrics.from(saved: props[i], report: reports[i]))
        }
        return RelocationVerdict.make(currentAddress: current.address,
                                      current: currentMetrics,
                                      candidates: candidates)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cleanBg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        propertyCardsScroll
                            .padding(.bottom, 20)
                        if props.count >= 2 {
                            if let verdict {
                                RelocationVerdictCard(verdict: verdict)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                            } else {
                                setCurrentPrompt
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                            }
                            CompareTableView(props: props, reports: reports, currentIndex: currentIndex)
                                .padding(.bottom, 40)
                        } else {
                            addPrompt
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("KROKVA")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(LinearGradient(
                        colors: [.cleanSky, .cleanIndigo],
                        startPoint: .leading, endPoint: .trailing))
                Text("Compare")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.cleanLabel)
                    .tracking(-0.8)
            }
            Spacer()
            if props.count >= 2 {
                exportButton
            } else if !saved.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(saved.count)")
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color.cleanLabel)
                    Text("SAVED")
                        .eyebrow()
                }
            }
        }
    }

    private var exportButton: some View {
        Button(action: exportPDF) {
            HStack(spacing: 6) {
                if isExporting {
                    ProgressView().tint(.cleanSky)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(isExporting ? "Generating…" : "Export PDF")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.cleanSky)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.cleanCard, in: Capsule())
            .overlay(Capsule().stroke(Color.cleanSep, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
    }

    // MARK: - Property cards

    private var propertyCardsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(props.enumerated()), id: \.offset) { i, prop in
                    miniCard(prop, colorIndex: i)
                }
                if props.count < SavedReport.maxSaved {
                    addSlot
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func miniCard(_ prop: SavedReport, colorIndex: Int) -> some View {
        let gradients: [[Color]] = [
            [Color(hex: 0xC8D4D0), Color(hex: 0xD8E4E0)],
            [Color(hex: 0xC4C8DC), Color(hex: 0xD0D4E8)],
            [Color(hex: 0xD0CCC8), Color(hex: 0xDCD8D4)],
            [Color(hex: 0xC8CED4), Color(hex: 0xD4DAE0)],
            [Color(hex: 0xD5CEBA), Color(hex: 0xE4DDC8)],
        ]
        let colors = gradients[colorIndex % gradients.count]

        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: colors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing))
                    .frame(height: 80)
                Button {
                    withAnimation { modelContext.delete(prop) }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.cleanCard.opacity(0.9))
                            .frame(width: 22, height: 22)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.cleanLabel2)
                    }
                }
                .padding(6)
            }

            // Current / candidate control: tap to make this the home address.
            Button {
                withAnimation { SavedReport.setCurrent(prop, in: saved) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: prop.isCurrentAddress ? "house.fill" : "house")
                        .font(.system(size: 9, weight: .bold))
                    Text(prop.isCurrentAddress ? "CURRENT" : "SET CURRENT")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.5)
                }
                .foregroundStyle(prop.isCurrentAddress ? .white : Color.cleanSky)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(prop.isCurrentAddress ? Color.cleanSky : Color.cleanSkyWash, in: Capsule())
            }
            .buttonStyle(.plain)

            Text(prop.address)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.cleanLabel)
                .lineLimit(2)

            if !prop.neighbourhood.isEmpty {
                Text(prop.neighbourhood)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cleanLabel2)
            }

            if let v = prop.assessedValue {
                Text(currencyLabel(v))
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.cleanLabel)
            } else {
                Text("No assessment")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
        .padding(12)
        .frame(width: 148)
        .background(Color.cleanCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(prop.isCurrentAddress ? Color.cleanSky : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var addSlot: some View {
        Button { selectedTab = 1 } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.cleanSkyWash).frame(width: 42, height: 42)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.cleanSky)
                }
                Text("Add property")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.cleanSky)
                Text("Search & tap\n  in a report")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 130, height: 160)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Color.cleanSep)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Prompts

    private var setCurrentPrompt: some View {
        CleanCard {
            HStack(spacing: 12) {
                Image(systemName: "house.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.cleanSky)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pick your current address")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    Text("Tap “Set current” on the address you live at to get a moving verdict for the others.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cleanLabel2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var addPrompt: some View {
        VStack(spacing: 18) {
            Image(systemName: "bookmark.square.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.cleanSky.opacity(0.22))
            VStack(spacing: 6) {
                Text(props.isEmpty ? "No saved properties" : "Add one more to compare")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                Text("Search for an address, open its report, then tap the bookmark to save it here.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cleanLabel2)
                    .multilineTextAlignment(.center)
            }
            Button { selectedTab = 1 } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("Search Properties")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color.cleanSky, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 48)
        .padding(.bottom, 40)
    }

    // MARK: - PDF export

    private func exportPDF() {
        guard !isExporting, props.count >= 2 else { return }
        isExporting = true
        Task { @MainActor in
            await Task.yield()
            let url = ComparePDFExporter.export(
                props: props,
                reports: reports,
                currentIndex: currentIndex,
                verdict: verdict,
                modelContext: modelContext
            )
            isExporting = false
            if let url { shareItem = ShareItem(url: url) }
        }
    }
}
