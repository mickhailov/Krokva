import Foundation
import SwiftData

@Model
final class RecentSearch {
    var address: String
    var cityID: String
    var createdAt: Date

    init(address: String, cityID: String, createdAt: Date = .now) {
        self.address = address
        self.cityID = cityID
        self.createdAt = createdAt
    }
}

@Model
final class CityVote {
    var cityID: String
    var count: Int

    init(cityID: String, count: Int = 0) {
        self.cityID = cityID
        self.count = count
    }
}

@Model
final class CachedDataset {
    var key: String
    var payload: Data
    var expiresAt: Date
    var updatedAt: Date

    init(key: String, payload: Data, expiresAt: Date, updatedAt: Date = .now) {
        self.key = key
        self.payload = payload
        self.expiresAt = expiresAt
        self.updatedAt = updatedAt
    }
}

@Model
final class SavedAddress {
    var address: String
    var cityID: String
    var savedAt: Date

    init(address: String, cityID: String, savedAt: Date = .now) {
        self.address = address
        self.cityID = cityID
        self.savedAt = savedAt
    }
}

// Snapshot of key report fields for side-by-side comparison.
@Model
final class SavedReport {
    // User-given label for fast access (defaults to the address).
    var name: String = ""
    var address: String
    var cityID: String
    var cityName: String
    var neighbourhood: String
    var savedAt: Date

    // The one address the user treats as home / their current place. Relocation
    // comparisons and the report hint measure candidates against it. At most one
    // saved report has this set (enforced by `setCurrent(_:in:)`). Defaulted so
    // reports saved before this field decode via lightweight migration.
    var isCurrentAddress: Bool = false

    // Up to this many reports can be pinned for fast access.
    static let maxSaved = 5

    /// Marks `target` as the current/home address and clears the flag on every
    /// other saved report, keeping the "exactly one current" invariant.
    static func setCurrent(_ target: SavedReport, in all: [SavedReport]) {
        for report in all { report.isCurrentAddress = (report === target) }
    }

    // Assessment snapshot
    var assessedValue: Double?
    var propertyTax: Double?
    var propertyTaxIsEstimated: Bool
    var livingArea: Double?
    var landArea: Double?
    var yearBuilt: Int?
    var houseStyle: String?
    var storeys: String?
    var basement: String?
    var garage: String?
    var airConditioning: String?
    var fireplace: String?
    var swimmingPool: String?
    var zoning: String?

    // Activity counts
    var permitCount: Int
    var vacantOrderCount: Int
    var serviceRequestTotal: Int?
    var crimeLastYear: Int?
    var parkCount: Int?
    var transitOnTimePct: Double?

    // Full encoded report — loaded instantly without re-fetching
    var reportData: Data?

    init(from report: AddressReport, name: String? = nil) {
        let resolvedAddress = report.property?.fullAddress ?? report.address.displayAddress
        address = resolvedAddress
        self.name = (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? resolvedAddress
        cityID = report.providerID
        cityName = report.cityName
        neighbourhood = report.property?.neighbourhood ?? ""
        savedAt = .now
        assessedValue = report.property?.totalAssessedValue
        propertyTax = report.property?.propertyTax
        propertyTaxIsEstimated = report.property?.propertyTaxIsEstimated ?? false
        livingArea = report.property?.livingArea
        landArea = report.property?.landArea
        yearBuilt = report.property?.yearBuilt
        houseStyle = report.property?.houseStyle
        storeys = report.property?.storeys
        basement = report.property?.basement
        garage = report.property?.garage
        airConditioning = report.property?.airConditioning
        fireplace = report.property?.fireplace
        swimmingPool = report.property?.swimmingPool
        zoning = report.property?.zoning
        permitCount = report.permits.count
        vacantOrderCount = report.vacantOrders.count
        serviceRequestTotal = report.serviceRequests?.totalLastYear
        crimeLastYear = report.policeCrime?.yearlyCounts.last?.neighbourhood
        parkCount = report.parks?.nearbyParks.count
        transitOnTimePct = report.transit?.onTimePercentage
        reportData = try? JSONEncoder().encode(report)
    }

    // Falls back to the address for rows saved before names existed.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? address : trimmed
    }

    func decodedReport() -> AddressReport? {
        guard let data = reportData else { return nil }
        return try? JSONDecoder().decode(AddressReport.self, from: data)
    }

    func update(from report: AddressReport) {
        savedAt = .now
        neighbourhood = report.property?.neighbourhood ?? neighbourhood
        assessedValue = report.property?.totalAssessedValue
        propertyTax = report.property?.propertyTax
        propertyTaxIsEstimated = report.property?.propertyTaxIsEstimated ?? false
        livingArea = report.property?.livingArea
        landArea = report.property?.landArea
        yearBuilt = report.property?.yearBuilt
        houseStyle = report.property?.houseStyle
        storeys = report.property?.storeys
        basement = report.property?.basement
        garage = report.property?.garage
        airConditioning = report.property?.airConditioning
        fireplace = report.property?.fireplace
        swimmingPool = report.property?.swimmingPool
        zoning = report.property?.zoning
        permitCount = report.permits.count
        vacantOrderCount = report.vacantOrders.count
        serviceRequestTotal = report.serviceRequests?.totalLastYear
        crimeLastYear = report.policeCrime?.yearlyCounts.last?.neighbourhood
        parkCount = report.parks?.nearbyParks.count
        transitOnTimePct = report.transit?.onTimePercentage
        reportData = try? JSONEncoder().encode(report)
    }
}
