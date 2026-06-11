import Charts
import SwiftUI

struct HealthView: View {
    let summary: PublicHealthSummary
    let neighbourhood: String

    var body: some View {
        ZStack {
            Color.cleanBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    heroCard
                    if summary.nearestER != nil || summary.nearestWalkIn != nil { accessCard }
                    if !summary.ageGroups.isEmpty { ageGroupsCard }
                    if !summary.substances.isEmpty { substancesCard }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .cleanNavBar(title: "Public Health")
    }

    // MARK: Hero — comparison donuts + trend bar

    private var heroCard: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Public Health Context")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    Text("Anonymized emergency events · \(neighbourhood)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.cleanLabel2)
                }

                // Two donuts + callout
                if let latest = summary.yearlyEvents.last {
                    HStack(alignment: .center, spacing: 24) {
                        VStack(spacing: 6) {
                            DonutRing(
                                value: latest.neighbourhood,
                                maxValue: max(latest.neighbourhood, 100),
                                size: 100, strokeWidth: 9,
                                color: .cleanSky,
                                centerSub: "NBHD"
                            )
                            Text("Neighbourhood")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.cleanLabel2)
                        }

                        VStack(spacing: 4) {
                            let ratio = latest.citywideAverage > 0
                                ? Double(latest.neighbourhood) / latest.citywideAverage
                                : 0
                            Text(String(format: "%.1f×", ratio))
                                .font(.system(size: 22, weight: .heavy).monospacedDigit())
                                .foregroundStyle(Color.cleanLabel)
                            Text("above city avg")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.4)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.cleanLabel3)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 6) {
                            DonutRing(
                                value: Int(latest.citywideAverage),
                                maxValue: max(Int(latest.citywideAverage), 100),
                                size: 100, strokeWidth: 9,
                                color: .cleanGreen,
                                centerSub: "CITY"
                            )
                            Text("City Average")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.cleanLabel2)
                        }
                    }
                }

                Divider().foregroundStyle(Color.cleanSep)

                // Historical trend bar chart
                if summary.yearlyEvents.count >= 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Historical Trend")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.cleanLabel2)

                        let years = summary.yearlyEvents
                        let maxYear = years.map(\.year).max() ?? 0
                        let avgLine = years.map(\.citywideAverage).last
                        let maxVal = years.map(\.neighbourhood).max() ?? 1

                        MiniBarChart(
                            bars: years.map { y in
                                MiniBarChart.Bar(
                                    id: "\(y.year)",
                                    value: y.neighbourhood,
                                    label: "\(y.year)",
                                    highlighted: y.year == maxYear
                                )
                            },
                            avgLine: avgLine.map { $0 / Double(maxVal) },
                            avgLineColor: .cleanGreen
                        )
                        .frame(height: 80)
                    }
                }
            }
        }
    }

    // MARK: Healthcare Access

    private var accessCard: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 16) {
                if let er = summary.nearestER {
                    facilitySection(eyebrow: "EMERGENCY ROOM", icon: "cross.fill", iconColor: .cleanRed, facility: er)
                }
                if let walkIn = summary.nearestWalkIn {
                    if summary.nearestER != nil { Divider().foregroundStyle(Color.cleanSep) }
                    facilitySection(eyebrow: "WALK-IN CLINIC", icon: "stethoscope", iconColor: .cleanSky, facility: walkIn)
                }
            }
        }
    }

    private func facilitySection(eyebrow: String, icon: String, iconColor: Color, facility: HealthFacilityAccess) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow).eyebrow(color: .cleanLabel3)
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
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
            if let status = facility.liveStatus {
                statusBlock(status)
            } else if let closure = summary.emergencyRoomClosures.first {
                statusBlock(closure)
            }
            if let attribution = facility.waitTimeAttribution {
                Text(attribution)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let attribution = summary.emergencyRoomAttribution {
                Text(attribution)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cleanLabel3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusBlock(_ status: EmergencyRoomStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(status.statusLabel)
                    .font(.system(size: 11, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(status.status.lowercased() == "closed" ? Color.cleanRed : Color.cleanAmber)
                if let expectedReopen = status.expectedReopen {
                    Text("Reopens \(expectedReopen.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel2)
                }
            }
            Text(status.message)
                .font(.system(size: 12))
                .foregroundStyle(Color.cleanLabel2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background((status.status.lowercased() == "closed" ? Color.cleanRed : Color.cleanAmber).opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    // MARK: Age Groups

    private let ageColors: [Color] = [.cleanSky, .cleanIndigo, Color(hex: 0x0EA5E9),
                                      Color(hex: 0x818CF8), Color(hex: 0x38BDF8), Color(hex: 0xA5B4FC)]

    private var ageGroupsCard: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Age Groups · \(neighbourhood)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)

                let maxVal = summary.ageGroups.map(\.count).max() ?? 1
                ForEach(Array(summary.ageGroups.enumerated()), id: \.offset) { i, group in
                    PillBar(
                        label: group.incidentType,
                        value: group.count,
                        maxValue: maxVal,
                        color: ageColors[i % ageColors.count],
                        animationDelay: Double(i) * 0.08
                    )
                }
            }
        }
    }

    // MARK: Substances

    private let substanceColors: [Color] = [.cleanSky, .cleanIndigo, .cleanAmber, .cleanRed, Color(hex: 0x10B981)]

    private var substancesCard: some View {
        CleanCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Substances Reported")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)

                let maxVal = summary.substances.map(\.count).max() ?? 1
                ForEach(Array(summary.substances.enumerated()), id: \.offset) { i, sub in
                    PillBar(
                        label: sub.incidentType,
                        value: sub.count,
                        maxValue: maxVal,
                        color: substanceColors[i % substanceColors.count],
                        animationDelay: Double(i) * 0.08
                    )
                }

                // Segmented summary bar
                let total = summary.substances.map(\.count).reduce(0, +)
                if total > 0 {
                    let segs = summary.substances.enumerated().map { i, s in
                        SegmentedBar.Segment(
                            id: s.incidentType,
                            color: substanceColors[i % substanceColors.count],
                            fraction: Double(s.count) / Double(total)
                        )
                    }
                    SegmentedBar(segments: segs, height: 8)
                        .padding(.top, 4)
                }
            }
        }
    }
}
