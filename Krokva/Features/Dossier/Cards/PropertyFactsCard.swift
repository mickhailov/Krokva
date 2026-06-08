import SwiftUI

// MARK: - PropertyFactsCard (Civic Modernist)
//
// 2-column grid of property attributes. Uses KrokvaCard + eyebrow pattern.

struct PropertyFactsCard: View {
    let property: PropertyAssessment?

    var body: some View {
        KrokvaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "house")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaNavy)
                    Text("Property facts")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.krokvaInk)
                    Spacer()
                    Text("14 FIELDS")
                        .eyebrow(color: .krokvaInk3)
                }

                if let property {
                    Grid(horizontalSpacing: 14, verticalSpacing: 0) {
                        GridRow {
                            factRow("Assessed value", money(property.totalAssessedValue))
                            factRow(propertyTaxLabel(property), money(property.propertyTax))
                        }
                        GridRow {
                            factRow("House style", property.houseStyle ?? "—")
                            factRow("Storeys", property.storeys ?? "—")
                        }
                        GridRow {
                            factRow("Living area", area(property.livingArea))
                            factRow("Lot size", area(property.landArea))
                        }
                        if let backyard = backyardArea(property) {
                            GridRow {
                                factRow("Backyard (est.)", backyard)
                                factRow("Year built", property.yearBuilt.map(String.init) ?? "—")
                            }
                        } else {
                            GridRow {
                                factRow("Year built", property.yearBuilt.map(String.init) ?? "—")
                                factRow("Rooms", property.rooms ?? "—")
                            }
                        }
                        GridRow {
                            factRow("Property use", property.useCode ?? "—")
                            factRow("Basement", property.basement ?? "—")
                        }
                        GridRow {
                            factRow("Garage", property.garage ?? "—")
                            factRow("A/C", property.airConditioning ?? "—")
                        }
                        GridRow {
                            factRow("Fireplace", property.fireplace ?? "—")
                            factRow("Pool", property.swimmingPool ?? "—")
                        }
                        GridRow {
                            factRow("Zoning", property.zoning ?? "—")
                            factRow("Roll number", property.rollNumber ?? "—")
                        }
                    }
                    taxEstimateNote(property)
                } else {
                    Text("No assessment record was returned for this address.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.krokvaInk3)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func factRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).eyebrow()
            Text(value)
                .font(label == "Roll number" ? KrokvaTypography.monoSmall : KrokvaTypography.body)
                .foregroundStyle(Color.krokvaInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func taxEstimateNote(_ property: PropertyAssessment) -> some View {
        if property.propertyTaxIsEstimated {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.krokvaInk3)
                    .padding(.top, 2)
                Text("Tax estimate uses 2026 residential mill rates; actual bill can vary by school division, credits, and local improvements.")
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.krokvaInk3)
            }
            .padding(.top, 2)
        }
    }

    private func propertyTaxLabel(_ property: PropertyAssessment) -> String {
        property.propertyTaxIsEstimated ? "Tax est. 2026" : "Property tax"
    }

    private func backyardArea(_ property: PropertyAssessment) -> String? {
        guard let lot = property.landArea, let living = property.livingArea, lot > living else { return nil }
        return area(lot - living)
    }
}
