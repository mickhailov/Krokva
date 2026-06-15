import Foundation
import MapKit

struct CityDatasets {
    var assessment: String?
    var permits: String?
    var vacantOrders: String?
    var speedLimits: String?
    var potholes: String?
    var trees: String?
    var shortTermRentals: String?
    var emergencyCalls: String?
    var naloxone: String?
    var substanceUse: String?
    var tradePermits: String? = nil
    var parkAssets: String? = nil
    var parksOpenSpace: String? = nil
    var transitOnTime: String? = nil
    var transitPassUps: String? = nil
    var transitPassengerActivity: String? = nil
    var bylawInvestigations: String? = nil
    var developmentPermits: String? = nil
    var developmentPermitProcessingTimes: String? = nil
    var developmentPermitIntake: String? = nil
    var riverWaterLevels: String? = nil
    var libraries: String? = nil
    var neighbourhoods: String? = nil
    var serviceRequests: String? = nil
    var zoningParcels: String? = nil
    var publicNotices: String? = nil
    var accessibilityDisruptions: String? = nil
    var laneClosures: String? = nil
    var pavementCondition: String? = nil
    var schoolSpeedLimits: String? = nil
    var schools: String? = nil
    var cyclingNetwork: String? = nil
    var policeCrimeMaps: String? = nil
    var addresses: String? = nil
    var schoolDivisions: String? = nil
    var recreationComplexes: String? = nil
    var leisureActivities: String? = nil
    var publicAeds: String? = nil
    var snowRouteAddresses: String? = nil
    var plowZones: String? = nil
    // Daily-living logistics
    var wasteCollection: String? = nil
    var snowParkingBans: String? = nil
    var plowZoneSchedule: String? = nil
    // Local commerce
    var businessLicenses: String? = nil
    var seasonalPatios: String? = nil
    // Environment
    var waterQuality: String? = nil
    // Traffic
    var midblockTrafficCounts: String? = nil
    var permanentTrafficCounts: String? = nil
    // Census demographics
    var censusAge: String? = nil
    var censusHouseholds: String? = nil
    var censusLanguage: String? = nil
    var censusTransportMode: String? = nil
    var censusImmigration: String? = nil
    var higherPovertyAreas: String? = nil
    // Local government
    var electoralWards: String? = nil
    var communityCommittees: String? = nil
    // Aquatics & amenities
    var poolsIndoor: String? = nil
    var poolsOutdoor: String? = nil
    var poolsWading: String? = nil
    var poolsSprayPad: String? = nil
    var walkways: String? = nil
    var publicWifi: String? = nil
    // Neighbourhood risk
    var vacantPropertyFires: String? = nil
    var roomingHouseEnforcement: String? = nil
    var rushHourTowing: String? = nil
    var paidParking: String? = nil
    // Capital works
    var capitalProjects: String? = nil
    var infrastructureFunding: String? = nil
    // Health protection
    var facilityClosures: String? = nil

    // Heritage & insect control
    var heritage: String? = nil
    var mosquitoTraps: String? = nil
}

struct FieldMappings {
    var assessment: [String: String] = [:]
    var permits: [String: String] = [:]
    var generic: [String: [String: String]] = [:]
}

enum ProviderImplementationState: Equatable, Codable {
    case live
    case comingSoon
}

protocol CityDataProvider {
    var cityID: String { get }
    var displayName: String { get }
    var attribution: String { get }
    var datasets: CityDatasets { get }
    var fieldMappings: FieldMappings { get }
    var addressNormalizer: AddressNormalizer { get }
    var boundingBox: MKMapRect { get }
    var implementationState: ProviderImplementationState { get }

    func fetchReport(for address: NormalizedAddress) async -> AddressReport
}
