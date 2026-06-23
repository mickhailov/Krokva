import Foundation
import SwiftData

/// Caches fully-assembled `AddressReport`s so re-opening a recently viewed address is
/// instant instead of re-running the ~50-module network fan-out against a slow mirror.
/// Reuses the shared `CachedDataset` table (same pattern as `WinnipegPermitHistoryService`).
///
/// The encode/decode strategy is the plain default — it must match `SavedReport`, which
/// already round-trips `AddressReport` through `JSONEncoder()/JSONDecoder()`.
@MainActor
enum ReportCacheStore {
    /// Reports are civic snapshots that change slowly, so a day keeps them fresh enough while
    /// killing repeat fan-outs within a browsing session. Pull-to-refresh forces a re-fetch.
    static let ttl: TimeInterval = 60 * 60 * 24

    /// Bump when `AddressReport`'s coding shape changes so stale payloads are ignored.
    private static let schemaVersion = "v1"

    private static func cacheKey(providerID: String, address: NormalizedAddress) -> String {
        "report:\(schemaVersion):\(providerID):\(address.displayAddress.lowercased())"
    }

    static func read(providerID: String, address: NormalizedAddress, modelContext: ModelContext) -> AddressReport? {
        let key = cacheKey(providerID: providerID, address: address)
        let descriptor = FetchDescriptor<CachedDataset>(predicate: #Predicate { $0.key == key })
        guard let cached = try? modelContext.fetch(descriptor).first,
              cached.expiresAt > .now,
              let report = try? JSONDecoder().decode(AddressReport.self, from: cached.payload) else {
            return nil
        }
        return report
    }

    static func write(_ report: AddressReport, providerID: String, address: NormalizedAddress, modelContext: ModelContext) {
        // Never cache a failed build — it would pin a database-error state for a full day.
        guard !report.dataSourceUnavailable else { return }
        guard let payload = try? JSONEncoder().encode(report) else { return }
        let key = cacheKey(providerID: providerID, address: address)
        let descriptor = FetchDescriptor<CachedDataset>(predicate: #Predicate { $0.key == key })
        if let cached = try? modelContext.fetch(descriptor).first {
            cached.payload = payload
            cached.expiresAt = Date(timeIntervalSinceNow: ttl)
            cached.updatedAt = .now
        } else {
            modelContext.insert(CachedDataset(key: key, payload: payload, expiresAt: Date(timeIntervalSinceNow: ttl)))
        }
    }
}
