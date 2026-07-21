import SwiftData
import SwiftUI
import UIKit

/// Shared US-Letter PDF layout engine used by both the report and the compare
/// exporters. Takes a list of pre-rendered card images (full content width) and
/// paginates them: cards that fit are drawn, cards that don't start a fresh
/// page, and cards taller than a page are sliced across page breaks. A
/// per-page footer is drawn via the caller's closure.
enum PDFPageComposer {
    struct Style {
        var pageSize = CGSize(width: 612, height: 792) // US Letter, points
        var margin: CGFloat = 36
        var footerHeight: CGFloat = 26
        var cardSpacing: CGFloat = 14

        var contentWidth: CGFloat { pageSize.width - margin * 2 }
        var pageBottom: CGFloat { pageSize.height - margin - footerHeight }
    }

    /// Renders a SwiftUI view to a full-content-width image, forcing light mode
    /// and the PDF-render environment so collapsible cards expand and animated
    /// components draw their final state.
    @MainActor
    static func renderImage(_ view: AnyView,
                            style: Style,
                            modelContext: ModelContext? = nil) -> UIImage? {
        var content: AnyView = AnyView(
            view
                .environment(\.reportPDFRender, true)
                .environment(\.colorScheme, .light)
                .frame(width: style.contentWidth)
        )
        if let modelContext {
            content = AnyView(content.modelContext(modelContext))
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: style.contentWidth, height: nil)
        guard let image = renderer.uiImage, image.size.height > 1 else { return nil }
        return image
    }

    /// Writes `images` into a paginated PDF at `url`. `footer` draws whatever
    /// per-page footer text the caller wants, given the CG context and 1-based
    /// page number. Returns true on success.
    static func write(images: [UIImage],
                      to url: URL,
                      style: Style = Style(),
                      footer: @escaping (CGContext, Int) -> Void) -> Bool {
        guard !images.isEmpty else { return false }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: style.pageSize))
        do {
            try renderer.writePDF(to: url) { pdf in
                var pageNumber = 0
                var cursorY = style.margin

                func beginPage() {
                    pdf.beginPage()
                    pageNumber += 1
                    cursorY = style.margin
                    footer(pdf.cgContext, pageNumber)
                }

                beginPage()
                for image in images {
                    let height = image.size.height
                    if height > style.pageBottom - cursorY, height <= style.pageBottom - style.margin {
                        beginPage()
                    }
                    if height <= style.pageBottom - cursorY {
                        image.draw(in: CGRect(x: style.margin, y: cursorY, width: style.contentWidth, height: height))
                        cursorY += height + style.cardSpacing
                    } else {
                        // Taller than a full page: slice across pages.
                        var offset: CGFloat = 0
                        while offset < height {
                            let available = style.pageBottom - cursorY
                            let slice = min(available, height - offset)
                            let cg = pdf.cgContext
                            cg.saveGState()
                            cg.clip(to: CGRect(x: style.margin, y: cursorY, width: style.contentWidth, height: slice))
                            image.draw(in: CGRect(x: style.margin, y: cursorY - offset, width: style.contentWidth, height: height))
                            cg.restoreGState()
                            offset += slice
                            cursorY += slice
                            if offset < height { beginPage() }
                        }
                        cursorY += style.cardSpacing
                    }
                }
            }
        } catch {
            return false
        }
        return true
    }

    /// Convenience: draw a centered grey footer string near the page bottom.
    static func drawCenteredFooter(_ text: String, in cg: CGContext, style: Style) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5, weight: .medium),
            .foregroundColor: UIColor.gray
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.size()
        attributed.draw(at: CGPoint(
            x: (style.pageSize.width - min(size.width, style.contentWidth)) / 2,
            y: style.pageSize.height - style.margin * 0.5 - size.height / 2
        ))
    }
}
