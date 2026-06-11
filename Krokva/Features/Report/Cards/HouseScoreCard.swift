import Observation
import SwiftData
import SwiftUI

struct HouseScoreCard: View {
    let report: AddressReport

    @Environment(\.modelContext) private var modelContext
    @State private var permitVM = PermitHistoryViewModel()

    private var rating: ReportRating {
        ReportRating.compute(report: report, permitHistory: permitVM.result)
    }

    var body: some View {
        ReportCard(title: "House score", systemImage: "star.circle", iconColor: .cleanAmber) {
            if report.property == nil {
                Text("Score unavailable — no assessment record for this address.")
                    .font(KrokvaTypography.bodySecondary)
                    .foregroundStyle(Color.cleanLabel2)
            } else {
                let r = rating
                overallHeader(r)
                sectionBars(r)
                if permitVM.isLoading { permitLoadingRow }
                disclaimerText
            }
        }
        .task { await permitVM.load(report: report, modelContext: modelContext) }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func overallHeader(_ r: ReportRating) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ScoreRing(score: Int(r.overall.rounded()), size: 64, strokeWidth: 5)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(r.grade)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(gradeColor(r.overall))
                    Text("grade")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.cleanLabel3)
                }
                Text("\(r.totalDataPoints) signals · \(summaryLabel(r.overall))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cleanLabel3)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func sectionBars(_ r: ReportRating) -> some View {
        VStack(spacing: 4) {
            bar("Property",    score: r.property,    color: .cleanSky,    delay: 0.05)
            bar("Safety",      score: r.safety,      color: .cleanAmber,  delay: 0.12)
            bar("Mobility",    score: r.mobility,    color: .cleanGreen,  delay: 0.19)
            bar("Liveability", score: r.liveability, color: .cleanIndigo, delay: 0.26)
            bar("Risk",        score: r.risk,        color: Color(hex: 0xEAB308), delay: 0.33)
        }
    }

    @ViewBuilder
    private func bar(
        _ label: String, score: ReportRating.SectionScore, color: Color, delay: Double
    ) -> some View {
        PillBar(
            label: label,
            value: score.isUnavailable ? 0 : Int(score.score.rounded()),
            maxValue: 100,
            color: score.isUnavailable ? Color.cleanTrack : color,
            animationDelay: delay
        )
    }

    @ViewBuilder
    private var permitLoadingRow: some View {
        HStack(spacing: 6) {
            ProgressView().scaleEffect(0.7)
            Text("Loading permit history…")
                .font(KrokvaTypography.caption)
                .foregroundStyle(Color.cleanLabel3)
        }
    }

    @ViewBuilder
    private var disclaimerText: some View {
        Text("Neighbourhood signals (safety, mobility, liveability) reflect area context — not this address specifically. Score is informational only.")
            .font(KrokvaTypography.caption)
            .foregroundStyle(Color.cleanLabel3)
    }

    // MARK: - Helpers

    private func gradeColor(_ score: Double) -> Color {
        if score >= 80 { return .cleanGreen }
        if score >= 60 { return .cleanAmber }
        return .cleanRed
    }

    private func summaryLabel(_ score: Double) -> String {
        switch score {
        case 85...: return "excellent"
        case 70..<85: return "above avg"
        case 50..<70: return "average"
        default: return "below avg"
        }
    }
}
