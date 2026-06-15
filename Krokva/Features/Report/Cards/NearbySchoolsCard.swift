import SwiftUI

// MARK: - NearbySchoolsCard

struct NearbySchoolsCard: View {
    let schools: [SchoolAmenity]
    let property: PropertyAssessment?
    let schoolZone: SchoolSpeedLimit?
    let civicContext: AddressCivicContext?
    var sourceFailed = false

    @State private var isExpanded = false

    // Estimated school division levy from the property's assessed value.
    // Uses Winnipeg's 2026 average combined residential mill rate of 27.405 mills
    // applied to the portioned value (45% of assessed).
    private var estimatedSchoolLevy: Double? {
        guard let val = property?.totalAssessedValue, val > 0 else { return nil }
        return val * 0.45 * 27.405 / 1_000
    }

    var body: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                headerButton
                if isExpanded {
                    Divider()
                    fullContent
                        .padding(18)
                }
            }
        }
    }

    // MARK: Header

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "graduationcap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanIndigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Schools")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if !isExpanded {
                        Text(smallSummary)
                            .font(.system(size: 13, weight: .semibold))
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
        var parts: [String] = []
        let assigned = schools.filter(\.isAssigned)
        if !assigned.isEmpty {
            parts.append("\(assigned.count) assigned")
        } else if !schools.isEmpty {
            parts.append("\(schools.count) \(schools.count == 1 ? "school" : "schools") nearby")
        }
        if parts.isEmpty { return "Tap to view" }
        return parts.joined(separator: " · ")
    }

    // MARK: Full content

    @ViewBuilder
    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 14) {

            // School list
            if !schools.isEmpty {
                let assignedSchools = schools.filter(\.isAssigned)
                let nearbySchools = assignedSchools.isEmpty ? schools : schools.filter { !$0.isAssigned }

                if !assignedSchools.isEmpty {
                    schoolList(title: "Assigned schools", schools: assignedSchools)
                }

                if !nearbySchools.isEmpty {
                    if !assignedSchools.isEmpty {
                        Divider().foregroundStyle(Color.cleanSep)
                    }
                    schoolList(title: "Nearby schools", schools: nearbySchools)
                }
            } else {
                Text(sourceFailed ? "Database error loading nearby schools." : "No nearby schools found in city data.")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.cleanLabel2)
            }

            // School zone speed limit
            if let zone = schoolZone {
                Divider().foregroundStyle(Color.cleanSep)
                VStack(alignment: .leading, spacing: 8) {
                    Text("School zone").eyebrow(color: .cleanLabel3)
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.cleanAmberWash)
                                .frame(width: 44, height: 44)
                            Text(zone.speedLimit)
                                .font(.system(size: 13, weight: .heavy).monospacedDigit())
                                .foregroundStyle(Color.cleanAmber)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.school)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.cleanLabel)
                                .lineLimit(2)
                            Text([zone.effectiveDays, zone.effectiveTime].compactMap { $0 }.joined(separator: " · "))
                                .font(KrokvaTypography.caption)
                                .foregroundStyle(Color.cleanLabel3)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            // School division
            if let context = civicContext, context.schoolDivision != nil
                || context.schoolDivisionCode != nil
                || context.schoolDivisionWard != nil
                || context.schoolDivisionBoundaryName != nil {
                if schoolZone != nil || !schools.isEmpty {
                    Divider().foregroundStyle(Color.cleanSep)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("School division").eyebrow(color: .cleanLabel3)
                    if let division = context.schoolDivision {
                        Text(division)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Color.cleanLabel)
                    }
                    if let code = context.schoolDivisionCode {
                        KeyValueRow(key: "Division no.", value: "#\(code)")
                    }
                    if let ward = context.schoolDivisionWard {
                        KeyValueRow(key: "School ward", value: ward)
                    }
                    if let boundary = context.schoolDivisionBoundaryName {
                        KeyValueRow(key: "Boundary", value: boundary)
                    }
                    if let website = context.schoolDivisionWebsite,
                       let url = URL(string: website) {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Image(systemName: "safari")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(website)
                                    .font(KrokvaTypography.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(Color.cleanSky)
                        }
                    }
                }
            }

            // School tax estimate
            Divider().foregroundStyle(Color.cleanSep)
            VStack(alignment: .leading, spacing: 8) {
                Text("School division levy").eyebrow(color: .cleanLabel3)
                if let levy = estimatedSchoolLevy {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(levy.formatted(.currency(code: "CAD").precision(.fractionLength(0))))
                            .font(.system(size: 22, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color.cleanLabel)
                        Text("/ year (est.)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.cleanLabel3)
                    }
                    Grid(horizontalSpacing: 12, verticalSpacing: 0) {
                        GridRow {
                            levyTile("Portioned value", (property?.totalAssessedValue ?? 0) * 0.45)
                            levyTile("Mill rate", nil, label: "27.405 mills")
                        }
                    }
                    Text("Estimated using Winnipeg's 2026 average combined school division residential mill rate of 27.405 mills on 45% portioned value. Actual levy varies by school division.")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cleanLabel3)
                } else {
                    Text("Assessed value required for estimate.")
                        .font(KrokvaTypography.bodySecondary)
                        .foregroundStyle(Color.cleanLabel2)
                }
            }
        }
    }

    // MARK: Row

    private func schoolList(title: String, schools: [SchoolAmenity]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).eyebrow(color: .cleanLabel3)
                .padding(.bottom, 6)
            ForEach(Array(schools.enumerated()), id: \.element.id) { index, school in
                schoolRow(school, index: index)
                if index < schools.count - 1 {
                    Divider().foregroundStyle(Color.cleanSep)
                }
            }
        }
    }

    private func schoolRow(_ school: SchoolAmenity, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.cleanIndigo.opacity(0.1))
                    .frame(width: 30, height: 30)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.cleanIndigo)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(school.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                    .lineLimit(2)
                Text([school.schoolType, school.grades.map { "Grades \($0)" }].compactMap { $0 }.joined(separator: " · "))
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel2)
                    .lineLimit(2)

                if !school.programs.isEmpty {
                    FlexibleTagRow(tags: Array(school.programs.prefix(3)))
                }

                Text([school.address, school.walkingTimeDescription].compactMap { $0 }.joined(separator: " · "))
                    .font(KrokvaTypography.caption)
                    .foregroundStyle(Color.cleanLabel3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            VStack(alignment: .trailing, spacing: 2) {
                Text(school.distanceDescription)
                    .font(KrokvaTypography.monoSmall)
                    .foregroundStyle(Color.cleanLabel3)
                if school.isAssigned {
                    Text("zone")
                        .font(KrokvaTypography.monoSmall)
                        .foregroundStyle(Color.cleanIndigo)
                }
            }
            .frame(width: 62, alignment: .trailing)
        }
        .padding(.vertical, 9)
    }

    // MARK: Levy tile

    private func levyTile(_ label: String, _ value: Double?, label valueLabel: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).eyebrow(color: .cleanLabel3)
            Text(valueLabel ?? (value.map { $0.formatted(.currency(code: "CAD").precision(.fractionLength(0))) } ?? "—"))
                .font(KrokvaTypography.monoBold)
                .foregroundStyle(Color.cleanLabel)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct FlexibleTagRow: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.cleanIndigo)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.cleanIndigo.opacity(0.08), in: Capsule())
                    .lineLimit(1)
            }
        }
    }
}
