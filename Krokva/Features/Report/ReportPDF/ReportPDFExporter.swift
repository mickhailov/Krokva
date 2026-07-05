import SwiftData
import SwiftUI
import UIKit

/// Renders the selected report cards into a paginated US-Letter PDF.
///
/// Each card is rendered offscreen with `ImageRenderer` using the *same* views
/// the on-screen report shows (via `ReportCardCatalog`), with
/// `\.reportPDFRender == true` so collapsible cards expand and appear-animated
/// components draw their final state. Cards taller than a page are sliced
/// across page breaks.
enum ReportPDFExporter {
    private static let pageSize = CGSize(width: 612, height: 792) // US Letter, points
    private static let margin: CGFloat = 36
    private static let footerHeight: CGFloat = 26
    private static let cardSpacing: CGFloat = 14

    private static var contentWidth: CGFloat { pageSize.width - margin * 2 }
    private static var pageBottom: CGFloat { pageSize.height - margin - footerHeight }

    @MainActor
    static func export(report: AddressReport,
                       analytics: ReportAnalytics,
                       selectedCardIDs: Set<String>,
                       modelContext: ModelContext) -> URL? {
        var context = ReportCardContext(report: report, analytics: analytics)
        context.isPDF = true

        var images: [UIImage] = []
        if let header = renderImage(AnyView(PDFHeaderView(report: report)), modelContext: modelContext) {
            images.append(header)
        }
        for card in ReportCardCatalog.all where card.includeInPDF && selectedCardIDs.contains(card.id) {
            if let image = renderImage(card.makeView(context), modelContext: modelContext) {
                images.append(image)
            }
        }
        guard !images.isEmpty else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: report))
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        do {
            try renderer.writePDF(to: url) { pdf in
                var pageNumber = 0
                var cursorY = margin

                func beginPage() {
                    pdf.beginPage()
                    pageNumber += 1
                    cursorY = margin
                    drawFooter(in: pdf.cgContext, pageNumber: pageNumber, report: report)
                }

                beginPage()
                for image in images {
                    let height = image.size.height
                    // Start a new page when the card doesn't fit but would fit a fresh page.
                    if height > pageBottom - cursorY, height <= pageBottom - margin {
                        beginPage()
                    }
                    if height <= pageBottom - cursorY {
                        image.draw(in: CGRect(x: margin, y: cursorY, width: contentWidth, height: height))
                        cursorY += height + cardSpacing
                    } else {
                        // Taller than a full page: slice across pages.
                        var offset: CGFloat = 0
                        while offset < height {
                            let available = pageBottom - cursorY
                            let slice = min(available, height - offset)
                            let cg = pdf.cgContext
                            cg.saveGState()
                            cg.clip(to: CGRect(x: margin, y: cursorY, width: contentWidth, height: slice))
                            image.draw(in: CGRect(x: margin, y: cursorY - offset, width: contentWidth, height: height))
                            cg.restoreGState()
                            offset += slice
                            cursorY += slice
                            if offset < height { beginPage() }
                        }
                        cursorY += cardSpacing
                    }
                }
            }
        } catch {
            return nil
        }
        return url
    }

    // MARK: - Rendering

    @MainActor
    private static func renderImage(_ view: AnyView, modelContext: ModelContext) -> UIImage? {
        let renderer = ImageRenderer(content:
            view
                .environment(\.reportPDFRender, true)
                .environment(\.colorScheme, .light)
                .modelContext(modelContext)
                .frame(width: contentWidth)
        )
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: contentWidth, height: nil)
        guard let image = renderer.uiImage, image.size.height > 1 else { return nil }
        return image
    }

    private static func drawFooter(in cg: CGContext, pageNumber: Int, report: AddressReport) {
        let text = "Krokva · \(report.cityName) · \(report.attributionText) · Page \(pageNumber)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .medium),
            .foregroundColor: UIColor.gray
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.size()
        attributed.draw(at: CGPoint(
            x: (pageSize.width - min(size.width, contentWidth)) / 2,
            y: pageSize.height - margin * 0.5 - size.height / 2
        ))
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

// MARK: - PDF header block

private struct PDFHeaderView: View {
    let report: AddressReport

    private var address: String {
        report.property?.fullAddress ?? report.address.displayAddress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            Divider()
                .foregroundStyle(Color.cleanSep)
        }
        .padding(.bottom, 4)
    }
}
