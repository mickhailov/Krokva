import SwiftData
import SwiftUI

struct PropertyCompareView: View {
    @Binding var selectedTab: Int
    @Query(sort: \SavedReport.savedAt, order: .reverse) private var saved: [SavedReport]
    @Environment(\.modelContext) private var modelContext

    private var props: [SavedReport] { Array(saved.prefix(4)) }

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
                            compareContent
                                .padding(.bottom, 40)
                        } else {
                            addPrompt
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
            if !saved.isEmpty {
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

    // MARK: - Property cards

    private var propertyCardsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(props.enumerated()), id: \.offset) { i, prop in
                    miniCard(prop, colorIndex: i)
                }
                if props.count < 4 {
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

    // MARK: - Empty / add prompt

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

    // MARK: - Comparison layout

    private var compareContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeaders
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
            taxDisclaimer
                .padding(.horizontal, 16)
                .padding(.top, 10)
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 96)
            ForEach(Array(props.enumerated()), id: \.offset) { _, prop in
                Text(shortAddress(prop.address))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel2)
                    .frame(maxWidth: .infinity)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    // MARK: - Data model

    private struct CompareRow {
        let label: String
        let values: [String?]
        let bestIndex: Int?
    }

    private struct CompareSection {
        let title: String
        let rows: [CompareRow]
    }

    private var sections: [CompareSection] {
        [
            CompareSection(title: "VALUE",        rows: valueRows),
            CompareSection(title: "SIZE",          rows: sizeRows),
            CompareSection(title: "PROPERTY",      rows: propertyRows),
            CompareSection(title: "FEATURES",      rows: featureRows),
            CompareSection(title: "NEIGHBOURHOOD", rows: neighbourhoodRows),
        ]
    }

    private var valueRows: [CompareRow] {
        [
            CompareRow(
                label: "Assessed",
                values: props.map { $0.assessedValue.map(currencyLabel) },
                bestIndex: nil
            ),
            CompareRow(
                label: "Tax",
                values: props.map {
                    guard let v = $0.propertyTax else { return nil }
                    return $0.propertyTaxIsEstimated ? currencyLabel(v) + "*" : currencyLabel(v)
                },
                bestIndex: bestDouble(props.map(\.propertyTax), higher: false)
            ),
        ]
    }

    private var sizeRows: [CompareRow] {
        [
            CompareRow(
                label: "Living",
                values: props.map { $0.livingArea.map { "\(Int($0).formatted()) sf" } },
                bestIndex: bestDouble(props.map(\.livingArea), higher: true)
            ),
            CompareRow(
                label: "Lot",
                values: props.map { $0.landArea.map { "\(Int($0).formatted()) sf" } },
                bestIndex: bestDouble(props.map(\.landArea), higher: true)
            ),
        ]
    }

    private var propertyRows: [CompareRow] {
        [
            CompareRow(
                label: "Year Built",
                values: props.map { $0.yearBuilt.map { "\($0)" } },
                bestIndex: bestInt(props.map(\.yearBuilt), higher: true)
            ),
            CompareRow(label: "Style",   values: props.map { $0.houseStyle?.nilIfEmpty },   bestIndex: nil),
            CompareRow(label: "Storeys", values: props.map { $0.storeys?.nilIfEmpty },       bestIndex: nil),
            CompareRow(label: "Zoning",  values: props.map { $0.zoning?.nilIfEmpty },        bestIndex: nil),
        ]
    }

    private var featureRows: [CompareRow] {
        [
            featureRow("Basement",  \.basement),
            featureRow("Garage",    \.garage),
            featureRow("A/C",       \.airConditioning),
            featureRow("Fireplace", \.fireplace),
            featureRow("Pool",      \.swimmingPool),
        ]
    }

    private func featureRow(_ label: String, _ kp: KeyPath<SavedReport, String?>) -> CompareRow {
        CompareRow(
            label: label,
            values: props.map {
                guard let v = $0[keyPath: kp], !v.isEmpty else { return nil }
                let low = v.lowercased()
                guard low != "none", low != "no" else { return nil }
                return v
            },
            bestIndex: nil
        )
    }

    private var neighbourhoodRows: [CompareRow] {
        [
            CompareRow(
                label: "District",
                values: props.map { $0.neighbourhood.nilIfEmpty },
                bestIndex: nil
            ),
            CompareRow(
                label: "Permits",
                values: props.map { Optional("\($0.permitCount)") },
                bestIndex: nil
            ),
            CompareRow(
                label: "Vacant Orders",
                values: props.map { Optional("\($0.vacantOrderCount)") },
                bestIndex: bestInts(props.map(\.vacantOrderCount), higher: false)
            ),
            CompareRow(
                label: "311 Calls",
                values: props.map { $0.serviceRequestTotal.map { "\($0.formatted())" } },
                bestIndex: bestInt(props.map(\.serviceRequestTotal), higher: false)
            ),
            CompareRow(
                label: "Crime/Year",
                values: props.map { $0.crimeLastYear.map { "\($0.formatted())" } },
                bestIndex: bestInt(props.map(\.crimeLastYear), higher: false)
            ),
            CompareRow(
                label: "Parks Nearby",
                values: props.map { $0.parkCount.map { "\($0)" } },
                bestIndex: bestInt(props.map(\.parkCount), higher: true)
            ),
            CompareRow(
                label: "Transit",
                values: props.map { $0.transitOnTimePct.map { String(format: "%.0f%%", $0) } },
                bestIndex: bestDouble(props.map(\.transitOnTimePct), higher: true)
            ),
        ]
    }

    // MARK: - Section view

    private func sectionView(_ section: CompareSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .eyebrow()
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 6)
            CleanCard(padding: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.offset) { idx, row in
                    rowView(row)
                    if idx < section.rows.count - 1 {
                        Divider().padding(.leading, 96)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func rowView(_ row: CompareRow) -> some View {
        HStack(spacing: 0) {
            Text(row.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cleanLabel2)
                .frame(width: 80, alignment: .leading)
                .padding(.leading, 16)
            ForEach(Array(props.indices), id: \.self) { i in
                let val = i < row.values.count ? (row.values[i] ?? "—") : "—"
                let isBest = i == row.bestIndex
                Text(val)
                    .font(.system(size: 12, weight: isBest ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(isBest ? Color.cleanSky : Color.cleanLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isBest ? Color.cleanSkyWash : Color.clear)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Tax disclaimer

    @ViewBuilder
    private var taxDisclaimer: some View {
        if props.contains(where: { $0.propertyTaxIsEstimated && $0.propertyTax != nil }) {
            Text("* 2026 tax estimate based on assessment")
                .font(.system(size: 10))
                .foregroundStyle(Color.cleanLabel3)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Helpers

    private func currencyLabel(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.2fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "$%.0fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }

    private func shortAddress(_ address: String) -> String {
        String(address.split(separator: ",").first ?? Substring(address))
    }

    private func bestDouble(_ values: [Double?], higher: Bool) -> Int? {
        let pairs = values.enumerated().compactMap { i, v in v.map { (i, $0) } }
        guard pairs.count > 1, !pairs.allSatisfy({ $0.1 == pairs[0].1 }) else { return nil }
        return higher
            ? pairs.max(by: { $0.1 < $1.1 })?.0
            : pairs.min(by: { $0.1 < $1.1 })?.0
    }

    private func bestInt(_ values: [Int?], higher: Bool) -> Int? {
        bestDouble(values.map { $0.map(Double.init) }, higher: higher)
    }

    private func bestInts(_ values: [Int], higher: Bool) -> Int? {
        bestDouble(values.map { Optional(Double($0)) }, higher: higher)
    }
}

// MARK: - String nilIfEmpty

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
