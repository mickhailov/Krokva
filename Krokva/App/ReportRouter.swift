import Observation

/// Shared routing state so a report fetched from the Home tab is presented on the
/// Report tab. Setting `pendingReport` causes `RootTabView` to switch to the Report
/// tab, where `SavedReportsView` pushes the report onto its navigation stack.
@Observable
final class ReportRouter {
    var pendingReport: AddressReport?
}
