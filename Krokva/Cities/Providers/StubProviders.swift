import Foundation
import MapKit

class ComingSoonProvider: CityDataProvider {
    let cityID: String
    let displayName: String
    let attribution: String
    let datasets: CityDatasets
    let fieldMappings = FieldMappings()
    let addressNormalizer: AddressNormalizer = DefaultAddressNormalizer()
    let boundingBox = MKMapRect.world
    let implementationState: ProviderImplementationState = .comingSoon

    init(cityID: String, displayName: String, attribution: String, datasets: CityDatasets) {
        self.cityID = cityID
        self.displayName = displayName
        self.attribution = attribution
        self.datasets = datasets
    }

    func fetchDossier(for address: NormalizedAddress) async -> AddressDossier {
        .comingSoon(address: address, provider: self)
    }
}

final class CalgaryProvider: ComingSoonProvider {
    init() {
        super.init(
            cityID: "calgary",
            displayName: "Calgary, AB",
            attribution: "Calgary Open Data Licence.",
            datasets: CityDatasets(
                assessment: "4bsw-nn7w", // Current Year Property Assessments: https://data.calgary.ca/d/4bsw-nn7w
                permits: "c2es-76ed",    // Building Permits: https://data.calgary.ca/d/c2es-76ed
                vacantOrders: nil,
                speedLimits: nil,         // TODO: confirm speed limit centreline dataset.
                potholes: nil,
                trees: nil,               // TODO: Tree Inventory on data.calgary.ca.
                shortTermRentals: nil,
                emergencyCalls: nil,      // TODO: Traffic/fire incident equivalents.
                naloxone: nil,
                substanceUse: nil
            )
        )
    }
}

final class TorontoProvider: ComingSoonProvider {
    init() {
        super.init(
            cityID: "toronto",
            displayName: "Toronto, ON",
            attribution: "Toronto Open Data Licence.",
            datasets: CityDatasets(
                assessment: nil,          // TODO CKAN: Property Assessment Roll, open.toronto.ca.
                permits: nil,             // TODO CKAN: Building Permits, open.toronto.ca.
                vacantOrders: nil,
                speedLimits: nil,
                potholes: nil,            // TODO CKAN: Pavement condition / service requests.
                trees: nil,               // TODO CKAN: Street Tree Data.
                shortTermRentals: nil,    // TODO CKAN: Short-Term Rental Registrations.
                emergencyCalls: nil,      // TODO CKAN: Fire Incidents.
                naloxone: nil,
                substanceUse: nil
            )
        )
    }
}

final class EdmontonProvider: ComingSoonProvider {
    init() {
        super.init(
            cityID: "edmonton",
            displayName: "Edmonton, AB",
            attribution: "City of Edmonton Open Data Terms of Use.",
            datasets: CityDatasets(
                assessment: "q3p7-s9p9", // Property Information: https://data.edmonton.ca/d/q3p7-s9p9
                permits: nil,            // TODO Socrata: Building Permits.
                vacantOrders: nil,
                speedLimits: nil,        // TODO Socrata: Speed Limits.
                potholes: nil,
                trees: nil,              // TODO Socrata: Trees Inventory.
                shortTermRentals: nil,
                emergencyCalls: nil,
                naloxone: nil,
                substanceUse: nil
            )
        )
    }
}

final class VancouverProvider: ComingSoonProvider {
    init() {
        super.init(
            cityID: "vancouver",
            displayName: "Vancouver, BC",
            attribution: "City of Vancouver Open Data Licence.",
            datasets: CityDatasets(
                assessment: nil,          // TODO CKAN: Property Tax Report.
                permits: nil,             // TODO CKAN: Issued Building Permits.
                vacantOrders: nil,
                speedLimits: nil,
                potholes: nil,
                trees: nil,               // TODO CKAN: Street Trees.
                shortTermRentals: nil,
                emergencyCalls: nil,
                naloxone: nil,
                substanceUse: nil
            )
        )
    }
}

final class OttawaProvider: ComingSoonProvider {
    init() {
        super.init(
            cityID: "ottawa",
            displayName: "Ottawa, ON",
            attribution: "Open Ottawa Licence.",
            datasets: CityDatasets(
                assessment: nil,          // TODO CKAN: MPAC tax records through City endpoints.
                permits: nil,             // TODO CKAN: Building Permits.
                vacantOrders: nil,
                speedLimits: nil,
                potholes: nil,
                trees: nil,               // TODO CKAN: Tree Inventory.
                shortTermRentals: nil,
                emergencyCalls: nil,
                naloxone: nil,
                substanceUse: nil
            )
        )
    }
}
