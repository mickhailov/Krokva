import CoreLocation
import Foundation

// CLLocationCoordinate2D doesn't conform to Codable — add retroactive conformance here
// so all report structs can be encoded/decoded for on-device storage.
extension CLLocationCoordinate2D: @retroactive Codable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(latitude)
        try c.encode(longitude)
    }
    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        let lat = try c.decode(Double.self)
        let lng = try c.decode(Double.self)
        self.init(latitude: lat, longitude: lng)
    }
}

struct AddressReport: Identifiable, Codable {
    let id: UUID
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
    var shortTermRentals: ShortTermRentalSummary?
    var civicContext: AddressCivicContext?
    var recreation: RecreationSummary?
    var nearbySchools: [SchoolAmenity] = []
    var waste: WasteCollectionSummary?
    var demographics: DemographicsSummary?
    var localGovernment: LocalGovernmentSummary?
    var localBusiness: LocalBusinessSummary?
    var aquatics: AquaticsAmenitiesSummary?
    var traffic: TrafficSummary?
    var neighbourhoodRisk: NeighbourhoodRiskSummary?
    var waterQuality: WaterQualitySummary?
    var capitalWorks: CapitalWorksSummary?
    var facilityClosures: FacilityClosureSummary?
    var sources: [DatasetSource] = []
    /// Modules whose data source threw a network/HTTP error during this build. A card uses
    /// this to show "Database error" instead of silently hiding when its module is empty.
    /// Optional so reports persisted before this field decode cleanly (missing key → nil).
    var failedModules: Set<ReportModule>? = nil

    init(
        id: UUID = UUID(),
        address: NormalizedAddress,
        providerID: String,
        cityName: String,
        providerState: ProviderImplementationState,
        property: PropertyAssessment? = nil,
        neighbourhoodValues: [AssessmentValueBin] = [],
        comparables: [ComparableProperty] = [],
        permits: [BuildingPermit] = [],
        permitActivity: [YearCount] = [],
        vacantOrders: [VacantOrder] = [],
        infrastructure: InfrastructureSummary? = nil,
        parks: ParksSummary? = nil,
        transit: TransitAccessSummary? = nil,
        bylaw: BylawInvestigationSummary? = nil,
        development: DevelopmentContextSummary? = nil,
        river: RiverGaugeSummary? = nil,
        library: LibraryAmenity? = nil,
        serviceRequests: ServiceRequestSummary? = nil,
        planning: PlanningContextSummary? = nil,
        streetAccess: StreetAccessSummary? = nil,
        emergency: EmergencySummary? = nil,
        publicHealth: PublicHealthSummary? = nil,
        policeCrime: PoliceCrimeSummary? = nil,
        shortTermRentals: ShortTermRentalSummary? = nil,
        civicContext: AddressCivicContext? = nil,
        recreation: RecreationSummary? = nil,
        nearbySchools: [SchoolAmenity] = [],
        waste: WasteCollectionSummary? = nil,
        demographics: DemographicsSummary? = nil,
        localGovernment: LocalGovernmentSummary? = nil,
        localBusiness: LocalBusinessSummary? = nil,
        aquatics: AquaticsAmenitiesSummary? = nil,
        traffic: TrafficSummary? = nil,
        neighbourhoodRisk: NeighbourhoodRiskSummary? = nil,
        waterQuality: WaterQualitySummary? = nil,
        capitalWorks: CapitalWorksSummary? = nil,
        facilityClosures: FacilityClosureSummary? = nil,
        sources: [DatasetSource] = [],
        failedModules: Set<ReportModule>? = nil
    ) {
        self.id = id
        self.address = address
        self.providerID = providerID
        self.cityName = cityName
        self.providerState = providerState
        self.property = property
        self.neighbourhoodValues = neighbourhoodValues
        self.comparables = comparables
        self.permits = permits
        self.permitActivity = permitActivity
        self.vacantOrders = vacantOrders
        self.infrastructure = infrastructure
        self.parks = parks
        self.transit = transit
        self.bylaw = bylaw
        self.development = development
        self.river = river
        self.library = library
        self.serviceRequests = serviceRequests
        self.planning = planning
        self.streetAccess = streetAccess
        self.emergency = emergency
        self.publicHealth = publicHealth
        self.policeCrime = policeCrime
        self.shortTermRentals = shortTermRentals
        self.civicContext = civicContext
        self.recreation = recreation
        self.nearbySchools = nearbySchools
        self.waste = waste
        self.demographics = demographics
        self.localGovernment = localGovernment
        self.localBusiness = localBusiness
        self.aquatics = aquatics
        self.traffic = traffic
        self.neighbourhoodRisk = neighbourhoodRisk
        self.waterQuality = waterQuality
        self.capitalWorks = capitalWorks
        self.facilityClosures = facilityClosures
        self.sources = sources
        self.failedModules = failedModules
    }

    /// Convenience for views: did this module's data source fail to load?
    func moduleFailed(_ module: ReportModule) -> Bool {
        failedModules?.contains(module) ?? false
    }

    static func comingSoon(address: NormalizedAddress, provider: any CityDataProvider) -> AddressReport {
        AddressReport(address: address, providerID: provider.cityID, cityName: provider.displayName, providerState: .comingSoon, sources: [])
    }

    /// The foundational lookups (assessment + civic context) errored and produced nothing,
    /// so the empty report is a database failure rather than a genuine "address not on file".
    var dataSourceUnavailable: Bool {
        providerState == .live && property == nil && civicContext == nil
            && (moduleFailed(.property) || moduleFailed(.civicContext))
    }

    /// An address that resolves no assessment and no civic match means the city's open
    /// data has nothing for it — typically a typo or an address outside coverage. Such a
    /// report has nothing worth navigating to, so callers should keep the user on the
    /// search screen instead of pushing an empty report. A database failure (see
    /// `dataSourceUnavailable`) is excluded — that is an error, not a missing address.
    var addressNotFound: Bool {
        providerState == .live && property == nil && civicContext == nil && !dataSourceUnavailable
    }
}

struct PropertyAssessment: Codable {
    var fullAddress: String
    var neighbourhood: String
    var postalCode: String?
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
    var assessmentYear: Int? = nil
    var propertyTaxYear: Int? = nil
}

struct AssessmentValueBin: Identifiable, Codable {
    let id: UUID
    var bucket: String
    var count: Int
    var midpoint: Double

    init(id: UUID = UUID(), bucket: String, count: Int, midpoint: Double) {
        self.id = id
        self.bucket = bucket
        self.count = count
        self.midpoint = midpoint
    }
}

struct ComparableProperty: Identifiable, Codable {
    let id: UUID
    var address: String
    var value: Double
    var livingArea: Double
    var yearBuilt: Int?

    init(id: UUID = UUID(), address: String, value: Double, livingArea: Double, yearBuilt: Int? = nil) {
        self.id = id
        self.address = address
        self.value = value
        self.livingArea = livingArea
        self.yearBuilt = yearBuilt
    }
}

struct BuildingPermit: Identifiable, Codable {
    let id: UUID
    var issuedDate: Date?
    var type: String
    var subType: String?
    var workType: String?
    var address: String
    var status: String?
    var isAdjacentStructural: Bool
    var coordinate: CLLocationCoordinate2D?

    init(id: UUID = UUID(), issuedDate: Date? = nil, type: String, subType: String? = nil, workType: String? = nil, address: String, status: String? = nil, isAdjacentStructural: Bool, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.issuedDate = issuedDate
        self.type = type
        self.subType = subType
        self.workType = workType
        self.address = address
        self.status = status
        self.isAdjacentStructural = isAdjacentStructural
        self.coordinate = coordinate
    }
}

struct YearCount: Identifiable, Codable {
    var id: Int { year }
    var year: Int
    var count: Int
    /// City-wide average count per neighbourhood for this year (0 when not applicable).
    var citywideAverage: Double = 0
}

struct VacantOrder: Identifiable, Codable {
    let id: UUID
    var issuedDate: Date?
    var address: String
    var orderType: String
    var distanceDescription: String?
    var coordinate: CLLocationCoordinate2D?

    init(id: UUID = UUID(), issuedDate: Date? = nil, address: String, orderType: String, distanceDescription: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.issuedDate = issuedDate
        self.address = address
        self.orderType = orderType
        self.distanceDescription = distanceDescription
        self.coordinate = coordinate
    }
}

struct InfrastructureSummary: Codable {
    var speedLimit: String?
    var potholes: Int
    var publicTrees: Int
    var taggedTrees: Int
    var topTreeSpecies: String? = nil
}

struct ParksSummary: Codable {
    var nearestPark: ParkAmenity?
    var nearbyParks: [ParkAmenity] = []
    var neighbourhoodParkCount: Int
    var neighbourhoodHectares: Double?
    var nearestDogPark: DogParkAmenity? = nil
}

struct ParkAmenity: Identifiable, Codable {
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

struct DogParkAmenity: Identifiable, Codable {
    var id: String { parkID }
    var parkID: String
    var name: String
    var distanceDescription: String
    var classification: String?
    var coordinate: CLLocationCoordinate2D?
}

struct TransitAccessSummary: Codable {
    var nearestStop: TransitStop?
    var routes: [TransitRouteSummary]
    var averageDeviationSeconds: Double?
    var onTimePercentage: Double?
    var passUpsLastYear: Int
    var averageDailyBoardings: Double?
}

struct TransitStop: Identifiable, Codable {
    var id: String { stopNumber }
    var stopNumber: String
    var distanceDescription: String
}

struct TransitRouteSummary: Identifiable, Codable {
    var id: String { routeNumber }
    var routeNumber: String
    var routeName: String
}

struct BylawInvestigationSummary: Codable {
    var neighbourhood: String
    var yearly: [YearCount]
    var complaintTypes: [IncidentBreakdown]
}

struct DevelopmentContextSummary: Codable {
    var recentPermits: [DevelopmentPermit]
    var reviewProcessing: [PermitProcessingMetric]
    var intake: [PermitIntakeMetric]
}

struct DevelopmentPermit: Identifiable, Codable {
    let id: UUID
    var issuedDate: Date?
    var permitNumber: String?
    var type: String
    var subType: String?
    var workType: String?
    var address: String
    var status: String?
    var coordinate: CLLocationCoordinate2D?

    init(id: UUID = UUID(), issuedDate: Date? = nil, permitNumber: String? = nil, type: String, subType: String? = nil, workType: String? = nil, address: String, status: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.issuedDate = issuedDate
        self.permitNumber = permitNumber
        self.type = type
        self.subType = subType
        self.workType = workType
        self.address = address
        self.status = status
        self.coordinate = coordinate
    }
}

struct PermitProcessingMetric: Identifiable, Codable {
    let id: UUID
    var description: String
    var month: Date?
    var averageBusinessDays: Double
    var serviceStandardDays: Double?
    var percentMetTarget: Double?

    init(id: UUID = UUID(), description: String, month: Date? = nil, averageBusinessDays: Double, serviceStandardDays: Double? = nil, percentMetTarget: Double? = nil) {
        self.id = id
        self.description = description
        self.month = month
        self.averageBusinessDays = averageBusinessDays
        self.serviceStandardDays = serviceStandardDays
        self.percentMetTarget = percentMetTarget
    }
}

struct PermitIntakeMetric: Identifiable, Codable {
    let id: UUID
    var description: String
    var month: Date?
    var approved: Int
    var notApproved: Int

    init(id: UUID = UUID(), description: String, month: Date? = nil, approved: Int, notApproved: Int) {
        self.id = id
        self.description = description
        self.month = month
        self.approved = approved
        self.notApproved = notApproved
    }
}

struct RiverGaugeSummary: Codable {
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

struct LibraryAmenity: Identifiable, Codable {
    let id: UUID
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

    init(id: UUID = UUID(), name: String, address: String, distanceDescription: String, wifi: Bool, accessibility: Bool, parkingLot: Bool, parkingStalls: Int? = nil, roomRentals: Bool, notes: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.distanceDescription = distanceDescription
        self.wifi = wifi
        self.accessibility = accessibility
        self.parkingLot = parkingLot
        self.parkingStalls = parkingStalls
        self.roomRentals = roomRentals
        self.notes = notes
        self.coordinate = coordinate
    }
}

struct ServiceRequestSummary: Codable {
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

struct ServiceRequestMonth: Identifiable, Codable {
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

struct ServiceRequestRecord: Identifiable, Codable {
    let uuid: UUID
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

    init(uuid: UUID = UUID(), caseID: String? = nil, interactionID: String? = nil, channel: String? = nil, subject: String? = nil, reason: String? = nil, type: String? = nil, openDate: Date? = nil, closedDate: Date? = nil, status: String? = nil, ward: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.uuid = uuid
        self.caseID = caseID
        self.interactionID = interactionID
        self.channel = channel
        self.subject = subject
        self.reason = reason
        self.type = type
        self.openDate = openDate
        self.closedDate = closedDate
        self.status = status
        self.ward = ward
        self.coordinate = coordinate
    }
}

struct PlanningContextSummary: Codable {
    var zoningCode: String?
    var zoningDescription: String?
    var publicNotices: [PublicNotice]
}

struct PublicNotice: Identifiable, Codable {
    let id: UUID
    var noticeType: String
    var address: String
    var description: String?
    var decision: String?
    var meetingDate: Date?
    var distanceDescription: String?
    var coordinate: CLLocationCoordinate2D?

    init(id: UUID = UUID(), noticeType: String, address: String, description: String? = nil, decision: String? = nil, meetingDate: Date? = nil, distanceDescription: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.noticeType = noticeType
        self.address = address
        self.description = description
        self.decision = decision
        self.meetingDate = meetingDate
        self.distanceDescription = distanceDescription
        self.coordinate = coordinate
    }
}

struct StreetAccessSummary: Codable {
    var pavementCondition: String?
    var pavementSurface: String?
    var roadType: String?
    var schoolSpeedLimit: SchoolSpeedLimit?
    var cyclingRoutesNearby: Int
    var activeDisruptions: [StreetDisruption]
    var activeLaneClosures: [StreetDisruption]
}

struct SchoolSpeedLimit: Codable {
    var school: String
    var speedLimit: String
    var effectiveDays: String?
    var effectiveTime: String?
}

struct StreetDisruption: Identifiable, Codable {
    let id: UUID
    var title: String
    var detail: String?
    var status: String?
    var startDate: Date?
    var endDate: Date?
    var distanceDescription: String?
    var coordinate: CLLocationCoordinate2D?

    init(id: UUID = UUID(), title: String, detail: String? = nil, status: String? = nil, startDate: Date? = nil, endDate: Date? = nil, distanceDescription: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.distanceDescription = distanceDescription
        self.coordinate = coordinate
    }
}

struct EmergencySummary: Codable {
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

struct EmergencyMonth: Identifiable, Codable {
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

struct EmergencyIncidentRecord: Identifiable, Codable {
    let uuid: UUID
    var id: String { incidentNumber ?? uuid.uuidString }
    var incidentNumber: String?
    var incidentType: String
    var callTime: Date?
    var closedTime: Date?
    var motorVehicleIncident: String?
    var units: String?
    var ward: String?

    init(uuid: UUID = UUID(), incidentNumber: String? = nil, incidentType: String, callTime: Date? = nil, closedTime: Date? = nil, motorVehicleIncident: String? = nil, units: String? = nil, ward: String? = nil) {
        self.uuid = uuid
        self.incidentNumber = incidentNumber
        self.incidentType = incidentType
        self.callTime = callTime
        self.closedTime = closedTime
        self.motorVehicleIncident = motorVehicleIncident
        self.units = units
        self.ward = ward
    }

    var durationMinutes: Int? {
        guard let callTime, let closedTime else { return nil }
        return max(Int(closedTime.timeIntervalSince(callTime) / 60), 0)
    }
}

struct IncidentBreakdown: Identifiable, Codable {
    var id: String { incidentType }
    var incidentType: String
    var count: Int
    /// City-wide average count per neighbourhood for this same type (0 when not applicable).
    var citywideAverage: Double = 0
}

struct HealthFacilityAccess: Codable {
    var name: String
    var address: String?
    var city: String? = nil
    var province: String? = nil
    var driveMinutes: Double?
    var avgWaitMinutes: Int? = nil
    var currentWaitMinutes: Int? = nil
    var waitingPatients: Int? = nil
    var treatingPatients: Int? = nil
    var waitTimeUpdatedAt: String? = nil
    var waitTimeAttribution: String? = nil
    var liveStatus: EmergencyRoomStatus? = nil
}

struct DefibrillatorAccess: Codable {
    var name: String
    var locationDescription: String?
    var access: String?
    var indoor: Bool?
    var distanceDescription: String
    var coordinate: CLLocationCoordinate2D?
    var source: String? = nil
}

struct PublicHealthSummary: Codable {
    var yearlyEvents: [PublicHealthYear]
    var ageGroups: [IncidentBreakdown]
    var ageGroupsByYear: [Int: [IncidentBreakdown]] = [:]
    var substances: [IncidentBreakdown]
    var substancesByYear: [Int: [IncidentBreakdown]] = [:]
    var nearestER: HealthFacilityAccess? = nil
    var nearestWalkIn: HealthFacilityAccess? = nil
    var walkInClinicsNearby: Int? = nil
    var nearestAED: DefibrillatorAccess? = nil
    var aedsNearby: Int? = nil
    var emergencyRoomClosures: [EmergencyRoomStatus] = []
    var emergencyRoomAttribution: String? = nil
}

struct EmergencyRoomStatus: Identifiable, Codable {
    var id: Int
    var name: String
    var city: String
    var province: String
    var status: String
    var message: String
    var updatedAt: Date?
    var expectedReopen: Date?

    var statusLabel: String {
        switch status.lowercased() {
        case "closed":
            return "Closed"
        case "disruption":
            return "Disruption"
        default:
            return status.capitalized
        }
    }
}

struct PublicHealthYear: Identifiable, Codable {
    var id: Int { year }
    var year: Int
    var neighbourhood: Int
    var citywideAverage: Double
}

struct PoliceCrimeSummary: Codable {
    var neighbourhood: String
    var latestMonth: PoliceCrimeMonth?
    var yearlyCounts: [PoliceCrimeYear]
    var crimeTypes: [IncidentBreakdown]
    var crimeTypesByYear: [Int: [IncidentBreakdown]] = [:]
    var offenceTypes: [IncidentBreakdown]
    var offenceTypesByYear: [Int: [IncidentBreakdown]] = [:]
}

struct PoliceCrimeYear: Identifiable, Codable {
    var id: Int { year }
    var year: Int
    var neighbourhood: Int
    var citywideAverage: Double
}

struct PoliceCrimeMonth: Codable {
    var year: Int
    var month: Int

    var label: String {
        let symbols = Calendar.current.shortMonthSymbols
        let monthName = month >= 1 && month <= symbols.count ? symbols[month - 1] : "\(month)"
        return "\(monthName) \(year)"
    }
}

struct SchoolAmenity: Identifiable, Codable {
    let id: UUID
    var name: String
    var address: String
    var distanceDescription: String
    var distanceMeters: Double?
    var walkingTimeDescription: String?
    var grades: String?
    var schoolType: String?
    var programs: [String]
    var isAssigned: Bool
    var source: String?
    var coordinate: CLLocationCoordinate2D?

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        distanceDescription: String,
        distanceMeters: Double? = nil,
        walkingTimeDescription: String? = nil,
        grades: String? = nil,
        schoolType: String? = nil,
        programs: [String] = [],
        isAssigned: Bool = false,
        source: String? = nil,
        coordinate: CLLocationCoordinate2D? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.distanceDescription = distanceDescription
        self.distanceMeters = distanceMeters
        self.walkingTimeDescription = walkingTimeDescription
        self.grades = grades
        self.schoolType = schoolType
        self.programs = programs
        self.isAssigned = isAssigned
        self.source = source
        self.coordinate = coordinate
    }
}

struct ShortTermRentalSummary: Codable {
    var total: Int
    var primaryCount: Int
    var nonPrimaryCount: Int
    var recent: [ShortTermRentalRecord]
}

struct ShortTermRentalRecord: Identifiable, Codable {
    let id: UUID
    var address: String
    var primaryStatus: String?
    var issuedDate: Date?
    var ward: String?

    init(id: UUID = UUID(), address: String, primaryStatus: String? = nil, issuedDate: Date? = nil, ward: String? = nil) {
        self.id = id
        self.address = address
        self.primaryStatus = primaryStatus
        self.issuedDate = issuedDate
        self.ward = ward
    }
}

struct AddressCivicContext: Codable {
    var addressID: String?
    var ward: String?
    var neighbourhood: String?
    var postalCode: String?
    var plowZone: String?
    var schoolDivision: String?
    var schoolDivisionBoundaryName: String?
    var schoolDivisionCode: String?
    var schoolDivisionWard: String?
    var schoolDivisionWebsite: String?
}

struct RecreationSummary: Codable {
    var nearestComplex: RecreationComplex?
    var complexes: [RecreationComplex]
    var activities: [RecreationActivity]
    var communityCentres: [CommunityCentre] = []
}

struct RecreationComplex: Identifiable, Codable {
    let id: UUID
    var name: String
    var address: String?
    var distanceDescription: String?
    var amenities: [String]
    var coordinate: CLLocationCoordinate2D?

    init(id: UUID = UUID(), name: String, address: String? = nil, distanceDescription: String? = nil, amenities: [String] = [], coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.distanceDescription = distanceDescription
        self.amenities = amenities
        self.coordinate = coordinate
    }
}

struct CommunityCentre: Identifiable, Codable {
    let id: UUID
    var name: String
    var address: String?
    var distanceDescription: String?
    var coordinate: CLLocationCoordinate2D?

    init(id: UUID = UUID(), name: String, address: String? = nil, distanceDescription: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.distanceDescription = distanceDescription
        self.coordinate = coordinate
    }
}

struct RecreationActivity: Identifiable, Codable {
    let id: UUID
    var name: String
    var placeName: String?
    var category: String?
    var activityType: String?
    var status: String?
    var startDate: Date?
    var endDate: Date?
    var openSpaces: String?
    var publicURL: String?

    init(id: UUID = UUID(), name: String, placeName: String? = nil, category: String? = nil, activityType: String? = nil, status: String? = nil, startDate: Date? = nil, endDate: Date? = nil, openSpaces: String? = nil, publicURL: String? = nil) {
        self.id = id
        self.name = name
        self.placeName = placeName
        self.category = category
        self.activityType = activityType
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.openSpaces = openSpaces
        self.publicURL = publicURL
    }
}

struct DatasetSource: Identifiable, Codable {
    var id: String { datasetID }
    var name: String
    var datasetID: String
    var url: URL
}

// MARK: - Waste collection & winter operations

struct WasteCollectionSummary: Codable {
    var garbageDay: String?
    var recycleDay: String?
    var yardWasteDay: String?
    var matchedAddress: String?
    var plowZone: String?
    var nextPlowWindow: String?
    var activeSnowBan: SnowBanInfo?
}

struct SnowBanInfo: Codable {
    var description: String
    var start: Date?
    var end: Date?
}

// MARK: - Neighbourhood demographics

struct DemographicsSummary: Codable {
    var boundaryName: String
    var totalPopulation: Int?
    var childrenPercent: Double?      // 0-14
    var seniorsPercent: Double?       // 65+
    var medianHouseholdIncome: Double?
    var averageHouseholdSize: Double?
    var immigrantPercent: Double?
    var topNonOfficialLanguage: String?
    var commuteModes: [IncidentBreakdown] = []   // car / public / walk / bicycle, as counts
    var isHighPovertyArea: Bool?
    var giniIndex: Double?
}

// MARK: - Local government

struct LocalGovernmentSummary: Codable {
    var wardName: String?
    var councillor: String?
    var councillorPhone: String?
    var councillorWebsite: String?
    var communityCommittee: String?
}

// MARK: - Local businesses

struct LocalBusinessSummary: Codable {
    var totalNearby: Int
    var topCategories: [IncidentBreakdown]
    var recent: [LocalBusinessRecord]
    var patios: [LocalBusinessRecord]
}

struct LocalBusinessRecord: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: String?
    var distanceDescription: String?
    var coordinate: CLLocationCoordinate2D?

    init(id: UUID = UUID(), name: String, category: String? = nil, distanceDescription: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.distanceDescription = distanceDescription
        self.coordinate = coordinate
    }
}

// MARK: - Aquatics & amenities

struct AquaticsAmenitiesSummary: Codable {
    var pools: [PoolAmenity]
    var walkwaysNearby: Int
    var nearestWifi: NamedAmenity?
}

struct PoolAmenity: Identifiable, Codable {
    let id: UUID
    var name: String
    var kind: String          // Indoor / Outdoor / Wading / Spray pad
    var address: String?
    var isOpen: Bool?
    var distanceDescription: String?
    var features: [String]
    var website: String?
    var coordinate: CLLocationCoordinate2D?

    init(id: UUID = UUID(), name: String, kind: String, address: String? = nil, isOpen: Bool? = nil, distanceDescription: String? = nil, features: [String] = [], website: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.address = address
        self.isOpen = isOpen
        self.distanceDescription = distanceDescription
        self.features = features
        self.website = website
        self.coordinate = coordinate
    }
}

struct NamedAmenity: Codable {
    var name: String
    var distanceDescription: String?
    var coordinate: CLLocationCoordinate2D?
}

// MARK: - Traffic

struct TrafficSummary: Codable {
    var streetStudy: TrafficStudy?
    var nearestPermanentStation: TrafficStudy?
}

struct TrafficStudy: Codable {
    var locationDescription: String
    var vehiclesCounted: Int?
    var countDate: Date?
    var direction: String?
    var distanceDescription: String?
    var countMetricLabel: String?
    var countSummaryUnit: String?
    var countNote: String?
}

// MARK: - Neighbourhood risk

struct NeighbourhoodRiskSummary: Codable {
    var roomingHouse: RoomingHouseActivity?
    var vacantFireTrend: [YearCount]
    var towingNearby: Int
    var paidParkingNearby: Int
    var nearestPaidParking: String?
    var graffitiReports: Int? = nil
}

struct RoomingHouseActivity: Codable {
    var year: Int
    var complaintDriven: Int?
    var proactive: Int?
    var inProgress: Int?
    var completed: Int?
}

// MARK: - Water quality

struct WaterQualitySummary: Codable {
    var year: Int?
    var area: String?
    var parameters: [WaterQualityReading]
}

struct WaterQualityReading: Identifiable, Codable {
    let id: UUID
    var parameter: String
    var average: Double?
    var minimum: Double?
    var maximum: Double?
    var units: String?

    init(id: UUID = UUID(), parameter: String, average: Double? = nil, minimum: Double? = nil, maximum: Double? = nil, units: String? = nil) {
        self.id = id
        self.parameter = parameter
        self.average = average
        self.minimum = minimum
        self.maximum = maximum
        self.units = units
    }
}

// MARK: - Capital works

struct CapitalWorksSummary: Codable {
    var projects: [CapitalProject]
}

struct CapitalProject: Identifiable, Codable {
    let id: UUID
    var name: String
    var detail: String?
    var status: String?
    var budget: Double?
    var year: String?
    var funded: Bool?

    init(id: UUID = UUID(), name: String, detail: String? = nil, status: String? = nil, budget: Double? = nil, year: String? = nil, funded: Bool? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.status = status
        self.budget = budget
        self.year = year
        self.funded = funded
    }
}

// MARK: - Facility closures (health protection)

struct FacilityClosureSummary: Codable {
    var closures: [FacilityClosureRecord]
}

struct FacilityClosureRecord: Identifiable, Codable {
    let id: UUID
    var name: String
    var establishmentType: String?
    var reason: String?
    var closureDate: Date?
    var reopenDate: Date?

    init(id: UUID = UUID(), name: String, establishmentType: String? = nil, reason: String? = nil, closureDate: Date? = nil, reopenDate: Date? = nil) {
        self.id = id
        self.name = name
        self.establishmentType = establishmentType
        self.reason = reason
        self.closureDate = closureDate
        self.reopenDate = reopenDate
    }
}
