import SwiftUI

// MARK: - PublicHealthCard

struct PublicHealthCard: View {
    let summary: PublicHealthSummary
    let neighbourhood: String
    @State private var isExpanded = false
    @Environment(\.reportPDFRender) private var pdfRender

    var body: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                headerButton
                if isExpanded || pdfRender {
                    Divider()
                    HealthInlineContent(summary: summary, neighbourhood: neighbourhood)
                        .padding(18)
                }
            }
        }
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanSky, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Public Health")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if !isExpanded {
                        Text(subtitle)
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

    private var subtitle: String {
        var parts: [String] = []
        if let minutes = summary.nearestER?.driveMinutes {
            parts.append("ER \(Int(minutes.rounded())) min")
        }
        if let count = summary.walkInClinicsNearby {
            parts.append("\(count) walk-ins")
        }
        if let aed = summary.nearestAED {
            parts.append("AED \(aed.distanceDescription)")
        }
        return parts.isEmpty ? "Emergency activity · age groups · substances" : parts.joined(separator: " · ")
    }
}

// MARK: - Service311Card

struct Service311Card: View {
    let summary: ServiceRequestSummary
    @State private var isExpanded = false
    @Environment(\.reportPDFRender) private var pdfRender

    var body: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                headerButton
                if isExpanded || pdfRender {
                    Divider()
                    Service311InlineContent(summary: summary)
                        .padding(18)
                }
            }
        }
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "phone.badge.waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanIndigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("311 Activity")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if !isExpanded {
                        Text(subtitle)
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

    private var subtitle: String {
        var parts: [String] = ["\(summary.totalLastYear.formatted()) calls"]
        if summary.totalLastYear > 0 {
            let pct = Int((Double(summary.closedLastYear) / Double(summary.totalLastYear) * 100).rounded())
            parts.append("\(pct)% closed")
        }
        if let top = summary.topReasons.first {
            let label = top.incidentType.count > 20
                ? String(top.incidentType.prefix(20)) + "…"
                : top.incidentType
            parts.append(label)
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - HealthInlineContent

struct HealthInlineContent: View {
    let summary: PublicHealthSummary
    let neighbourhood: String

    private let ageColors: [Color] = [.cleanSky, .cleanIndigo, Color(hex: 0x0EA5E9),
                                      Color(hex: 0x818CF8), Color(hex: 0x38BDF8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let er = summary.nearestER {
                facilitySection(eyebrow: "EMERGENCY ROOM", icon: "cross.fill", iconColor: .cleanRed, facility: er)
            }
            if let walkIn = summary.nearestWalkIn {
                if summary.nearestER != nil { Divider().foregroundStyle(Color.cleanSep) }
                facilitySection(eyebrow: "WALK-IN CLINIC", icon: "stethoscope", iconColor: .cleanSky, facility: walkIn)
            }
            if summary.nearestER != nil || summary.nearestWalkIn != nil { Divider().foregroundStyle(Color.cleanSep) }
            if let aed = summary.nearestAED {
                aedSection(aed)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PUBLIC AED").eyebrow(color: .cleanLabel3)
                    Text("No AEDs within 500 m")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cleanLabel2)
                }
            }
            if !summary.ageGroups.isEmpty {
                Divider().foregroundStyle(Color.cleanSep)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age groups · \(neighbourhood)").eyebrow(color: .cleanLabel3)
                    let maxVal = summary.ageGroups.map(\.count).max() ?? 1
                    ForEach(Array(summary.ageGroups.enumerated()), id: \.offset) { i, group in
                        PillBar(label: group.incidentType, value: group.count, maxValue: maxVal,
                                color: ageColors[i % ageColors.count], animationDelay: Double(i) * 0.08)
                    }
                }
            }
        }
    }

    private func facilitySection(eyebrow: String, icon: String, iconColor: Color, facility: HealthFacilityAccess) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow).eyebrow(color: .cleanLabel3)
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 26, height: 26)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text(facility.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if let address = facility.address {
                        Text(address)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cleanLabel2)
                            .lineLimit(1)
                    }
                }
            }
            if let driveMinutes = facility.driveMinutes {
                statRow(label: "Drive time", value: "\(Int(driveMinutes.rounded())) min")
            }
            if let currentWaitMinutes = facility.currentWaitMinutes {
                statRow(label: "Current wait", value: formattedWait(minutes: currentWaitMinutes))
                if let waiting = facility.waitingPatients, let treating = facility.treatingPatients {
                    statRow(label: "Waiting / treating", value: "\(waiting) / \(treating)")
                }
                if let updatedAt = facility.waitTimeUpdatedAt {
                    Text("WRHA updated \(updatedAt)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cleanLabel3)
                }
            } else if let avgWaitMinutes = facility.avgWaitMinutes {
                statRow(label: "Avg. wait time", value: formattedWait(minutes: avgWaitMinutes))
            }
            if let attribution = facility.waitTimeAttribution {
                Text(attribution)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func aedSection(_ aed: DefibrillatorAccess) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PUBLIC AED").eyebrow(color: .cleanLabel3)
            HStack(spacing: 10) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.cleanRed)
                    .frame(width: 26, height: 26)
                    .background(Color.cleanRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text(aed.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if let location = aed.locationDescription {
                        Text(location)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.cleanLabel2)
                            .lineLimit(2)
                    }
                }
            }
            statRow(label: "Distance", value: aed.distanceDescription)
            if let count = summary.aedsNearby {
                statRow(label: "AEDs within 500 m", value: count.formatted())
            }
            let detail = [aed.access, aed.indoor.map { $0 ? "Indoor" : "Outdoor" }, aed.source].compactMap { $0 }.joined(separator: " · ")
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func formattedWait(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "\(hours) hr" }
        return "\(hours) hr \(remainingMinutes) min"
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.cleanLabel2)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.cleanLabel)
        }
    }

}

// MARK: - Service311InlineContent

struct Service311InlineContent: View {
    let summary: ServiceRequestSummary

    private let reasonColors: [Color] = [.cleanSky, .cleanIndigo, Color(hex: 0x0EA5E9),
                                         Color(hex: 0x10B981), .cleanAmber]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Totals
            HStack(spacing: 0) {
                donutCell(value: summary.totalLastYear,
                          maxValue: max(summary.totalLastYear, 400),
                          color: .cleanIndigo, label: "Total")
                Divider().frame(height: 80)
                donutCell(value: summary.openLastYear,
                          maxValue: max(summary.totalLastYear, 1),
                          color: .cleanAmber, label: "Open")
                Divider().frame(height: 80)
                donutCell(value: summary.closedLastYear,
                          maxValue: max(summary.totalLastYear, 1),
                          color: .cleanGreen, label: "Closed")
            }

            // Monthly trend
            if !summary.monthlyTrend.isEmpty {
                let recent = Array(summary.monthlyTrend.suffix(12))
                let maxYear = recent.map(\.year).max() ?? 0
                let maxMonth = recent.filter { $0.year == maxYear }.map(\.month).max() ?? 0
                VStack(alignment: .leading, spacing: 6) {
                    Text("Monthly volume").eyebrow(color: .cleanLabel3)
                    MiniBarChart(
                        bars: recent.map { m in
                            MiniBarChart.Bar(id: m.id, value: m.count, label: m.label,
                                            highlighted: m.year == maxYear && m.month == maxMonth)
                        },
                        accentColor: .cleanIndigo,
                        baseColor: Color(hex: 0x6366F1).opacity(0.65)
                    )
                    .frame(height: 80)
                }
            }

            // Top reasons
            if !summary.topReasons.isEmpty {
                Divider().foregroundStyle(Color.cleanSep)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top reasons").eyebrow(color: .cleanLabel3)
                    let maxVal = summary.topReasons.map(\.count).max() ?? 1
                    ForEach(Array(summary.topReasons.prefix(5).enumerated()), id: \.offset) { i, reason in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(reasonColors[i % reasonColors.count])
                                .frame(width: 7, height: 7)
                            Text(reason.incidentType)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Color.cleanLabel)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 8)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.cleanTrack)
                                    Capsule()
                                        .fill(reasonColors[i % reasonColors.count])
                                        .frame(width: maxVal > 0
                                               ? geo.size.width * CGFloat(reason.count) / CGFloat(maxVal) : 0)
                                }
                            }
                            .frame(width: 90, height: 6)
                            Text("\(reason.count)")
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color.cleanLabel3)
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                }
            }

            Text("311 locations are privacy-adjusted · shown as \(summary.neighbourhood) context only.")
                .font(.system(size: 10))
                .foregroundStyle(Color.cleanLabel3)
        }
    }

    private func donutCell(value: Int, maxValue: Int, color: Color, label: String) -> some View {
        VStack(spacing: 6) {
            DonutRing(value: value, maxValue: maxValue, size: 86, strokeWidth: 8, color: color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.cleanLabel2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ParksInlineContent

struct ParksInlineContent: View {
    let summary: ParksSummary

    private let dotColors: [Color] = [.cleanSky, .cleanIndigo, Color(hex: 0x10B981)]
    private let gradients: [(Color, Color)] = [
        (Color(hex: 0xE0F2FE), Color(hex: 0xBAE6FD)),
        (Color(hex: 0xEDE9FE), Color(hex: 0xDDD6FE)),
        (Color(hex: 0xD1FAE5), Color(hex: 0xA7F3D0)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(summary.nearbyParks.enumerated()), id: \.offset) { i, park in
                parkRow(park: park, index: i)
            }
            if let hectares = summary.neighbourhoodHectares {
                Text("\(hectares.formatted(.number.precision(.fractionLength(1)))) ha of mapped parks in this neighbourhood.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
            }
        }
    }

    private func parkRow(park: ParkAmenity, index: Int) -> some View {
        let (gradStart, gradEnd) = gradients[index % gradients.count]
        let color = dotColors[index % dotColors.count]
        let totalAssets = park.playgrounds + park.benches + park.courts + park.fields + park.washrooms
        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: [gradStart, gradEnd],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white.opacity(0.68))
                            .frame(width: 30, height: 30)
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(park.name)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(Color.cleanLabel)
                        Text(park.distanceDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cleanLabel2)
                    }
                }

                HStack(spacing: 8) {
                    miniTile("Playgrounds", "\(park.playgrounds)", color)
                    miniTile("Benches", "\(park.benches)", color)
                    miniTile("Assets", "\(totalAssets)", color)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.5)).frame(height: 4)
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * min(CGFloat(totalAssets) / 51, 1), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(14)
        }
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 1)
    }

    private func miniTile(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .heavy).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.cleanLabel2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct ReportCard<Content: View>: View {
    let title: String
    var systemImage: String?
    var iconColor: Color = .cleanSky
    var badge: String? = nil
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(iconColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.cleanLabel)
                        if let subtitle {
                            Text(subtitle)
                                .eyebrow(color: .cleanLabel3)
                        }
                    }
                    Spacer(minLength: 0)
                    if let badge {
                        Text(badge)
                            .eyebrow(color: .cleanLabel3)
                    }
                }
                content
            }
        }
    }
}

struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.cleanLabel)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.cleanLabel3)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.cleanBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cleanSep, lineWidth: 0.5))
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .foregroundStyle(Color.cleanLabel2)
            Spacer(minLength: 16)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(Color.cleanLabel)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Report retry environment

struct ReportRetryActionKey: EnvironmentKey {
    static let defaultValue: (() async -> Void)? = nil
}

extension EnvironmentValues {
    var reportRetryAction: (() async -> Void)? {
        get { self[ReportRetryActionKey.self] }
        set { self[ReportRetryActionKey.self] = newValue }
    }
}

// MARK: - Empty / error states

struct EmptyCardState: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundStyle(Color.cleanLabel3)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.cleanLabel2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

/// Body shown when a card’s data source failed to load (network/HTTP error), as opposed to
/// loading successfully with no rows. Distinguished from `EmptyCardState` by tone + icon so
/// a failure reads as recoverable rather than "nothing here". Shows a retry button when a
/// `reportRetryAction` is set in the environment.
struct DatabaseErrorState: View {
    var message: String = "Database error — couldn’t load this data."

    @Environment(\.reportRetryAction) private var retryAction
    @State private var isRetrying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(Color.cleanRed)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.cleanLabel2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            if let retry = retryAction {
                Button {
                    guard !isRetrying else { return }
                    isRetrying = true
                    Task {
                        await retry()
                        isRetrying = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isRetrying {
                            ProgressView().scaleEffect(0.75)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(isRetrying ? "Retrying…" : "Retry")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.cleanSky)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.cleanSky.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isRetrying)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A full card shell rendered in place of a card that would otherwise hide on empty, so a
/// load failure surfaces as "Database error" instead of the card silently disappearing.
struct ModuleErrorCard: View {
    let title: String
    var systemImage: String
    var iconColor: Color = .cleanRed
    var message: String = "Database error — couldn’t load this data."

    var body: some View {
        ReportCard(title: title, systemImage: systemImage, iconColor: iconColor) {
            DatabaseErrorState(message: message)
        }
    }
}
