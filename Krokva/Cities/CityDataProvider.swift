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
    var cyclingNetwork: String? = nil
    var policeCrimeMaps: String? = nil
}

struct FieldMappings {
    var assessment: [String: String] = [:]
    var permits: [String: String] = [:]
    var generic: [String: [String: String]] = [:]
}

enum ProviderImplementationState: Equatable {
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

    func fetchDossier(for address: NormalizedAddress) async -> AddressDossier
}
