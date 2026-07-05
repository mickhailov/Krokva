import SwiftData
import SwiftUI

/// Lets the user pick which report cards go into the PDF, generate it, and
/// share the file. The checkbox list is driven by `ReportCardCatalog`, so new
/// cards show up here automatically.
struct ExportReportSheet: View {
    let report: AddressReport
    let analytics: ReportAnalytics

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selected: Set<String>
    @State private var isGenerating = false
    @State private var shareItem: ShareItem?

    private struct ShareItem: Identifiable {
        let url: URL
        var id: String { url.path }
    }

    init(report: AddressReport, analytics: ReportAnalytics) {
        self.report = report
        self.analytics = analytics
        _selected = State(initialValue: Set(ReportCardCatalog.all.filter(\.includeInPDF).map(\.id)))
    }

    private var exportableIDs: Set<String> {
        Set(ReportCardCatalog.all.filter(\.includeInPDF).map(\.id))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cleanBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Choose which cards to include. Cards without data for this address are skipped automatically.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.cleanLabel2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            selectionChip("Select all", disabled: selected == exportableIDs) {
                                selected = exportableIDs
                            }
                            selectionChip("Select none", disabled: selected.isEmpty) {
                                selected.removeAll()
                            }
                            Spacer()
                            Text("\(selected.count)/\(exportableIDs.count)")
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color.cleanLabel3)
                        }

                        ForEach(ReportCardCatalog.pdfSections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title).eyebrow(color: .cleanLabel3)
                                VStack(spacing: 0) {
                                    ForEach(Array(section.cards.enumerated()), id: \.element.id) { position, card in
                                        checkboxRow(card)
                                        if position < section.cards.count - 1 {
                                            Divider()
                                                .foregroundStyle(Color.cleanSep)
                                                .padding(.leading, 46)
                                        }
                                    }
                                }
                                .background(Color.cleanCard)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle("Export PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.cleanLabel2)
                }
            }
            .safeAreaInset(edge: .bottom) {
                generateButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.cleanBg)
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
    }

    private func selectionChip(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(disabled ? Color.cleanLabel3 : Color.cleanSky)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.cleanCard, in: Capsule())
                .overlay(Capsule().stroke(Color.cleanSep, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func checkboxRow(_ card: ReportCardDescriptor) -> some View {
        let isOn = selected.contains(card.id)
        return Button {
            if isOn { selected.remove(card.id) } else { selected.insert(card.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isOn ? Color.cleanSky : Color.cleanLabel3)
                    .contentTransition(.symbolEffect(.replace))
                Image(systemName: card.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel2)
                    .frame(width: 20)
                Text(card.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.cleanLabel)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var generateButton: some View {
        Button {
            generate()
        } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isGenerating ? "Generating…" : "Generate PDF")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected.isEmpty || isGenerating ? Color.cleanLabel3 : Color.cleanSky, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(selected.isEmpty || isGenerating)
    }

    private func generate() {
        guard !isGenerating, !selected.isEmpty else { return }
        isGenerating = true
        let ids = selected
        Task { @MainActor in
            // Let the button repaint into its progress state before the
            // main-thread render work starts.
            await Task.yield()
            let url = ReportPDFExporter.export(
                report: report,
                analytics: analytics,
                selectedCardIDs: ids,
                modelContext: modelContext
            )
            isGenerating = false
            if let url {
                shareItem = ShareItem(url: url)
            }
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
