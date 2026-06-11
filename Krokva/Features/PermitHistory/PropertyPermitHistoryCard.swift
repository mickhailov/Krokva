import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class PermitHistoryViewModel {
    var result: PermitHistoryResult?
    var isLoading = false

    private let service: PermitHistoryService = WinnipegPermitHistoryService()

    func load(report: AddressReport, modelContext: ModelContext, forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        result = await service.history(for: report, modelContext: modelContext, forceRefresh: forceRefresh)
    }
}

struct PropertyPermitHistoryCard: View {
    let report: AddressReport
    let refreshToken: UUID

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PermitHistoryViewModel()
    @State private var isExpanded = false

    var body: some View {
        CleanCard(padding: 0) {
            VStack(spacing: 0) {
                headerButton
                if isExpanded {
                    Divider()
                    fullContent
                        .padding(18)
                }
            }
        }
        .task(id: report.id) {
            await viewModel.load(report: report, modelContext: modelContext)
        }
        .onChange(of: refreshToken) {
            Task {
                await viewModel.load(report: report, modelContext: modelContext, forceRefresh: true)
            }
        }
    }

    // MARK: - Header

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.cleanAmber, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Permit history")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                    if !isExpanded {
                        smallSummaryText
                    }
                }

                Spacer(minLength: 0)

                if viewModel.isLoading && !isExpanded {
                    ProgressView().scaleEffect(0.75)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel3)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .padding(18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var smallSummaryText: some View {
        if viewModel.isLoading {
            Text("Loading…")
                .font(.system(size: 13))
                .foregroundStyle(Color.cleanLabel3)
        } else if let analytics = viewModel.result?.analytics {
            Text("\(analytics.permitCount) permits · Major reno: \(analytics.majorRenovationDetected ? "Yes" : "No")")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.cleanSky)
        } else {
            Text("No permit records")
                .font(.system(size: 13))
                .foregroundStyle(Color.cleanLabel3)
        }
    }

    // MARK: - Full content

    @ViewBuilder
    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Official permit records since 2000")
                .font(.caption)
                .foregroundStyle(Color.cleanLabel3)

            if viewModel.isLoading && viewModel.result == nil {
                PermitHistorySkeletonView()
            } else if let result = viewModel.result {
                Text(result.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.cleanLabel)

                PermitCategoryBadges(categories: result.categories)
                PermitAnalyticsView(analytics: result.analytics)
                PermitTimelineView(groups: result.groupedByYear)

                Text("Permit records indicate officially permitted work only. Absence of permits does not mean no renovations were completed.")
                    .font(.caption)
                    .foregroundStyle(Color.cleanLabel3)

                Text(result.attribution)
                    .font(.caption2)
                    .foregroundStyle(Color.cleanLabel3.opacity(0.72))
            } else {
                EmptyCardState(message: "Permit history is unavailable for this address.")
            }
        }
    }
}

private struct PermitCategoryBadges: View {
    let categories: [PropertyPermitCategory]

    var body: some View {
        if categories.isEmpty {
            EmptyView()
        } else {
            FlowLayout(spacing: 8) {
                ForEach(categories) { category in
                    Label(category.rawValue, systemImage: category.symbol)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .foregroundStyle(.white)
                        .background(Color.cleanAmber.opacity(0.78), in: Capsule())
                }
            }
        }
    }
}

struct PermitAnalyticsView: View {
    let analytics: PermitHistoryAnalytics

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(label: "Permits found", value: "\(analytics.permitCount)")
            StatTile(label: "First year", value: analytics.firstPermitYear.map(String.init) ?? "-")
            StatTile(label: "Most recent", value: analytics.mostRecentPermitYear.map(String.init) ?? "-")
            StatTile(label: "Major renovation", value: analytics.majorRenovationDetected ? "Yes" : "No")
            StatTile(label: "Electrical", value: analytics.electricalPermitDetected ? "Yes" : "No")
            StatTile(label: "Plumbing", value: analytics.plumbingPermitDetected ? "Yes" : "No")
            if analytics.homeownerFiledDetected {
                StatTile(label: "Homeowner-filed", value: "\(analytics.homeownerFiledCount)")
            }
        }
    }
}

struct PermitTimelineView: View {
    let groups: [(year: Int, permits: [PropertyPermitRecord])]

    var body: some View {
        if groups.isEmpty {
            EmptyCardState(message: "No permits were found for this property.")
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groups, id: \.year) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(group.year))
                            .font(.headline)
                            .foregroundStyle(Color.cleanAmber)
                        ForEach(group.permits) { permit in
                            PermitTimelineRow(permit: permit)
                        }
                    }
                }
            }
        }
    }
}

private struct PermitTimelineRow: View {
    let permit: PropertyPermitRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(permit.workDone ?? permit.description ?? "\(permit.category.rawValue) permit issued")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cleanLabel)
            if permit.isHomeownerFiled {
                Label("Filed by homeowner", systemImage: "person.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cleanLabel2)
            }
            VStack(alignment: .leading, spacing: 3) {
                KeyValueRow(key: "Permit Type", value: permit.permitType)
                KeyValueRow(key: "Permit Category", value: permit.category.rawValue)
                if let workDone = permit.workDone {
                    KeyValueRow(key: "Work Done", value: workDone)
                }
                if let performedBy = permit.performedBy {
                    KeyValueRow(key: "Performed By", value: performedBy)
                }
                if let contractor = permit.contractor {
                    KeyValueRow(key: "Contractor", value: contractor)
                }
                if let delta = permit.dwellingUnitsDelta {
                    KeyValueRow(key: "Dwelling Units", value: delta > 0 ? "+\(delta)" : "\(delta)")
                }
                KeyValueRow(key: "Issue Date", value: permit.issueDate?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                if let completed = permit.completedDate {
                    KeyValueRow(key: "Completed", value: completed.formatted(date: .abbreviated, time: .omitted))
                }
                KeyValueRow(key: "Status", value: permit.status ?? "-")
                KeyValueRow(key: "Permit Number", value: permit.permitNumber ?? "-")
                if let parent = permit.parentPermitNumber {
                    KeyValueRow(key: "Part Of", value: parent)
                }
            }
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.cleanSep)
                .frame(width: 2)
        }
    }
}

private struct PermitHistorySkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6).fill(Color.cleanLabel3.opacity(0.18)).frame(height: 16)
            RoundedRectangle(cornerRadius: 6).fill(Color.cleanLabel3.opacity(0.14)).frame(height: 16).padding(.trailing, 70)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12).fill(Color.cleanLabel3.opacity(0.12)).frame(height: 64)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for item in arrange(proposal: proposal, subviews: subviews).items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(item.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (items: [(index: Int, origin: CGPoint, size: CGSize)], size: CGSize) {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var items: [(Int, CGPoint, CGSize)] = []

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            items.append((index, CGPoint(x: x, y: y), size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (items, CGSize(width: width, height: y + rowHeight))
    }
}
