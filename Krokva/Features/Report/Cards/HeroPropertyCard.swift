import CoreLocation
import MapKit
import Observation
import SwiftData
import SwiftUI

struct HeroPropertyCard: View {
    let report: AddressReport
    /// Live MapKit views don't render in offscreen PDF export, so the map is skipped there.
    var showsMap: Bool = true
    @State private var camera: MapCameraPosition
    @State private var permitVM = PermitHistoryViewModel()
    @State private var selectedSection: ScoreSectionDetail?
    @Environment(\.modelContext) private var modelContext

    private var property: PropertyAssessment? { report.property }

    init(report: AddressReport, showsMap: Bool = true) {
        self.report = report
        self.showsMap = showsMap
        let coord = report.property?.coordinate
            ?? CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384)
        _camera = State(initialValue: .camera(MapCamera(
            centerCoordinate: coord,
            distance: 380,
            heading: 0,
            pitch: 65
        )))
    }

    var body: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                if showsMap {
                    mapSection
                }
                addressSection
                if property != nil {
                    Divider().foregroundStyle(Color.cleanSep)
                    houseScoreSection
                }
            }
        }
        .task { await permitVM.load(report: report, modelContext: modelContext) }
        .sheet(item: $selectedSection) { detail in
            ScoreBreakdownSheet(detail: detail)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        Map(position: $camera) {
            if let coord = property?.coordinate {
                Annotation("", coordinate: coord) {
                    ZStack {
                        Circle()
                            .fill(Color.cleanSky)
                            .frame(width: 34, height: 34)
                            .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
                        Image(systemName: "house.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .disabled(true)
        .frame(height: 200)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 18,
            style: .continuous
        ))
    }

    // MARK: - Address + Value

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let hood = property?.neighbourhood, !hood.isEmpty {
                        HStack(spacing: 5) {
                            Text(hood)
                                .eyebrow(color: .cleanLabel3)
                            if let postal = property?.postalCode, !postal.isEmpty {
                                Text("·")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.cleanLabel3)
                                Text(postal)
                                    .eyebrow(color: .cleanLabel3)
                            }
                        }
                    }
                    Text(property?.fullAddress ?? report.address.displayAddress)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.cleanLabel)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(report.cityName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                }
                Spacer(minLength: 8)
            }

            if property?.totalAssessedValue != nil {
                Divider().foregroundStyle(Color.cleanSep)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(money(property?.totalAssessedValue))
                            .font(.system(size: 28, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color.cleanLabel)
                            .minimumScaleFactor(0.65)
                            .lineLimit(1)
                        Text("Assessed value\(property?.assessmentYear.map { " · \($0)" } ?? "")")
                            .eyebrow(color: .cleanLabel3)
                    }
                    Spacer()
                    if let tax = property?.propertyTax {
                        Text("\(taxLabel) \(money(tax))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.cleanSky)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.cleanSkyWash, in: Capsule())
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: - House Score

    private var houseScoreSection: some View {
        let r = rating
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ScoreRing(score: Int(r.overall.rounded()), size: 60, strokeWidth: 5)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(r.grade)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
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
                VStack(alignment: .trailing, spacing: 2) {
                    Text("House score")
                        .eyebrow(color: .cleanLabel3)
                    Text("Tap a bar for why")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.cleanLabel3)
                }
            }

            VStack(spacing: 4) {
                scorePillBar("Property",    score: r.property,    rating: r, color: .cleanSky,           delay: 0.05)
                scorePillBar("Safety",      score: r.safety,      rating: r, color: .cleanAmber,         delay: 0.12)
                scorePillBar("Mobility",    score: r.mobility,    rating: r, color: .cleanGreen,         delay: 0.19)
                scorePillBar("Liveability", score: r.liveability, rating: r, color: .cleanIndigo,        delay: 0.26)
                scorePillBar("Risk",        score: r.risk,        rating: r, color: Color(hex: 0xEAB308), delay: 0.33)
            }

            if permitVM.isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading permit signals…")
                        .font(KrokvaTypography.caption)
                        .foregroundStyle(Color.cleanLabel3)
                }
            }

            Text("Neighbourhood signals reflect area context — not this address specifically. Score is informational only.")
                .font(KrokvaTypography.caption)
                .foregroundStyle(Color.cleanLabel3)
        }
        .padding(16)
    }

    @ViewBuilder
    private func scorePillBar(_ label: String, score: ReportRating.SectionScore, rating: ReportRating, color: Color, delay: Double) -> some View {
        Button {
            selectedSection = ScoreSectionDetail(
                name: label,
                color: color,
                section: score,
                effectiveWeight: rating.effectiveWeight(for: label)
            )
        } label: {
            HStack(spacing: 8) {
                PillBar(
                    label: label,
                    value: score.isUnavailable ? 0 : Int(score.score.rounded()),
                    maxValue: 100,
                    color: score.isUnavailable ? Color.cleanTrack : color,
                    animationDelay: delay
                )
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived

    private var rating: ReportRating {
        ReportRating.compute(report: report, permitHistory: permitVM.result)
    }

    private var overallScore: Int {
        Int(ReportRating.compute(report: report, permitHistory: permitVM.result).overall.rounded())
    }

    private var taxLabel: String {
        property?.propertyTaxIsEstimated == true ? "Tax est." : "Tax"
    }

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
