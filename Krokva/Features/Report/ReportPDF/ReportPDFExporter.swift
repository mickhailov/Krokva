import SwiftData
import SwiftUI
import UIKit

/// Renders the selected report cards into a paginated US-Letter PDF.
///
/// Each card is rendered offscreen with `ImageRenderer` using the *same* views
/// the on-screen report shows (via `ReportCardCatalog`), with
/// `\.reportPDFRender == true` so collapsible cards expand and appear-animated
/// components draw their final state. Pagination and page slicing live in the
/// shared `PDFPageComposer`.
enum ReportPDFExporter {
    private static let style = PDFPageComposer.Style()

    @MainActor
    static func export(report: AddressReport,
                       analytics: ReportAnalytics,
                       selectedCardIDs: Set<String>,
                       modelContext: ModelContext) -> URL? {
        var context = ReportCardContext(report: report, analytics: analytics)
        context.isPDF = true

        var images: [UIImage] = []
        if let header = PDFPageComposer.renderImage(AnyView(PDFHeaderView(report: report)), style: style, modelContext: modelContext) {
            images.append(header)
        }
        for card in ReportCardCatalog.all where card.includeInPDF && selectedCardIDs.contains(card.id) {
            if let image = PDFPageComposer.renderImage(card.makeView(context), style: style, modelContext: modelContext) {
                images.append(image)
            }
        }
        guard !images.isEmpty else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: report))
        let footerText = "Krokva · \(report.cityName) · \(report.attributionText)"
        let ok = PDFPageComposer.write(images: images, to: url, style: style) { cg, page in
            PDFPageComposer.drawCenteredFooter("\(footerText) · Page \(page)", in: cg, style: style)
        }
        return ok ? url : nil
    }

    private static func fileName(for report: AddressReport) -> String {
        let address = report.property?.fullAddress ?? report.address.displayAddress
        let slug = address
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "\(slug.isEmpty ? "Krokva" : slug)-Krokva-Report.pdf"
    }
}

private extension AddressReport {
    var attributionText: String {
        "Contains information licensed under the Open Government Licence – Winnipeg"
    }
}

// MARK: - PDF cover / header block

private struct PDFHeaderView: View {
    let report: AddressReport

    private var address: String {
        report.property?.fullAddress ?? report.address.displayAddress
    }

    // House Score is cheap and pure to recompute; permit history isn't needed
    // for the overall grade shown on the cover.
    private var rating: ReportRating {
        ReportRating.compute(report: report, permitHistory: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Krokva")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.cleanLabel)
                Spacer()
                Text("CIVIC ADDRESS DOSSIER")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.cleanLabel3)
            }
            Text(address)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.cleanLabel)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(report.cityName) · Generated \(Date.now.formatted(date: .long, time: .shortened))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.cleanLabel2)

            summaryStrip
                .padding(.top, 2)

            Divider()
                .foregroundStyle(Color.cleanSep)
        }
        .padding(.bottom, 4)
    }

    private var summaryStrip: some View {
        HStack(spacing: 10) {
            summaryTile("House Score", "\(Int(rating.overall.rounded())) · \(rating.grade)")
            if let assessed = report.property?.totalAssessedValue {
                summaryTile("Assessed", currency(assessed))
            }
            if let tax = report.property?.propertyTax {
                summaryTile("Property tax", currency(tax) + (report.property?.propertyTaxIsEstimated == true ? "*" : ""))
            }
            if let n = report.property?.neighbourhood, !n.isEmpty {
                summaryTile("Neighbourhood", n)
            }
        }
    }

    private func summaryTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Color.cleanLabel3)
            Text(value)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(Color.cleanLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.cleanCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.cleanSep, lineWidth: 1))
    }

    private func currency(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.2fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "$%.0fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }
}
