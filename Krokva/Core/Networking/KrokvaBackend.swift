import Foundation

/// Single source of truth for the Winnipeg live-report backend.
///
/// The live report is assembled from a self-hosted Socrata-compatible mirror. Keeping the
/// host and scheme here — instead of buried in `WinnipegProvider.init` — means relocating the
/// mirror, or (importantly) putting it behind a TLS domain, is a one-line change. The value
/// can also be overridden per build via the `KrokvaBackendHost` / `KrokvaBackendScheme`
/// Info.plist keys without touching source, which is handy for staging vs production.
///
/// SECURITY NOTE: the default host is a raw IP served over plain HTTP, which is the reason
/// `NSAllowsArbitraryLoads` is currently enabled in project.yml. Replacing this with an
/// `https://` domain is the prerequisite for turning App Transport Security back on (scoped
/// to this single host). `isSecure` reflects whether the current endpoint is encrypted.
enum KrokvaBackend {
    static let defaultHost = "3.99.123.190:8889"
    static let defaultScheme = "http"

    static var host: String { infoValue("KrokvaBackendHost") ?? defaultHost }
    static var scheme: String { infoValue("KrokvaBackendScheme") ?? defaultScheme }

    /// True when traffic to the backend is encrypted. Surfaced for diagnostics/Settings.
    static var isSecure: Bool { scheme.lowercased() == "https" }

    private static func infoValue(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
