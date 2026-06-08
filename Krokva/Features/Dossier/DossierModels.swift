import CoreLocation
import Foundation

struct AddressDossier: Identifiable {
    let id = UUID()
    var address: NormalizedAddress
    var providerID: String
    var cityName: String
    var providerState: ProviderImplementationState
    var property: PropertyAssessment?
    var neighbourhoodValues: [AssessmentValueBin] = []
    var comparables: [ComparableProperty] = []
    var permits: [BuildingPermit] = []
    var permitActivity: [YearCount] = []
    var vacantOrders: [VacantOrder] = []
    var infrastructure: InfrastructureSummary?
    var parks: ParksSummary?
    var transit: TransitAccessSummary?
    var bylaw: BylawInvestigationSummary?
    var development: DevelopmentContextSummary?
    var river: RiverGaugeSummary?
    var library: LibraryAmenity?
    var serviceRequests: ServiceRequestSummary?
    var planning: PlanningContextSummary?
    var streetAccess: StreetAccessSummary?
    var emergency: EmergencySummary?
    var publicHealth: PublicHealthSummary?
    var policeCrime: PoliceCrimeSummary?
    var sources: [DatasetSource] = []

    static func comingSoon(address: NormalizedAddress, provider: any CityDataProvider) -> AddressDossier {
        AddressDossier(address: address, providerID: provider.cityID, cityName: provider.displayName, providerState: .comingSoon, sources: [])
    }
}

struct PropertyAssessment {
    var fullAddress: String
    var neighbourhood: String
    var useCode: String?
    var totalAssessedValue: Double?
    var propertyTax: Double?
    var propertyTaxIsEstimated: Bool = false
    var livingArea: Double?
    var landArea: Double?
    var yearBuilt: Int?
    var rooms: String?
    var basement: String?
    var garage: String?
    var airConditioning: String?
    var fireplace: String?
    var swimmingPool: String?
    var zoning: String?
    var rollNumber: String?
    var houseStyle: String?
    var storeys: String?
    var coordinate: CLLocationCoordinate2D?
}

struct AssessmentValueBin: Identifiable {
    let id = UUID()
    var bucket: String
    var count: Int
    var midpoint: Double
}

struct ComparableProperty: Identifiable {
    let id = UUID()
    var address: String
    var value: Double
    var livingArea: Double
    var yearBuilt: Int?
}

struct BuildingPermit: Identifiable {
    let id = UUID()
    var issuedDate: Date?
    var type: String
    var subType: String?
    var workType: String?
    var address: String
    var status: String?
    var isAdjacentStructural: Bool
    var coordinate: CLLocationCoordinate2D?
}

struct YearCount: Identifiable {
    var id: Int { year }
    var year: Int
    var count: Int
}

struct VacantOrder: Identifiable {
    let id = UUID()
    var issuedDate: Date?
    var address: String
    var orderType: String
    var distanceDescription: String?
    var coordinate: CLLocationCoordinate2D?
}

struct InfrastructureSummary {
    var speedLimit: String?
    var potholes: Int
    var publicTrees: Int
    var taggedTrees: Int
}

struct ParksSummary {
    var nearestPark: ParkAmenity?
    var nearbyParks: [ParkAmenity] = []
    var neighbourhoodParkCount: Int
    var neighbourhoodHectares: Double?
}

struct ParkAmenity: Identifiable {
    var id: String { parkID }
    var parkID: String
    var name: String
    var distanceDescription: String
    var coordinate: CLLocationCoordinate2D?
    var playgrounds: Int
    var fields: Int
    var courts: Int
    var washrooms: Int
    var benches: Int
}

struct TransitAccessSummary {
    var nearestStop: TransitStop?
    var routes: [TransitRouteSummary]
    var averageDeviationSeconds: Double?
    var onTimePercentage: Double?
    var passUpsLastYear: Int
    var averageDailyBoardings: Double?
}

struct TransitStop: Identifiable {
    var id: String { stopNumber }
    var stopNumber: String
    var distanceDescription: String
}

struct TransitRouteSummary: Identifiable {
    var id: String { routeNumber }
    var routeNumber: String
    var routeName: String
}

struct BylawInvestigationSummary {
    var neighbourhood: String
    var yearly: [YearCount]
    var complaintTypes: [IncidentBreakdown]
}

struct DevelopmentContextSummary {
    var recentPermits: [DevelopmentPermit]
    var reviewProcessing: [PermitProcessingMetric]
    var intake: [PermitIntakeMetric]
}

struct DevelopmentPermit: Identifiable {
    let id = UUID()
    var issuedDate: Date?
    var permitNumber: String?
    var type: String
    var subType: String?
    var workType: String?
    var address: String
    var status: String?
    var coordinate: CLLocationCoordinate2D?
}

struct PermitProcessingMetric: Identifiable {
    let id = UUID()
    var description: String
    var month: Date?
    var averageBusinessDays: Double
    var serviceStandardDays: Double?
    var percentMetTarget: Double?
}

struct PermitIntakeMetric: Identifiable {
    let id = UUID()
    var description: String
    var month: Date?
    var approved: Int
    var notApproved: Int
}

struct RiverGaugeSummary {
    var riverName: String
    var location: String
    var distanceDescription: String
    var jamesFeet: Double?
    var geodeticFeet: Double?
    var geodeticMetric: Double?
    var readingDate: Date?
    var notes: String?
    var coordinate: CLLocationCoordinate2D?
}

struct LibraryAmenity: Identifiable {
    let id = UUID()
    var name: String
    var address: String
    var distanceDescription: String
    var wifi: Bool
    var accessibility: Bool
    var parkingLot: Bool
    var parkingStalls: Int?
    var roomRentals: Bool
    var notes: String?
    var coordinate: CLLocationCoordinate2D?
}

struct ServiceRequestSummary {
    var neighbourhood: String
    var totalLastYear: Int
    var openLastYear: Int
    var closedLastYear: Int
    var statusBreakdown: [IncidentBreakdown]
    var channelBreakdown: [IncidentBreakdown]
    var topSubjects: [IncidentBreakdown]
    var topReasons: [IncidentBreakdown]
    var topTypes: [IncidentBreakdown]
    var monthlyTrend: [ServiceRequestMonth]
    var recentRequests: [ServiceRequestRecord]
}

struct ServiceRequestMonth: Identifiable {
    var id: String { "\(year)-\(month)" }
    var year: Int
    var month: Int
    var count: Int

    var label: String {
        let symbols = Calendar.current.shortMonthSymbols
        let monthName = month >= 1 && month <= symbols.count ? symbols[month - 1] : "\(month)"
        return "\(monthName) \(String(year).suffix(2))"
    }
}

struct ServiceRequestRecord: Identifiable {
    let uuid = UUID()
    var id: String { caseID ?? interactionID ?? uuid.uuidString }
    var caseID: String?
    var interactionID: String?
    var channel: String?
    var subject: String?
    var reason: String?
    var type: String?
    var openDate: Date?
    var closedDate: Date?
    var status: String?
    var ward: String?
    var coordinate: CLLocationCoordinate2D?
}

struct PlanningContextSummary {
    var zoningCode: String?
    var zoningDescription: String?
    var publicNotices: [PublicNotice]
}

struct PublicNotice: Identifiable {
    let id = UUID()
    var noticeType: String
    var address: String
    var description: String?
    var decision: String?
    var meetingDate: Date?
    var distanceDescription: String?
    var coordinate: CLLocationCoordinate2D?
}

struct StreetAccessSummary {
    var pavementCondition: String?
    var pavementSurface: String?
    var schoolSpeedLimit: SchoolSpeedLimit?
    var cyclingRoutesNearby: Int
    var activeDisruptions: [StreetDisruption]
    var activeLaneClosures: [StreetDisruption]
}

struct SchoolSpeedLimit {
    var school: String
    var speedLimit: String
    var effectiveDays: String?
    var effectiveTime: String?
}

struct StreetDisruption: Identifiable {
    let id = UUID()
    var title: String
    var detail: String?
    var status: String?
    var startDate: Date?
    var endDate: Date?
    var distanceDescription: String?
    var coordinate: CLLocationCoordinate2D?
}

struct EmergencySummary {
    var neighbourhood: String
    var totalLastYear: Int
    var motorVehicleLastYear: Int
    var averageDurationMinutes: Double?
    var yearlyCalls: [YearCount]
    var monthlyTrend: [EmergencyMonth]
    var last12Months: [IncidentBreakdown]
    var breakdownByYear: [Int: [IncidentBreakdown]] = [:]
    var wardBreakdown: [IncidentBreakdown] = []
    var motorVehicleBreakdown: [IncidentBreakdown] = []
    var unitBreakdown: [IncidentBreakdown] = []
    var recentIncidents: [EmergencyIncidentRecord] = []
    var citywideMedian: Int?
    var neighbourhoodRank: Int?
    var neighbourhoodCount: Int?
}

struct EmergencyMonth: Identifiable {
    var id: String { "\(year)-\(month)" }
    var year: Int
    var month: Int
    var count: Int

    var label: String {
        let symbols = Calendar.current.shortMonthSymbols
        let monthName = month >= 1 && month <= symbols.count ? symbols[month - 1] : "\(month)"
        return "\(monthName) \(String(year).suffix(2))"
    }
}

struct EmergencyIncidentRecord: Identifiable {
    private let uuid = UUID()
    var id: String { incidentNumber ?? uuid.uuidString }
    var incidentNumber: String?
    var incidentType: String
    var callTime: Date?
    var closedTime: Date?
    var motorVehicleIncident: String?
    var units: String?
    var ward: String?

    var durationMinutes: Int? {
        guard let callTime, let closedTime else { return nil }
        return max(Int(closedTime.timeIntervalSince(callTime) / 60), 0)
    }
}

struct IncidentBreakdown: Identifiable {
    var id: String { incidentType }
    var incidentType: String
    var count: Int
}

struct PublicHealthSummary {
    var yearlyEvents: [PublicHealthYear]
    var ageGroups: [IncidentBreakdown]
    var ageGroupsByYear: [Int: [IncidentBreakdown]] = [:]
    var substances: [IncidentBreakdown]
    var substancesByYear: [Int: [IncidentBreakdown]] = [:]
}

struct PublicHealthYear: Identifiable {
    var id: Int { year }
    var year: Int
    var neighbourhood: Int
    var citywideAverage: Double
}

struct PoliceCrimeSummary {
    var neighbourhood: String
    var latestMonth: PoliceCrimeMonth?
    var yearlyCounts: [PoliceCrimeYear]
    var crimeTypes: [IncidentBreakdown]
    var crimeTypesByYear: [Int: [IncidentBreakdown]] = [:]
    var offenceTypes: [IncidentBreakdown]
    var offenceTypesByYear: [Int: [IncidentBreakdown]] = [:]
}

struct PoliceCrimeYear: Identifiable {
    var id: Int { year }
    var year: Int
    var neighbourhood: Int
    var citywideAverage: Double
}

struct PoliceCrimeMonth {
    var year: Int
    var month: Int

    var label: String {
        let symbols = Calendar.current.shortMonthSymbols
        let monthName = month >= 1 && month <= symbols.count ? symbols[month - 1] : "\(month)"
        return "\(monthName) \(year)"
    }
}

struct DatasetSource: Identifiable {
    var id: String { datasetID }
    var name: String
    var datasetID: String
    var url: URL
}
