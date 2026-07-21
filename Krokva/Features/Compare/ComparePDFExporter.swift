import SwiftData
import SwiftUI
import UIKit

/// Renders the address comparison — cover, moving verdict, and the full
/// comparison table — into a paginated US-Letter PDF, reusing `PDFPageComposer`.
enum ComparePDFExporter {
    private static let style = PDFPageComposer.Style()

    @MainActor
    static func export(props: [SavedReport],
                       reports: [AddressReport?],
                       currentIndex: Int?,
                       verdict: RelocationVerdict?,
                       modelContext: ModelContext) -> URL? {
        guard props.count >= 2 else { return nil }

        var images: [UIImage] = []
        if let cover = PDFPageComposer.renderImage(
            AnyView(CompareCoverView(props: props, currentIndex: currentIndex)),
            style: style, modelContext: modelContext) {
            images.append(cover)
        }
        if let verdict, let card = PDFPageComposer.renderImage(
            AnyView(RelocationVerdictCard(verdict: verdict)),
            style: style, modelContext: modelContext) {
            images.append(card)
        }
        if let table = PDFPageComposer.renderImage(
            AnyView(CompareTableView(props: props, reports: reports, currentIndex: currentIndex)),
            style: style, modelContext: modelContext) {
            images.append(table)
        }
        guard !images.isEmpty else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName())
        let ok = PDFPageComposer.write(images: images, to: url, style: style) { cg, page in
            PDFPageComposer.drawCenteredFooter(
                "Krokva · Address comparison · Page \(page)", in: cg, style: style)
        }
        return ok ? url : nil
    }

    private static func fileName() -> String {
        "Krokva-Address-Comparison.pdf"
    }
}
