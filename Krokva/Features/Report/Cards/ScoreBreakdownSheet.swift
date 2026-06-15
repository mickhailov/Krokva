import SwiftUI

/// Identifiable payload describing one House Score section so it can drive a
/// `.sheet(item:)` breakdown of the individual signals behind its bar.
struct ScoreSectionDetail: Identifiable {
    let name: String
    let color: Color
    let section: ReportRating.SectionScore
    let effectiveWeight: Double

    var id: String { name }
}

/// "Why exactly this score?" — lists every signal that fed a section bar, with
/// its own sub-score, a plain-language value, and how the section rolls up.
struct ScoreBreakdownSheet: View {
    let detail: ScoreSectionDetail

    private var section: ReportRating.SectionScore { detail.section }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                if section.signals.isEmpty {
                    unavailable
                } else {
                    signalsList
                    Divider()
                    footer
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("House score · \(detail.name)")
                .eyebrow(color: .cleanLabel3)

            HStack(alignment: .center, spacing: 16) {
                ScoreRing(
                    score: section.isUnavailable ? 0 : Int(section.score.rounded()),
                    size: 64,
                    strokeWidth: 5
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.isUnavailable ? "No data" : "\(Int(section.score.rounded())) / 100")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(barColor)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cleanLabel3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private var subtitle: String {
        guard !section.isUnavailable else { return "No city data covers this section yet." }
        let weightPct = Int((detail.effectiveWeight * 100).rounded())
        let signalNote = "Average of \(section.signals.count) signal\(section.signals.count == 1 ? "" : "s")"
        return weightPct > 0 ? "\(signalNote) · \(weightPct)% of overall score" : signalNote
    }

    // MARK: - Signals

    private var signalsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(section.signals.enumerated()), id: \.element.id) { index, signal in
                if index > 0 {
                    Divider().padding(.leading, 20)
                }
                signalRow(signal)
            }
        }
    }

    private func signalRow(_ signal: ReportRating.Signal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(signal.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                Spacer(minLength: 12)
                Text("\(Int(signal.score.rounded()))")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(scoreColor(signal.score))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cleanTrack)
                    Capsule()
                        .fill(scoreColor(signal.score))
                        .frame(width: geo.size.width * CGFloat(min(signal.score, 100) / 100))
                }
            }
            .frame(height: 6)

            Text(signal.detail)
                .font(.system(size: 13))
                .foregroundStyle(Color.cleanLabel2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }

    // MARK: - Footer / empty

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if section.isPartial {
                Label(
                    "\(section.signals.count) of \(section.capacity) possible signals available for this address.",
                    systemImage: "info.circle"
                )
                .font(KrokvaTypography.caption)
                .foregroundStyle(Color.cleanLabel3)
            }
            Text("Each signal is scored 0–100, then averaged for the section. Neighbourhood signals reflect area context — not this address specifically.")
                .font(KrokvaTypography.caption)
                .foregroundStyle(Color.cleanLabel3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.cleanLabel)
            Text("The city sources for this section returned nothing for this address, so it doesn't contribute to the overall score.")
                .font(KrokvaTypography.bodySecondary)
                .foregroundStyle(Color.cleanLabel2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    // MARK: - Colors

    private var barColor: Color {
        section.isUnavailable ? .cleanLabel3 : scoreColor(section.score)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return .cleanGreen }
        if score >= 50 { return .cleanAmber }
        return .cleanRed
    }
}
