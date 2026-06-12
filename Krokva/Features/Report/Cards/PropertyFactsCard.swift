import SwiftUI

struct PropertyFactsCard: View {
    let property: PropertyAssessment?
    var sourceFailed = false
    @State private var isExpanded = false

    var body: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                headerButton
                if isExpanded {
                    Divider()
                    if let p = property {
                        factsGrid(p)
                            .padding(18)
                    } else {
                        Text(sourceFailed ? "Database error loading the assessment record." : "No assessment record was returned for this address.")
                            .font(KrokvaTypography.bodySecondary)
                            .foregroundStyle(Color.cleanLabel2)
                            .padding(18)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "house")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanSky, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Property facts")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if !isExpanded {
                        Text(smallSummary)
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.cleanLabel2)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel3)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var smallSummary: String {
        guard let p = property else { return sourceFailed ? "Database error" : "No assessment data" }
        var parts: [String] = []
        if let area = p.livingArea { parts.append("\(Int(area).formatted()) sf") }
        if let rooms = p.rooms, !rooms.isEmpty { parts.append(roomsDisplay(rooms)) }
        if let lot = p.landArea { parts.append("\(Int(lot).formatted()) sf lot") }
        return parts.isEmpty ? "Tap to view details" : parts.joined(separator: " · ")
    }

    // MARK: - Full content

    @ViewBuilder
    private func factsGrid(_ p: PropertyAssessment) -> some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 0) {
            GridRow {
                factRow("House style", p.houseStyle ?? "—")
                factRow("Rooms", roomsDisplay(p.rooms))
            }
            GridRow {
                factRow("Living area", area(p.livingArea))
                factRow("Lot size", area(p.landArea))
            }
            if let backyard = backyardArea(p) {
                GridRow {
                    factRow("Backyard (est.)", backyard)
                    factRow("Year built", p.yearBuilt.map(String.init) ?? "—")
                }
            } else {
                GridRow {
                    factRow("Year built", p.yearBuilt.map(String.init) ?? "—")
                    factRow("Property use", p.useCode ?? "—")
                }
            }
            GridRow {
                factRow("Basement", p.basement ?? "—")
                factRow("Garage", p.garage ?? "—")
            }
            GridRow {
                factRow("A/C", p.airConditioning ?? "—")
                factRow("Fireplace", p.fireplace ?? "—")
            }
            GridRow {
                factRow("Pool", p.swimmingPool ?? "—")
                factRow("Zoning", p.zoning ?? "—")
            }
        }
        if p.propertyTaxIsEstimated {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
                    .padding(.top, 2)
                Text("Tax estimate uses 2026 residential mill rates; actual bill can vary by school division, credits, and local improvements.")
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel3)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func factRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).eyebrow(color: .cleanLabel3)
            Text(value)
                .font(KrokvaTypography.body)
                .foregroundStyle(Color.cleanLabel)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func backyardArea(_ p: PropertyAssessment) -> String? {
        guard let lot = p.landArea, let living = p.livingArea, lot > living else { return nil }
        return area(lot - living)
    }

    private func roomsDisplay(_ rooms: String?) -> String {
        guard let r = rooms, !r.isEmpty else { return "—" }
        if r.allSatisfy({ $0.isNumber }) { return "\(r) rooms" }
        return r
    }
}
