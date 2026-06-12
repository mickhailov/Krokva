import Foundation

/// One entry per report module fanned out by a `CityDataProvider`. Used to attribute a
/// network/HTTP failure to the specific module whose task was running when it threw, so a
/// card can tell "the source loaded but had nothing for this address" (empty) apart from
/// "the source failed to load" (database error). See `feedback-empty-vs-error-states`.
enum ReportModule: String, Codable, CaseIterable, Sendable {
    case property
    case infrastructure
    case permits
    case vacantOrders
    case neighbourhoodValues
    case comparables
    case permitActivity
    case parks
    case transit
    case bylaw
    case development
    case river
    case library
    case serviceRequests
    case planning
    case streetAccess
    case emergency
    case publicHealth
    case policeCrime
    case civicContext
    case shortTermRentals
    case recreation
    case schools
    case waste
    case demographics
    case localGovernment
    case localBusiness
    case aquatics
    case traffic
    case neighbourhoodRisk
    case waterQuality
    case capitalWorks
    case facilityClosures
}

/// Task-local marker for the module currently being fetched. Set around each `async let`
/// in a provider's fan-out so the deep, shared networking layer can record which module a
/// thrown request belonged to without every fetch function having to thread it through.
enum ReportModuleContext {
    @TaskLocal static var current: ReportModule?
}

/// Collects the set of modules that hit a transport/HTTP error during a single report
/// build. Empty (HTTP 200 with no rows) is *not* recorded — that is genuine "no data".
actor DataSourceHealth {
    private var failed: Set<ReportModule> = []

    /// Records a failure for the module bound to the current task, if any.
    func recordCurrentModuleFailure() {
        guard let module = ReportModuleContext.current else { return }
        failed.insert(module)
    }

    /// Snapshot of the modules that failed, for stamping onto the assembled report.
    func snapshot() -> Set<ReportModule> { failed }

    /// Clears state at the start of a fresh report build (providers are reused).
    func reset() { failed.removeAll() }
}
