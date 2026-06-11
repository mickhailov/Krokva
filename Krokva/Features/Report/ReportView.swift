import Charts
import MapKit
import SwiftData
import SwiftUI

struct ReportView: View {
    let report: AddressReport
    @State private var permitHistoryRefreshToken = UUID()
    @Environment(\.modelContext) private var modelContext
    @Query private var savedReports: [SavedReport]

    // An address that resolves no assessment (and no civic match) means the city's
    // open data has nothing for it — typically a typo or an address outside coverage.
    // Rendering the full card stack here produces an empty, misleading report, so we
    // show a dedicated "no data" screen instead.
    private var addressNotFound: Bool {
        report.providerState == .live && report.property == nil && report.civicContext == nil
    }

    var body: some View {
        ZStack {
            Color.cleanBg.ignoresSafeArea()

            if addressNotFound {
                NoDataReportView(report: report)
            } else {
                reportScroll
            }
        }
        .refreshable { permitHistoryRefreshToken = UUID() }
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
    }

    private var reportScroll: some View {
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
                    PropertyFactsCard(property: report.property)
                    CivicContextCard(summary: report.civicContext)
                    SchoolDivisionsCard(
                        context: report.civicContext,
                        schools: report.nearbySchools,
                        schoolZone: report.streetAccess?.schoolSpeedLimit
                    )

                    // 4. Permit history
                    PropertyPermitHistoryCard(report: report, refreshToken: permitHistoryRefreshToken)

                    // 5. Public health
                    if let health = report.publicHealth {
                        PublicHealthCard(
                            summary: health,
                            neighbourhood: report.property?.neighbourhood ?? report.cityName
                        )
                    }

                    // 6. 311 activity
                    if let sr = report.serviceRequests {
                        Service311Card(summary: sr)
                    }

                    // 7. Emergency response
                    EmergencyActivityCard(summary: report.emergency, substances: report.publicHealth?.substances ?? [])

                    // 8. Police crime context
                    PoliceCrimeCard(summary: report.policeCrime)

                    // 10. Street access + Infrastructure
                    StreetAccessCard(street: report.streetAccess, infrastructure: report.infrastructure)

                    // 11. Civic amenities
                    CivicAmenitiesCard(parks: report.parks, river: report.river, library: report.library)
                    NearbySchoolsCard(
                        schools: report.nearbySchools,
                        property: report.property,
                        schoolZone: report.streetAccess?.schoolSpeedLimit,
                        civicContext: report.civicContext
                    )
                    RecreationCard(summary: report.recreation)

                    // 12. Transit access
                    TransitAccessCard(summary: report.transit)

                    // 13. Vacant build orders
                    VacantOrdersCard(orders: report.vacantOrders)

                    // 14. Building permits
                    PermitsCard(permits: report.permits)
                    PermitActivityCard(activity: report.permitActivity)

                    // 15. Development context
                    DevelopmentContextCard(summary: report.development)
                    BylawInvestigationsCard(summary: report.bylaw)
                    PlanningContextCard(summary: report.planning)
                    ShortTermRentalsCard(summary: report.shortTermRentals)

                    // 16. Map
                    ReportMapCard(report: report)

                    SourcesCard(report: report)
                }
                .padding(20)
            }
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
            modelContext.insert(SavedReport(from: report))
        }
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

                    Text("We couldn't find “\(typedAddress)” in \(report.cityName) open data. Check the spelling, or try a nearby civic number — coverage is limited to addresses on file with the city.")
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
    @Environment(\.modelContext) private var modelContext
    @Environment(ReportRouter.self) private var router
    @State private var selectedReport: AddressReport?
    @State private var isShowingReport = false
    @State private var loadingAddress: String?
    @State private var refreshingAddress: String?

    var body: some View {
        ZStack {
            Color.cleanBg.ignoresSafeArea()

            if savedReports.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(savedReports) { saved in
                            savedReportRow(saved)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingReport) {
            if let selectedReport {
                ReportView(report: selectedReport)
            }
        }
        .onChange(of: router.pendingReport?.id) { _, newValue in
            guard newValue != nil, let report = router.pendingReport else { return }
            selectedReport = report
            isShowingReport = true
            router.pendingReport = nil
        }
        .overlay {
            if let loadingAddress {
                LoadingScreenAnimation(
                    addressText: loadingAddress,
                    cityName: "Winnipeg, MB",
                    stage: .nearbyRecords
                )
                .ignoresSafeArea()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.cleanLabel3)
            Text("No saved reports")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.cleanLabel2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Text(saved.address)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cleanLabel)
                    .lineLimit(1)
                if !saved.neighbourhood.isEmpty {
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
        loadingAddress = saved.address
        defer { loadingAddress = nil }
        let report = await ReportService().report(for: saved.address)
        saved.update(from: report)
        try? modelContext.save()
        selectedReport = report
        isShowingReport = true
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
