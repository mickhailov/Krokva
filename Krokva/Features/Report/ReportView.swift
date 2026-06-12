import Charts
import MapKit
import SwiftData
import SwiftUI

struct ReportView: View {
    @State private var currentReport: AddressReport
    @State private var permitHistoryRefreshToken = UUID()
    @State private var isRetrying = false
    @State private var showSaveSheet = false
    @Environment(\.modelContext) private var modelContext
    @Query private var savedReports: [SavedReport]

    init(report: AddressReport) {
        _currentReport = State(initialValue: report)
    }

    private var report: AddressReport { currentReport }

    // Rendering the full card stack for an address the city has no data on produces an
    // empty, misleading report, so we show a dedicated "no data" screen instead. The
    // detection lives on the model (`AddressReport.addressNotFound`).
    private var addressNotFound: Bool { report.addressNotFound }

    private func retryReport() async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        let refreshed = await ReportService().report(for: currentReport.address.raw)
        currentReport = refreshed
        permitHistoryRefreshToken = UUID()
    }

    var body: some View {
        ZStack {
            Color.cleanBg.ignoresSafeArea()

            if report.dataSourceUnavailable {
                DatabaseErrorReportView(report: report, onRetry: retryReport)
            } else if addressNotFound {
                NoDataReportView(report: report)
            } else {
                reportScroll
            }
        }
        .environment(\.reportRetryAction, retryReport)
        .refreshable { await retryReport() }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cleanBg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Address report")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.cleanLabel)
            }
            if !addressNotFound {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: toggleSaved) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(isSaved ? Color.cleanSky : Color.cleanLabel2)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveReportSheet(
                defaultName: reportAddress,
                savedCount: savedReports.count,
                onSave: { name in
                    modelContext.insert(SavedReport(from: report, name: name))
                }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
    }

    private var reportScroll: some View {
        VStack(spacing: 0) {
            stickyAddressBar
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color.cleanBg.opacity(0.92))

            ScrollView {
                LazyVStack(spacing: 14) {
                    if report.providerState == .comingSoon {
                        ComingSoonReportCard(report: report)
                    }

                    // 1. Address + House Score
                    HeroPropertyCard(report: report)

                    // 2. Ownership cost
                    PropertyFinancialCard(property: report.property)

                    // 3. Property facts
                    PropertyFactsCard(property: report.property, sourceFailed: report.moduleFailed(.property))
                    CivicContextCard(summary: report.civicContext, sourceFailed: report.moduleFailed(.civicContext))
                    WasteCollectionCard(summary: report.waste, sourceFailed: report.moduleFailed(.waste))
                    LocalGovernmentCard(summary: report.localGovernment, sourceFailed: report.moduleFailed(.localGovernment))
                    NearbySchoolsCard(
                        schools: report.nearbySchools,
                        property: report.property,
                        schoolZone: report.streetAccess?.schoolSpeedLimit,
                        civicContext: report.civicContext,
                        sourceFailed: report.moduleFailed(.schools)
                    )

                    // 4. Permit history
                    PropertyPermitHistoryCard(report: report, refreshToken: permitHistoryRefreshToken)

                    // 4b. Neighbourhood demographics
                    DemographicsCard(
                        summary: report.demographics,
                        sourceFailed: report.moduleFailed(.demographics)
                    )

                    // 5. Public health
                    if let health = report.publicHealth {
                        PublicHealthCard(
                            summary: health,
                            neighbourhood: report.property?.neighbourhood ?? report.cityName
                        )
                    } else if report.moduleFailed(.publicHealth) {
                        ModuleErrorCard(title: "Public Health", systemImage: "heart.text.square", iconColor: .cleanSky,
                                        message: "Database error loading public health data.")
                    }

                    // 6. 311 activity
                    if let sr = report.serviceRequests {
                        Service311Card(summary: sr)
                    } else if report.moduleFailed(.serviceRequests) {
                        ModuleErrorCard(title: "311 Activity", systemImage: "phone.badge.waveform", iconColor: .cleanIndigo,
                                        message: "Database error loading 311 activity.")
                    }

                    // 7. Emergency response
                    EmergencyActivityCard(
                        summary: report.emergency,
                        substances: report.publicHealth?.substances ?? [],
                        sourceFailed: report.moduleFailed(.emergency)
                    )

                    // 8. Police crime context
                    PoliceCrimeCard(summary: report.policeCrime, sourceFailed: report.moduleFailed(.policeCrime))

                    // 10. Street access + Infrastructure
                    StreetAccessCard(street: report.streetAccess, infrastructure: report.infrastructure,
                                     sourceFailed: report.moduleFailed(.streetAccess) || report.moduleFailed(.infrastructure))
                    TrafficCard(summary: report.traffic, risk: report.neighbourhoodRisk,
                                sourceFailed: report.moduleFailed(.traffic) || report.moduleFailed(.neighbourhoodRisk))
                    NeighbourhoodRiskCard(summary: report.neighbourhoodRisk, sourceFailed: report.moduleFailed(.neighbourhoodRisk))
                    WaterQualityCard(summary: report.waterQuality, sourceFailed: report.moduleFailed(.waterQuality))
                    CapitalWorksCard(summary: report.capitalWorks, sourceFailed: report.moduleFailed(.capitalWorks))

                    // 11. Civic amenities (parks, library, river, pools)
                    CivicAmenitiesCard(parks: report.parks, river: report.river, library: report.library, aquatics: report.aquatics,
                                       sourceFailed: report.moduleFailed(.parks) || report.moduleFailed(.river) || report.moduleFailed(.library) || report.moduleFailed(.aquatics))
                    LocalBusinessCard(summary: report.localBusiness, sourceFailed: report.moduleFailed(.localBusiness))
                    FacilityClosuresCard(summary: report.facilityClosures, sourceFailed: report.moduleFailed(.facilityClosures))
                    RecreationCard(summary: report.recreation, sourceFailed: report.moduleFailed(.recreation))

                    // 12. Transit access
                    TransitAccessCard(summary: report.transit, sourceFailed: report.moduleFailed(.transit))

                    // 13. Vacant build orders
                    VacantOrdersCard(orders: report.vacantOrders, sourceFailed: report.moduleFailed(.vacantOrders))

                    // 14. Building permits
                    PermitsCard(permits: report.permits, sourceFailed: report.moduleFailed(.permits))
                    PermitActivityCard(activity: report.permitActivity, sourceFailed: report.moduleFailed(.permitActivity))

                    // 15. Development context
                    DevelopmentContextCard(summary: report.development, sourceFailed: report.moduleFailed(.development))
                    BylawInvestigationsCard(summary: report.bylaw, sourceFailed: report.moduleFailed(.bylaw))
                    PlanningContextCard(summary: report.planning, sourceFailed: report.moduleFailed(.planning))
                    ShortTermRentalsCard(summary: report.shortTermRentals, sourceFailed: report.moduleFailed(.shortTermRentals))

                    // 16. Map
                    ReportMapCard(report: report)

                    SourcesCard(report: report)
                }
                .padding(20)
            }
        }
    }

    private var stickyAddressBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.cleanSky)
            VStack(alignment: .leading, spacing: 1) {
                Text(reportAddress)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                    .lineLimit(1)
                Text(report.cityName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cleanLabel3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cleanCard.opacity(0.94), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.65), lineWidth: 1))
        .shadow(color: Color.cleanLabel.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    private var reportAddress: String {
        report.property?.fullAddress ?? report.address.displayAddress
    }

    private var isSaved: Bool {
        savedReports.contains { $0.address == reportAddress && $0.cityID == report.providerID }
    }

    private func toggleSaved() {
        if let existing = savedReports.first(where: { $0.address == reportAddress && $0.cityID == report.providerID }) {
            modelContext.delete(existing)
        } else {
            showSaveSheet = true
        }
    }
}

// Lets the user name a report before pinning it for fast access, and surfaces the
// 5-report limit. The bookmark toolbar button opens this for unsaved reports.
private struct SaveReportSheet: View {
    let defaultName: String
    let savedCount: Int
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    private var isFull: Bool { savedCount >= SavedReport.maxSaved }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Report name").eyebrow(color: .cleanLabel3)
                    TextField(defaultName, text: $name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.cleanAmber.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.5), lineWidth: 1))
                        .disabled(isFull)
                }

                HStack(spacing: 8) {
                    Image(systemName: isFull ? "exclamationmark.triangle.fill" : "bookmark.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isFull ? Color.cleanAmber : Color.cleanSky)
                    Text(isFull
                         ? "You’ve saved the maximum of \(SavedReport.maxSaved) reports. Remove one to pin this address."
                         : "You can save up to \(SavedReport.maxSaved) reports here for fast access. \(savedCount)/\(SavedReport.maxSaved) used.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: save) {
                    Text("Save report")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isFull ? Color.cleanLabel3 : Color.cleanSky, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isFull)
            }
            .padding(22)
            .background(Color.cleanBg.ignoresSafeArea())
            .navigationTitle("Save report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.cleanLabel2)
                }
            }
            .onAppear { if !isFull { nameFocused = true } }
        }
    }

    private func save() {
        guard !isFull else { return }
        onSave(name)
        dismiss()
    }
}

struct NoDataReportView: View {
    let report: AddressReport
    @Environment(\.dismiss) private var dismiss

    private var typedAddress: String {
        let display = report.address.displayAddress
        return display.isEmpty ? report.address.raw : display
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.cleanAmber.opacity(0.12))
                        .frame(width: 92, height: 92)
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Color.cleanAmber)
                }
                .padding(.top, 48)

                VStack(spacing: 10) {
                    Text("No data for this address")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.cleanLabel)
                        .multilineTextAlignment(.center)

                    Text("We couldn't find \u{201C}\(typedAddress)\u{201D} in \(report.cityName) open data. Check the spelling, or try a nearby civic number — coverage is limited to addresses on file with the city.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Try another address")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(Color.cleanSky, in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Shown in place of the full report when the city's open-data backend errored on the
/// foundational lookups, so the user sees a recoverable "database error" rather than a
/// misleading "address not found".
struct DatabaseErrorReportView: View {
    let report: AddressReport
    var onRetry: (() async -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isRetrying = false

    private var typedAddress: String {
        let display = report.address.displayAddress
        return display.isEmpty ? report.address.raw : display
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.cleanRed.opacity(0.12))
                        .frame(width: 92, height: 92)
                    if isRetrying {
                        ProgressView()
                            .scaleEffect(1.4)
                    } else {
                        Image(systemName: "exclamationmark.icloud")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color.cleanRed)
                    }
                }
                .padding(.top, 48)

                VStack(spacing: 10) {
                    Text(isRetrying ? "Retrying…" : "Database error")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.cleanLabel)
                        .multilineTextAlignment(.center)

                    Text("We couldn't reach \(report.cityName) open data to build a report for \u{201C}\(typedAddress)\u{201D}. This is usually temporary — check your connection and try again.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let retry = onRetry {
                    Button {
                        guard !isRetrying else { return }
                        isRetrying = true
                        Task {
                            await retry()
                            isRetrying = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Retry")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(isRetrying ? Color.cleanLabel3 : Color.cleanSky, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isRetrying)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Go back")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel2)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ComingSoonReportCard: View {
    let report: AddressReport

    var body: some View {
        ReportCard(title: "Coming soon", systemImage: "hourglass") {
            Text("We do not have live data for \(report.cityName) yet. Vote for this city in Settings to prioritize coverage.")
                .foregroundStyle(Color.cleanLabel2)
        }
    }
}

struct SavedReportsView: View {
    @Query(sort: \SavedReport.savedAt, order: .reverse) private var savedReports: [SavedReport]
    @Query(sort: \RecentSearch.createdAt, order: .reverse) private var recentSearches: [RecentSearch]
    @Environment(\.modelContext) private var modelContext
    @Environment(ReportRouter.self) private var router
    @State private var selectedReport: AddressReport?
    @State private var isShowingReport = false
    @State private var loadingAddress: String?
    @State private var loadingStage: ReportLoadingStage = .normalizing
    @State private var refreshingAddress: String?

    var body: some View {
        ZStack {
            Color.cleanBg.ignoresSafeArea()

            if savedReports.isEmpty && recentSearches.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        reportsHeader

                        if !savedReports.isEmpty {
                            reportsSection(
                                title: "Saved",
                                count: min(savedReports.count, SavedReport.maxSaved),
                                countLabel: "saved",
                                description: "Saved reports are pinned snapshots you bookmarked for fast access, comparison, and refreshes."
                            ) {
                                ForEach(Array(savedReports.prefix(SavedReport.maxSaved))) { saved in
                                    savedReportRow(saved)
                                }
                            }
                        }

                        if !recentSearches.isEmpty {
                            reportsSection(
                                title: "Recent",
                                count: min(recentSearches.count, 5),
                                countLabel: "recent",
                                description: "Recent reports are the last addresses you opened from search. They are history, not pinned saves."
                            ) {
                                ForEach(Array(recentSearches.prefix(5))) { recent in
                                    recentReportRow(recent)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingReport) {
            if let selectedReport {
                ReportView(report: selectedReport)
                    .onAppear {
                        if router.pendingReport?.id == selectedReport.id {
                            router.pendingReport = nil
                        }
                    }
            }
        }
        .onAppear {
            presentPendingReport()
        }
        .onChange(of: router.pendingReport?.id) { _, newValue in
            guard newValue != nil else { return }
            presentPendingReport()
        }
        .overlay {
            if let loadingAddress {
                LoadingScreenAnimation(
                    addressText: loadingAddress,
                    cityName: "Winnipeg, MB",
                    stage: loadingStage
                )
                .ignoresSafeArea()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private var reportsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reports")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.cleanLabel)
            Text("Saved reports stay pinned. Recent reports are your latest lookups.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.cleanLabel2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private func reportsSection<Content: View>(
        title: String,
        count: Int,
        countLabel: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).eyebrow(color: .cleanLabel3)
                Spacer()
                Text("\(count) \(countLabel)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel.opacity(0.45))
            }

            Text(description)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.cleanLabel2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                content()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.cleanLabel3)
            Text("No reports yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.cleanLabel2)
            Text("Saved reports will appear here after you bookmark them. Recent reports will appear after you search an address.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cleanLabel3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func presentPendingReport() {
        guard let report = router.pendingReport else { return }
        selectedReport = report

        Task { @MainActor in
            await Task.yield()
            guard selectedReport?.id == report.id else { return }
            isShowingReport = true
        }
    }

    private func recentReportRow(_ recent: RecentSearch) -> some View {
        Button {
            Task { await fetchRecentAndOpen(recent) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cleanAmber.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.cleanAmber)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(recent.address)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cleanLabel)
                        .lineLimit(1)
                    Text(CityRegistry.shared.provider(for: recent.cityID)?.displayName ?? recent.cityID)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.cleanLabel3)
                        Text("Opened \(recent.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.cleanLabel3)
                    }
                }

                Spacer(minLength: 4)

                if loadingAddress == recent.address {
                    ProgressView()
                        .frame(width: 34, height: 34)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.cleanLabel)
                            .frame(width: 34, height: 34)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 10)
            .background(Color.cleanAmber.opacity(0.07))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.4), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func savedReportRow(_ saved: SavedReport) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.cleanSky.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.cleanSky)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(saved.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                    .lineLimit(1)
                if saved.displayName != saved.address {
                    Text(saved.address)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                        .lineLimit(1)
                } else if !saved.neighbourhood.isEmpty {
                    Text("\(saved.neighbourhood) · \(saved.cityName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cleanLabel2)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.cleanLabel3)
                    Text("Updated \(saved.savedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.cleanLabel3)
                }
            }

            Spacer(minLength: 4)

            Button {
                Task { await refresh(saved) }
            } label: {
                if refreshingAddress == saved.address {
                    ProgressView()
                        .frame(width: 34, height: 34)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.cleanTrack)
                            .frame(width: 34, height: 34)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.cleanLabel2)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                remove(saved)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.cleanAmber.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.cleanAmber)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(Color.cleanSky.opacity(0.07))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.4), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            open(saved)
        }
    }

    private func fetchRecentAndOpen(_ recent: RecentSearch) async {
        guard loadingAddress == nil else { return }
        loadingStage = .normalizing
        loadingAddress = recent.address
        defer { loadingAddress = nil }
        let report = await ReportService().report(for: recent.address) { stage in
            await MainActor.run { loadingStage = stage }
        }
        selectedReport = report
        isShowingReport = true
    }

    private func open(_ saved: SavedReport) {
        if let report = saved.decodedReport(), !shouldRefetch(report) {
            selectedReport = report
            isShowingReport = true
        } else {
            Task { await fetchAndOpen(saved) }
        }
    }

    private func fetchAndOpen(_ saved: SavedReport) async {
        guard loadingAddress == nil else { return }
        loadingStage = .normalizing
        loadingAddress = saved.address
        defer { loadingAddress = nil }
        let report = await ReportService().report(for: saved.address) { stage in
            await MainActor.run { loadingStage = stage }
        }
        saved.update(from: report)
        try? modelContext.save()
        selectedReport = report
        isShowingReport = true
    }

    private func remove(_ saved: SavedReport) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            modelContext.delete(saved)
        }
    }

    private func refresh(_ saved: SavedReport) async {
        guard refreshingAddress == nil else { return }
        refreshingAddress = saved.address
        defer { refreshingAddress = nil }
        let report = await ReportService().report(for: saved.address)
        saved.update(from: report)
        try? modelContext.save()
    }

    private func shouldRefetch(_ report: AddressReport) -> Bool {
        report.providerID == "winnipeg" && report.serviceRequests == nil
    }
}
