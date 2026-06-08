import CoreLocation
import Foundation
import MapKit

final class WinnipegProvider: SocrataProvider, CityDataProvider {
    private static var policeCrimeCSVCache: String?

    let cityID = "winnipeg"
    let displayName = "Winnipeg, MB"
    let attribution = "Contains information licensed under the Open Government Licence - Winnipeg."
    let datasets = CityDatasets(
        assessment: "d4mq-wa44",
        permits: "it4w-cpf4",
        vacantOrders: "qe3f-4r3j",
        speedLimits: "j5wn-5wz7",
        potholes: "4mat-mb3w",
        trees: "hfwk-jp4h",
        shortTermRentals: "74hr-f8ai",
        emergencyCalls: "yg42-q284",
        naloxone: "qd6b-q49i",
        substanceUse: "6x82-bz5y",
        tradePermits: "urbd-qygv",
        parkAssets: "dk7c-zxyd",
        parksOpenSpace: "tx3d-pfxq",
        transitOnTime: "gp3k-am4u",
        transitPassUps: "mer2-irmb",
        transitPassengerActivity: "bv6q-du26",
        bylawInvestigations: "eye3-guud",
        developmentPermits: "w842-cdeb",
        developmentPermitProcessingTimes: "3ij3-3hnj",
        developmentPermitIntake: "jman-p4ya",
        riverWaterLevels: "tgrf-v2zc",
        libraries: "bt47-pkkm",
        neighbourhoods: "8k6x-xxsy",
        serviceRequests: "u7f6-5326",
        zoningParcels: "dxrp-w6re",
        publicNotices: "gnxp-9hpt",
        accessibilityDisruptions: "fxq5-ign2",
        laneClosures: "h367-iifg",
        pavementCondition: "enpg-8cug",
        schoolSpeedLimits: "k56t-9dvi",
        cyclingNetwork: "kjd9-dvf5",
        policeCrimeMaps: "d920a305d0024913a64e61ee1ef1d2a3"
    )
    let fieldMappings = FieldMappings(
        assessment: [
            "streetNumber": "street_number",
            "streetName": "street_name",
            "fullAddress": "full_address",
            "neighbourhood": "neighbourhood_area",
            "assessedValue": "total_assessed_value"
        ],
        permits: [
            "neighbourhood": "neighbourhood_name",
            "streetName": "street_name"
        ]
    )
    let addressNormalizer: AddressNormalizer = WinnipegAddressNormalizer()
    let boundingBox = MKMapRect.world
    let implementationState: ProviderImplementationState = .live

    init() {
        super.init(domain: "data.winnipeg.ca")
    }

    func fetchDossier(for address: NormalizedAddress) async -> AddressDossier {
        await fetchDossier(for: address, progress: nil)
    }

    func fetchDossier(for address: NormalizedAddress, progress: DossierService.ProgressHandler?) async -> AddressDossier {
        await progress?(.assessment)
        async let property = fetchAssessment(address)
        async let infrastructure = fetchInfrastructure(address)

        let assessment = await property
        await progress?(.nearbyRecords)
        let nearbyStreetCores = await fetchNearbyStreetCores(address: address, property: assessment)
        await progress?(.permits)
        async let permitsRaw = fetchPermits(address, streetCores: nearbyStreetCores)
        async let vacantOrdersRaw = fetchVacantOrders(address, streetCores: nearbyStreetCores)
        async let values = fetchNeighbourhoodValues(neighbourhood: assessment?.neighbourhood)
        async let comparables = fetchComparables(address: address, property: assessment)
        async let permitActivity = fetchPermitActivity(neighbourhood: assessment?.neighbourhood)
        async let parks = fetchParks(property: assessment)
        async let transit = fetchTransit(property: assessment)
        async let bylaw = fetchBylaw(neighbourhood: assessment?.neighbourhood)
        async let development = fetchDevelopmentContext(address: address, streetCores: nearbyStreetCores)
        async let river = fetchRiverGauge(property: assessment)
        async let library = fetchLibrary(property: assessment)
        async let serviceRequests = fetchServiceRequests(neighbourhood: assessment?.neighbourhood)
        async let planning = fetchPlanningContext(property: assessment)
        async let streetAccess = fetchStreetAccess(address: address, property: assessment)
        await progress?(.emergency)
        async let emergency = fetchEmergency(neighbourhood: assessment?.neighbourhood)
        await progress?(.health)
        async let health = fetchPublicHealth(neighbourhood: assessment?.neighbourhood)
        async let policeCrime = fetchPoliceCrime(neighbourhood: assessment?.neighbourhood)

        await progress?(.infrastructure)
        let infrastructureSummary = await infrastructure
        await progress?(.mapCoordinates)
        let permits = await geocodePermits(await permitsRaw)
        let vacantOrders = await geocodeVacantOrders(await vacantOrdersRaw, subject: assessment?.coordinate)
        await progress?(.comparables)

        let neighbourhoodValues = await values
        let comparableProperties = await comparables
        let permitActivitySummary = await permitActivity
        let parksSummary = await parks
        let transitSummary = await transit
        let bylawSummary = await bylaw
        let developmentSummary = await development
        let riverSummary = await river
        let librarySummary = await library
        let serviceRequestSummary = await serviceRequests
        let planningSummary = await planning
        let streetAccessSummary = await streetAccess
        let emergencySummary = await emergency
        let publicHealthSummary = await health
        let policeCrimeSummary = await policeCrime

        await progress?(.assembling)

        return AddressDossier(
            address: address,
            providerID: cityID,
            cityName: displayName,
            providerState: .live,
            property: assessment,
            neighbourhoodValues: neighbourhoodValues,
            comparables: comparableProperties,
            permits: permits,
            permitActivity: permitActivitySummary,
            vacantOrders: vacantOrders,
            infrastructure: infrastructureSummary,
            parks: parksSummary,
            transit: transitSummary,
            bylaw: bylawSummary,
            development: developmentSummary,
            river: riverSummary,
            library: librarySummary,
            serviceRequests: serviceRequestSummary,
            planning: planningSummary,
            streetAccess: streetAccessSummary,
            emergency: emergencySummary,
            publicHealth: publicHealthSummary,
            policeCrime: policeCrimeSummary,
            sources: sourceList()
        )
    }

    private func geocodePermits(_ permits: [BuildingPermit]) async -> [BuildingPermit] {
        guard !permits.isEmpty else { return permits }
        let lookup = await geocode(addresses: permits.map(\.address))
        return permits.map { p in
            var copy = p
            if copy.coordinate == nil { copy.coordinate = lookup[geocodeKey(for: p.address)] }
            return copy
        }
    }

    private func geocodeVacantOrders(_ orders: [VacantOrder], subject: CLLocationCoordinate2D?) async -> [VacantOrder] {
        guard !orders.isEmpty else { return orders }
        let lookup = await geocode(addresses: orders.map(\.address))
        return orders.map { o in
            var copy = o
            if copy.coordinate == nil { copy.coordinate = lookup[geocodeKey(for: o.address)] }
            if let subject, let coordinate = copy.coordinate {
                copy.distanceDescription = distanceDescription(from: subject, to: coordinate)
            }
            return copy
        }
    }

    private func geocodeKey(for address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return trimmed.uppercased() }
        let num = String(parts[0])
        let street = streetCore(String(parts[1]))
        return "\(num) \(street)"
    }

    private func geocode(addresses: [String]) async -> [String: CLLocationCoordinate2D] {
        guard let dataset = datasets.assessment else { return [:] }
        var byStreet: [String: Set<String>] = [:]
        for raw in addresses {
            let parts = raw.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, Int(parts[0]) != nil else { continue }
            let num = String(parts[0])
            let street = streetCore(String(parts[1]))
            guard !street.isEmpty else { continue }
            byStreet[street, default: []].insert(num)
        }
        var result: [String: CLLocationCoordinate2D] = [:]
        await withTaskGroup(of: [(String, CLLocationCoordinate2D)].self) { group in
            for (street, nums) in byStreet {
                let numList = Array(nums).prefix(80).map { "'\($0)'" }.joined(separator: ",")
                let token = escaped(street)
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    let rows = (try? await self.fetch(dataset, queryItems: [
                        URLQueryItem(name: "$select", value: "street_number,centroid_lat,centroid_lon,geometry"),
                        URLQueryItem(name: "$where", value: "upper(street_name)='\(token)' AND street_number in (\(numList))"),
                        URLQueryItem(name: "$limit", value: "200")
                    ])) ?? []
                    var pairs: [(String, CLLocationCoordinate2D)] = []
                    for row in rows {
                        guard let coord = self.parseCoordinate(row),
                              let num = row.string("street_number") else { continue }
                        pairs.append(("\(num) \(street)", coord))
                    }
                    return pairs
                }
            }
            for await pairs in group {
                for (key, coord) in pairs where result[key] == nil { result[key] = coord }
            }
        }
        return result
    }

    private func fetchNearbyStreetCores(address: NormalizedAddress, property: PropertyAssessment?, radiusMeters: Double = 1000) async -> [String] {
        var cores = Set(addressNormalizer.streetVariants(for: address).map(streetCore).filter { !$0.isEmpty })
        guard let dataset = datasets.assessment,
              let property,
              let subject = property.coordinate else {
            return Array(cores).sorted()
        }

        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "street_name,centroid_lat,centroid_lon,geometry"),
            URLQueryItem(name: "$where", value: "neighbourhood_area='\(escaped(property.neighbourhood))' AND street_name IS NOT NULL"),
            URLQueryItem(name: "$limit", value: "2000")
        ])) ?? []

        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        for row in rows {
            guard let street = row.string("street_name"),
                  let coordinate = parseCoordinate(row) else { continue }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            if distance <= radiusMeters {
                let core = streetCore(street)
                if !core.isEmpty { cores.insert(core) }
            }
        }

        return Array(cores).sorted()
    }

    private func sourceList() -> [DatasetSource] {
        let sourcePairs: [(String, String?)] = [
            ("Assessment Parcels", datasets.assessment),
            ("Detailed Building Permits", datasets.permits),
            ("Active Vacant Building Orders", datasets.vacantOrders),
            ("LRS Speed Limits", datasets.speedLimits),
            ("Pothole Repairs", datasets.potholes),
            ("Tree Inventory", datasets.trees),
            ("Short Term Rental Accommodations", datasets.shortTermRentals),
            ("WFPS Call Logs", datasets.emergencyCalls),
            ("Naloxone Administrations", datasets.naloxone),
            ("Substance Use", datasets.substanceUse),
            ("Trade Permits", datasets.tradePermits),
            ("Park Asset Inventory", datasets.parkAssets),
            ("Parks and Open Space", datasets.parksOpenSpace),
            ("Recent Transit On-Time Performance", datasets.transitOnTime),
            ("Transit Pass-ups", datasets.transitPassUps),
            ("Estimated Daily Passenger Activity", datasets.transitPassengerActivity),
            ("By-Law Investigations", datasets.bylawInvestigations),
            ("Detailed Development Permit Data", datasets.developmentPermits),
            ("Development Permit Processing Times", datasets.developmentPermitProcessingTimes),
            ("Development Permit Intake", datasets.developmentPermitIntake),
            ("River Water Levels", datasets.riverWaterLevels),
            ("Library", datasets.libraries),
            ("Neighbourhoods", datasets.neighbourhoods),
            ("311 Requests", datasets.serviceRequests),
            ("Zoning By-law Parcels", datasets.zoningParcels),
            ("Public Notices", datasets.publicNotices),
            ("Accessibility Disruptions", datasets.accessibilityDisruptions),
            ("Lane Closure", datasets.laneClosures),
            ("Street Pavement Surface Condition Data", datasets.pavementCondition),
            ("LRS School Speed Limits", datasets.schoolSpeedLimits),
            ("Cycling Network", datasets.cyclingNetwork)
        ]
        let citySources: [DatasetSource] = sourcePairs.compactMap { pair -> DatasetSource? in
            let (name, id) = pair
            guard let id, let url = try? resourceURL(id) else { return nil }
            return DatasetSource(name: name, datasetID: id, url: url)
        }

        let policeSource = DatasetSource(
            name: "WPS Crime Maps Public Data",
            datasetID: datasets.policeCrimeMaps ?? "d920a305d0024913a64e61ee1ef1d2a3",
            url: URL(string: "https://www.arcgis.com/home/item.html?id=d920a305d0024913a64e61ee1ef1d2a3")!
        )
        return citySources + [policeSource]
    }

    private func fetchAssessment(_ address: NormalizedAddress) async -> PropertyAssessment? {
        guard let dataset = datasets.assessment else { return nil }
        let streetClauses = addressNormalizer.streetVariants(for: address)
            .map { "upper(street_name)='\(escaped($0.uppercased()))'" }
            .joined(separator: " OR ")
        var clauses: [String] = []
        if let civic = address.civicNumber {
            clauses.append("street_number='\(civic)'")
        }
        if !streetClauses.isEmpty {
            clauses.append("(\(streetClauses))")
        }
        if clauses.isEmpty { return nil }
        var rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: clauses.joined(separator: " AND ")),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        if rows.isEmpty {
            let streetOnly = address.streetName
                .replacingOccurrences(of: #"(?i)\b(avenue|ave|av|street|st|road|rd|drive|dr|boulevard|blvd|crescent|cres|place|pl|way)\b"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if !streetOnly.isEmpty {
                let likeClause = "upper(full_address) like '%\(escaped(streetOnly))%'"
                let fallback = address.civicNumber.map { "street_number='\($0)' AND \(likeClause)" } ?? likeClause
                rows = (try? await fetch(dataset, queryItems: [
                    URLQueryItem(name: "$where", value: fallback),
                    URLQueryItem(name: "$limit", value: "1")
                ])) ?? []
            }
        }
        guard let row = rows.first else { return nil }
        let attached = row.string("attached_garage")
        let detached = row.string("detached_garage")
        let garage: String?
        switch (attached?.lowercased(), detached?.lowercased()) {
        case ("yes", "yes"): garage = "Attached + Detached"
        case ("yes", _): garage = "Attached"
        case (_, "yes"): garage = "Detached"
        case ("no", "no"): garage = "No"
        default: garage = row.string("garage")
        }
        let directPropertyTax = propertyTax(from: row)
        let estimatedPropertyTax = directPropertyTax == nil ? estimatedPropertyTax(from: row) : nil

        return PropertyAssessment(
            fullAddress: row.string("full_address") ?? address.raw,
            neighbourhood: row.string("neighbourhood_area") ?? "Unknown",
            useCode: row.string("property_use_code"),
            totalAssessedValue: row.double("total_assessed_value"),
            propertyTax: directPropertyTax ?? estimatedPropertyTax,
            propertyTaxIsEstimated: directPropertyTax == nil && estimatedPropertyTax != nil,
            livingArea: row.double("total_living_area"),
            landArea: row.double("assessed_land_area") ?? row.double("land_area_in_sq_feet"),
            yearBuilt: row.int("year_built"),
            rooms: row.string("rooms"),
            basement: row.string("basement"),
            garage: garage,
            airConditioning: row.string("air_conditioning"),
            fireplace: row.string("fire_place") ?? row.string("fireplace"),
            swimmingPool: row.string("pool") ?? row.string("swimming_pool"),
            zoning: row.string("zoning"),
            rollNumber: row.string("roll_number"),
            houseStyle: row.string("building_type") ?? row.string("house_style"),
            storeys: nil,
            coordinate: parseCoordinate(row)
        )
    }

    private func propertyTax(from row: [String: Any]) -> Double? {
        [
            "property_tax",
            "property_taxes",
            "annual_property_tax",
            "tax_amount",
            "taxes",
            "total_taxes",
            "gross_taxes",
            "gross_property_tax",
            "municipal_taxes",
            "net_property_tax"
        ].lazy.compactMap { row.double($0) }.first
    }

    private func estimatedPropertyTax(from row: [String: Any]) -> Double? {
        guard
            let assessedValue = row.double("total_assessed_value"),
            assessedValue > 0,
            isTaxableResidential(row)
        else { return nil }

        // The assessment feed does not expose school division, so use the average
        // 2026 residential combined mill rate across Winnipeg school divisions.
        let residentialPortion = 0.45
        let averageCombinedResidentialMillRate = 27.405
        return assessedValue * residentialPortion * averageCombinedResidentialMillRate / 1_000
    }

    private func isTaxableResidential(_ row: [String: Any]) -> Bool {
        let classFields = [
            row.string("property_class_1"),
            row.string("proposed_property_class_1"),
            row.string("property_use_code")
        ]
        let statusFields = [
            row.string("status_1"),
            row.string("proposed_status_1")
        ]

        let isResidential = classFields.contains { value in
            value?.localizedCaseInsensitiveContains("residential") == true ||
            value?.localizedCaseInsensitiveContains("ressd") == true
        }
        let isTaxable = statusFields.contains { value in
            value?.localizedCaseInsensitiveContains("taxable") == true
        }
        return isResidential && isTaxable
    }

    private func fetchNeighbourhoodValues(neighbourhood: String?) async -> [AssessmentValueBin] {
        guard let dataset = datasets.assessment, let neighbourhood else { return [] }
        let select = "floor(total_assessed_value / 50000) * 50000 as bucket, count(*) as cnt"
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: select),
            URLQueryItem(name: "$where", value: "neighbourhood_area='\(escaped(neighbourhood))' AND total_assessed_value IS NOT NULL"),
            URLQueryItem(name: "$group", value: "bucket"),
            URLQueryItem(name: "$order", value: "bucket"),
            URLQueryItem(name: "$limit", value: "24")
        ])) ?? []
        return rows.compactMap { row in
            guard let midpoint = row.double("bucket"), let count = row.int("cnt") else { return nil }
            return AssessmentValueBin(bucket: currency(midpoint), count: count, midpoint: midpoint)
        }
    }

    private func fetchComparables(address: NormalizedAddress, property: PropertyAssessment?) async -> [ComparableProperty] {
        guard let dataset = datasets.assessment, let property else { return [] }
        var clauses = ["neighbourhood_area='\(escaped(property.neighbourhood))'"]
        if let area = property.livingArea {
            clauses.append("total_living_area between \(Int(area * 0.8)) and \(Int(area * 1.2))")
        }
        if let year = property.yearBuilt {
            clauses.append("year_built between \(year - 10) and \(year + 10)")
        }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "full_address,total_assessed_value,total_living_area,year_built"),
            URLQueryItem(name: "$where", value: clauses.joined(separator: " AND ")),
            URLQueryItem(name: "$limit", value: "40")
        ])) ?? []
        return rows.compactMap { row in
            guard let address = row.string("full_address"),
                  let value = row.double("total_assessed_value"),
                  let area = row.double("total_living_area") else { return nil }
            return ComparableProperty(address: address, value: value, livingArea: area, yearBuilt: row.int("year_built"))
        }
    }

    private func fetchPermits(_ address: NormalizedAddress, streetCores: [String]) async -> [BuildingPermit] {
        guard let dataset = datasets.permits else { return [] }
        let nearbyCores = limitedStreetCores(streetCores)
        let streetClauses = nearbyCores
            .map { "upper(street_name)='\(escaped($0))'" }
            .joined(separator: " OR ")
        guard !streetClauses.isEmpty else { return [] }
        let whereClause = "(\(streetClauses)) AND issue_date > '\(yearOffset(-2))-01-01T00:00:00'"
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: whereClause),
            URLQueryItem(name: "$order", value: "issue_date DESC"),
            URLQueryItem(name: "$limit", value: "50")
        ])) ?? []
        return rows.map { row in
            let permitAddress = row.string("address") ?? ""
            let structural = ["foundation", "structural"].contains { (row.string("work_type") ?? "").lowercased().contains($0) }
            let adjacent = isAdjacent(permitAddress: permitAddress, to: address.civicNumber)
            return BuildingPermit(
                issuedDate: parseDate(row.string("issue_date")),
                type: row.string("permit_type") ?? "Permit",
                subType: row.string("sub_type"),
                workType: row.string("work_type"),
                address: permitAddress,
                status: row.string("status"),
                isAdjacentStructural: structural && adjacent,
                coordinate: parseCoordinate(row)
            )
        }
    }

    private func fetchPermitActivity(neighbourhood: String?) async -> [YearCount] {
        guard let dataset = datasets.permits, let neighbourhood else { return [] }
        let neighUpper = escaped(neighbourhood.uppercased())
        let neighClause = "(upper(neighbourhood_name)='\(neighUpper)' OR upper(neighbourhood)='\(neighUpper)' OR upper(neighborhood_name)='\(neighUpper)')"
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(issue_date) as year, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(neighClause) AND issue_date >= '\(yearOffset(-6))-01-01T00:00:00'"),
            URLQueryItem(name: "$group", value: "year"),
            URLQueryItem(name: "$order", value: "year")
        ])) ?? []
        return rows.compactMap { row in
            guard let year = row.int("year"), let count = row.int("cnt") else { return nil }
            return YearCount(year: year, count: count)
        }
    }

    private func fetchVacantOrders(_ address: NormalizedAddress, streetCores: [String]) async -> [VacantOrder] {
        guard let dataset = datasets.vacantOrders else { return [] }
        let nearbyCores = limitedStreetCores(streetCores)
        let streetClauses = nearbyCores
            .map { "upper(address) like '%\(escaped($0))%'" }
            .joined(separator: " OR ")
        guard !streetClauses.isEmpty else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: "(\(streetClauses))"),
            URLQueryItem(name: "$order", value: "order_issued_date DESC"),
            URLQueryItem(name: "$limit", value: "40")
        ])) ?? []
        return rows.map {
            VacantOrder(
                issuedDate: parseDate($0.string("order_issued_date")),
                address: $0.string("address") ?? "Address unavailable",
                orderType: $0.string("order_type") ?? "Compliance order",
                distanceDescription: nil,
                coordinate: parseCoordinate($0)
            )
        }
    }

    private func fetchInfrastructure(_ address: NormalizedAddress) async -> InfrastructureSummary {
        async let speed = fetchSpeedLimit(address)
        async let potholes = fetchPotholes(address)
        async let trees = fetchTrees(address)
        let treeCounts = await trees
        return InfrastructureSummary(
            speedLimit: await speed,
            potholes: await potholes,
            publicTrees: treeCounts.public,
            taggedTrees: treeCounts.tagged
        )
    }

    private func limitedStreetCores(_ cores: [String], limit: Int = 18) -> [String] {
        Array(Array(Set(cores.filter { !$0.isEmpty })).sorted().prefix(limit))
    }

    private func fetchSpeedLimit(_ address: NormalizedAddress) async -> String? {
        guard let dataset = datasets.speedLimits else { return nil }
        let token = escaped(streetCore(address.streetName))
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: "upper(street_name) like '\(token)%'"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first else { return nil }
        if let raw = row.string("speed_limit") { return "\(raw) km/h" }
        if let desc = row.string("speed_limit_description") { return desc }
        return nil
    }

    private func fetchPotholes(_ address: NormalizedAddress) async -> Int {
        guard let dataset = datasets.potholes else { return 0 }
        let token = escaped(streetCore(address.streetName))
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "sum(potholes) as cnt"),
            URLQueryItem(name: "$where", value: "upper(street_name) like '\(token)%'")
        ])) ?? []
        return Int(rows.first?.double("cnt") ?? 0)
    }

    private func streetCore(_ name: String) -> String {
        name.replacingOccurrences(of: #"(?i)\s+(avenue|ave|av|street|st|road|rd|drive|dr|boulevard|blvd|crescent|cres|place|pl|way|bay|bv)\.?$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func fetchTrees(_ address: NormalizedAddress) async -> (public: Int, tagged: Int) {
        guard let dataset = datasets.trees else { return (0, 0) }
        let streetClause = "upper(street) like '\(escaped(streetCore(address.streetName)))%'"
        let total = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt"),
            URLQueryItem(name: "$where", value: streetClause)
        ])) ?? []
        let tagged = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(streetClause) AND ded_tag_number IS NOT NULL")
        ])) ?? []
        return (total.first?.int("cnt") ?? 0, tagged.first?.int("cnt") ?? 0)
    }

    private func fetchParks(property: PropertyAssessment?) async -> ParksSummary? {
        guard let property else { return nil }
        async let nearby = fetchNearbyParks(property: property)
        async let neighbourhood = fetchNeighbourhoodParks(neighbourhood: property.neighbourhood)
        let nearbyParks = await nearby
        let nearestPark = nearbyParks.first
        let neighbourhoodStats = await neighbourhood
        if nearestPark == nil && neighbourhoodStats.count == 0 { return nil }
        return ParksSummary(
            nearestPark: nearestPark,
            nearbyParks: nearbyParks,
            neighbourhoodParkCount: neighbourhoodStats.count,
            neighbourhoodHectares: neighbourhoodStats.hectares
        )
    }

    private func fetchNearbyParks(property: PropertyAssessment, limit: Int = 20) async -> [ParkAmenity] {
        guard let dataset = datasets.parkAssets,
              let subject = property.coordinate else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "park_id,park_name,asset_class,asset_type,point"),
            URLQueryItem(name: "$where", value: "within_circle(point,\(subject.latitude),\(subject.longitude),500)"),
            URLQueryItem(name: "$limit", value: "500")
        ])) ?? []
        struct ParkAccumulator {
            var parkID: String
            var name: String
            var distance: Double
            var coordinate: CLLocationCoordinate2D?
            var playgrounds = 0
            var fields = 0
            var courts = 0
            var washrooms = 0
            var benches = 0
        }
        var parksByID: [String: ParkAccumulator] = [:]
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        for row in rows {
            guard let parkID = row.string("park_id"),
                  let name = row.string("park_name"),
                  let coordinate = parseCoordinate(row) else { continue }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            var item = parksByID[parkID] ?? ParkAccumulator(parkID: parkID, name: name, distance: distance, coordinate: coordinate)
            if distance < item.distance {
                item.distance = distance
                item.coordinate = coordinate
            }
            let tokens = [row.string("asset_class"), row.string("asset_type")].compactMap { $0?.lowercased() }.joined(separator: " ")
            if tokens.contains("play") { item.playgrounds += 1 }
            if tokens.contains("field") || tokens.contains("diamond") || tokens.contains("soccer") { item.fields += 1 }
            if tokens.contains("court") || tokens.contains("tennis") || tokens.contains("basketball") { item.courts += 1 }
            if tokens.contains("washroom") || tokens.contains("toilet") { item.washrooms += 1 }
            if tokens.contains("bench") { item.benches += 1 }
            parksByID[parkID] = item
        }
        return parksByID.values
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { park in
                ParkAmenity(
                    parkID: park.parkID,
                    name: park.name,
                    distanceDescription: distanceDescription(meters: park.distance),
                    coordinate: park.coordinate,
                    playgrounds: park.playgrounds,
                    fields: park.fields,
                    courts: park.courts,
                    washrooms: park.washrooms,
                    benches: park.benches
                )
            }
    }

    private func fetchNeighbourhoodParks(neighbourhood: String) async -> (count: Int, hectares: Double?) {
        guard let dataset = datasets.parksOpenSpace else { return (0, nil) }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt, sum(total_area_in_hectares) as hectares"),
            URLQueryItem(name: "$where", value: "upper(neighbourhood)='\(escaped(neighbourhood.uppercased()))'")
        ])) ?? []
        return (rows.first?.int("cnt") ?? 0, rows.first?.double("hectares"))
    }

    private func fetchTransit(property: PropertyAssessment?) async -> TransitAccessSummary? {
        guard let subject = property?.coordinate,
              let onTimeDataset = datasets.transitOnTime else { return nil }
        let nearbyRows = (try? await fetch(onTimeDataset, queryItems: [
            URLQueryItem(name: "$select", value: "stop_number,route_number,route_name,deviation,location"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),700)"),
            URLQueryItem(name: "$limit", value: "800")
        ])) ?? []
        guard !nearbyRows.isEmpty else { return nil }

        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        var nearestStop: (stop: String, distance: Double)?
        var routesByNumber: [String: TransitRouteSummary] = [:]
        var deviations: [Double] = []
        var onTimeCount = 0
        var stopNumbers = Set<String>()

        for row in nearbyRows {
            if let stop = row.string("stop_number") {
                stopNumbers.insert(stop)
                if let coordinate = parseCoordinate(row) {
                    let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
                    if nearestStop == nil || distance < nearestStop!.distance {
                        nearestStop = (stop, distance)
                    }
                }
            }
            if let route = row.string("route_number") {
                routesByNumber[route] = TransitRouteSummary(routeNumber: route, routeName: row.string("route_name") ?? "Route \(route)")
            }
            if let deviation = row.double("deviation") {
                deviations.append(deviation)
                if deviation >= -180 && deviation <= 60 { onTimeCount += 1 }
            }
        }

        let nearbyStopNumbers = Array(stopNumbers)
        async let passUps = fetchTransitPassUps(subject: subject)
        async let passengerActivity = fetchPassengerActivity(stopNumbers: nearbyStopNumbers)
        let averageDeviation = deviations.isEmpty ? nil : deviations.reduce(0, +) / Double(deviations.count)
        let onTimePercent = deviations.isEmpty ? nil : Double(onTimeCount) / Double(deviations.count) * 100

        return TransitAccessSummary(
            nearestStop: nearestStop.map { TransitStop(stopNumber: $0.stop, distanceDescription: distanceDescription(meters: $0.distance)) },
            routes: routesByNumber.values.sorted { $0.routeNumber.localizedStandardCompare($1.routeNumber) == .orderedAscending },
            averageDeviationSeconds: averageDeviation,
            onTimePercentage: onTimePercent,
            passUpsLastYear: await passUps,
            averageDailyBoardings: await passengerActivity
        )
    }

    private func fetchTransitPassUps(subject: CLLocationCoordinate2D) async -> Int {
        guard let dataset = datasets.transitPassUps else { return 0 }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),700) AND time >= '\(yearOffset(-1))-01-01T00:00:00'")
        ])) ?? []
        return rows.first?.int("cnt") ?? 0
    }

    private func fetchPassengerActivity(stopNumbers: [String]) async -> Double? {
        guard let dataset = datasets.transitPassengerActivity else { return nil }
        let stops = Array(stopNumbers.prefix(12))
        guard !stops.isEmpty else { return nil }
        let stopList = stops.map { "'\(escaped($0))'" }.joined(separator: ",")
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "sum(average_boardings) as boardings"),
            URLQueryItem(name: "$where", value: "stop_number in (\(stopList)) AND day_type='Weekday'")
        ])) ?? []
        return rows.first?.double("boardings")
    }

    private func fetchBylaw(neighbourhood: String?) async -> BylawInvestigationSummary? {
        guard let neighbourhood,
              let dataset = datasets.bylawInvestigations,
              let neighbourhoodID = await fetchNeighbourhoodID(named: neighbourhood) else { return nil }
        let yearly = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(indate) as year, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "nbhd_number='\(neighbourhoodID)' AND indate >= '\(yearOffset(-6))-01-01T00:00:00'"),
            URLQueryItem(name: "$group", value: "year"),
            URLQueryItem(name: "$order", value: "year")
        ])) ?? []
        let types = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "complaint_type_1, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "nbhd_number='\(neighbourhoodID)' AND indate >= '\(yearOffset(-1))-01-01T00:00:00' AND complaint_type_1 IS NOT NULL"),
            URLQueryItem(name: "$group", value: "complaint_type_1"),
            URLQueryItem(name: "$order", value: "cnt DESC"),
            URLQueryItem(name: "$limit", value: "6")
        ])) ?? []
        let summary = BylawInvestigationSummary(
            neighbourhood: neighbourhood,
            yearly: yearly.compactMap { row in
                guard let year = row.int("year"), let count = row.int("cnt") else { return nil }
                return YearCount(year: year, count: count)
            },
            complaintTypes: types.compactMap { row in
                guard let type = row.string("complaint_type_1"), let count = row.int("cnt") else { return nil }
                return IncidentBreakdown(incidentType: type, count: count)
            }
        )
        if summary.yearly.isEmpty && summary.complaintTypes.isEmpty { return nil }
        return summary
    }

    private func fetchNeighbourhoodID(named neighbourhood: String) async -> String? {
        guard let dataset = datasets.neighbourhoods else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "id,name"),
            URLQueryItem(name: "$where", value: "upper(name)='\(escaped(neighbourhood.uppercased()))'"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        return rows.first?.string("id")
    }

    private func fetchDevelopmentContext(address: NormalizedAddress, streetCores: [String]) async -> DevelopmentContextSummary? {
        async let permits = fetchDevelopmentPermits(address: address, streetCores: streetCores)
        async let review = fetchDevelopmentProcessingTimes()
        async let intake = fetchDevelopmentIntake()
        let summary = DevelopmentContextSummary(recentPermits: await permits, reviewProcessing: await review, intake: await intake)
        if summary.recentPermits.isEmpty && summary.reviewProcessing.isEmpty && summary.intake.isEmpty { return nil }
        return summary
    }

    private func fetchDevelopmentPermits(address: NormalizedAddress, streetCores: [String]) async -> [DevelopmentPermit] {
        guard let dataset = datasets.developmentPermits else { return [] }
        let nearbyCores = limitedStreetCores(streetCores)
        let streetClauses = nearbyCores.map { "upper(street_name)='\(escaped($0))'" }.joined(separator: " OR ")
        guard !streetClauses.isEmpty else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: "(\(streetClauses)) AND issue_date > '\(yearOffset(-2))-01-01T00:00:00'"),
            URLQueryItem(name: "$order", value: "issue_date DESC"),
            URLQueryItem(name: "$limit", value: "30")
        ])) ?? []
        return rows.map { row in
            let addressParts = [
                row.string("street_number"),
                row.string("street_name"),
                row.string("street_type")
            ].compactMap { $0 }
            return DevelopmentPermit(
                issuedDate: parseDate(row.string("issue_date")),
                permitNumber: row.string("permit_number"),
                type: row.string("permit_type") ?? row.string("permit_group") ?? "Development permit",
                subType: row.string("sub_type"),
                workType: row.string("work_type"),
                address: addressParts.isEmpty ? address.raw : addressParts.joined(separator: " "),
                status: row.string("status"),
                coordinate: parseCoordinate(row)
            )
        }
    }

    private func fetchDevelopmentProcessingTimes() async -> [PermitProcessingMetric] {
        guard let dataset = datasets.developmentPermitProcessingTimes else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$order", value: "month DESC"),
            URLQueryItem(name: "$limit", value: "4")
        ])) ?? []
        return rows.compactMap { row in
            guard let description = row.string("description"),
                  let average = row.double("average_number_of_business_days") else { return nil }
            return PermitProcessingMetric(
                description: description,
                month: parseDate(row.string("month")),
                averageBusinessDays: average,
                serviceStandardDays: row.double("city_service_level_standard"),
                percentMetTarget: row.double("city_percent_met_target")
            )
        }
    }

    private func fetchDevelopmentIntake() async -> [PermitIntakeMetric] {
        guard let dataset = datasets.developmentPermitIntake else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$order", value: "month DESC"),
            URLQueryItem(name: "$limit", value: "4")
        ])) ?? []
        return rows.compactMap { row in
            guard let description = row.string("description"),
                  let approved = row.int("number_approved"),
                  let notApproved = row.int("number_not_approved") else { return nil }
            return PermitIntakeMetric(
                description: description,
                month: parseDate(row.string("month")),
                approved: approved,
                notApproved: notApproved
            )
        }
    }

    private func fetchRiverGauge(property: PropertyAssessment?) async -> RiverGaugeSummary? {
        guard let dataset = datasets.riverWaterLevels,
              let subject = property?.coordinate else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "river_name,location,james_feet,geodetic_feet,geodetic_metric,reading_date,notes,coordinate"),
            URLQueryItem(name: "$where", value: "within_circle(coordinate,\(subject.latitude),\(subject.longitude),7000)"),
            URLQueryItem(name: "$limit", value: "60")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        let nearest = rows.compactMap { row -> (row: [String: Any], distance: Double)? in
            guard let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            return (row, distance)
        }.min { $0.distance < $1.distance }
        guard let nearest else { return nil }
        let gaugeCoordinate = parseCoordinate(nearest.row)
        return RiverGaugeSummary(
            riverName: nearest.row.string("river_name") ?? "River",
            location: nearest.row.string("location") ?? "Gauge",
            distanceDescription: distanceDescription(meters: nearest.distance),
            jamesFeet: nearest.row.double("james_feet"),
            geodeticFeet: nearest.row.double("geodetic_feet"),
            geodeticMetric: nearest.row.double("geodetic_metric"),
            readingDate: parseDate(nearest.row.string("reading_date")),
            notes: nearest.row.string("notes"),
            coordinate: gaugeCoordinate
        )
    }

    private func fetchLibrary(property: PropertyAssessment?) async -> LibraryAmenity? {
        guard let dataset = datasets.libraries,
              let subject = property?.coordinate else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "name,address,wifi,accessibilty,room_rentals,parking_lot,parkng_stalls,notes,point"),
            URLQueryItem(name: "$where", value: "within_circle(point,\(subject.latitude),\(subject.longitude),7000)"),
            URLQueryItem(name: "$limit", value: "30")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        let nearest = rows.compactMap { row -> (row: [String: Any], distance: Double)? in
            guard let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            return (row, distance)
        }.min { $0.distance < $1.distance }
        guard let nearest else { return nil }
        let libraryCoordinate = parseCoordinate(nearest.row)
        return LibraryAmenity(
            name: nearest.row.string("name") ?? "Library",
            address: nearest.row.string("address") ?? "Address unavailable",
            distanceDescription: distanceDescription(meters: nearest.distance),
            wifi: nearest.row.bool("wifi"),
            accessibility: nearest.row.bool("accessibilty"),
            parkingLot: nearest.row.bool("parking_lot"),
            parkingStalls: nearest.row.int("parkng_stalls"),
            roomRentals: nearest.row.bool("room_rentals"),
            notes: nearest.row.string("notes"),
            coordinate: libraryCoordinate
        )
    }

    private func fetchServiceRequests(neighbourhood: String?) async -> ServiceRequestSummary? {
        guard let dataset = datasets.serviceRequests,
              let neighbourhood else { return nil }
        let whereBase = "\(serviceNeighbourhoodClause(neighbourhood)) AND open_date >= '\(yearOffset(-1))-01-01T00:00:00'"

        async let totalsRaw = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as total"),
            URLQueryItem(name: "$where", value: whereBase)
        ])
        async let openRaw = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as open_count"),
            URLQueryItem(name: "$where", value: "\(whereBase) AND upper(case_status)='OPEN'")
        ])
        async let closedRaw = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as closed_count"),
            URLQueryItem(name: "$where", value: "\(whereBase) AND upper(case_status)='CLOSED'")
        ])
        async let statusesRaw = fetchServiceBreakdown(dataset: dataset, field: "case_status", whereBase: whereBase, limit: 6)
        async let channelsRaw = fetchServiceBreakdown(dataset: dataset, field: "channel_type", whereBase: whereBase, limit: 6)
        async let subjectsRaw = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "subject, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(whereBase) AND subject IS NOT NULL"),
            URLQueryItem(name: "$group", value: "subject"),
            URLQueryItem(name: "$order", value: "cnt DESC"),
            URLQueryItem(name: "$limit", value: "8")
        ])
        async let reasonsRaw = fetchServiceBreakdown(dataset: dataset, field: "reason", whereBase: whereBase, limit: 8)
        async let typesRaw = fetchServiceBreakdown(dataset: dataset, field: "type", whereBase: whereBase, limit: 8)
        async let trendRaw = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(open_date) as year, date_extract_m(open_date) as month, count(*) as cnt"),
            URLQueryItem(name: "$where", value: whereBase),
            URLQueryItem(name: "$group", value: "year, month"),
            URLQueryItem(name: "$order", value: "year, month"),
            URLQueryItem(name: "$limit", value: "18")
        ])
        async let recentRaw = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "case_id,interaction_id,channel_type,subject,reason,type,open_date,closed_date,case_status,ward,geometry"),
            URLQueryItem(name: "$where", value: whereBase),
            URLQueryItem(name: "$order", value: "open_date DESC"),
            URLQueryItem(name: "$limit", value: "12")
        ])

        let totals = (try? await totalsRaw) ?? []
        let openRows = (try? await openRaw) ?? []
        let closedRows = (try? await closedRaw) ?? []
        let statuses = await statusesRaw
        let channels = await channelsRaw
        let subjects = (try? await subjectsRaw) ?? []
        let reasons = await reasonsRaw
        let types = await typesRaw
        let trendRows = (try? await trendRaw) ?? []
        let recentRows = (try? await recentRaw) ?? []
        let total = totals.first?.int("total") ?? 0
        let open = openRows.first?.int("open_count") ?? 0
        let closed = closedRows.first?.int("closed_count") ?? 0
        let breakdown = subjects.compactMap { row -> IncidentBreakdown? in
            guard let subject = row.string("subject"), let count = row.int("cnt") else { return nil }
            return IncidentBreakdown(incidentType: subject, count: count)
        }
        let trend = trendRows.compactMap { row -> ServiceRequestMonth? in
            guard let year = row.int("year"),
                  let month = row.int("month"),
                  let count = row.int("cnt") else { return nil }
            return ServiceRequestMonth(year: year, month: month, count: count)
        }
        let recent = recentRows.map { row in
            ServiceRequestRecord(
                caseID: row.string("case_id"),
                interactionID: row.string("interaction_id"),
                channel: row.string("channel_type"),
                subject: row.string("subject"),
                reason: row.string("reason"),
                type: row.string("type"),
                openDate: parseDate(row.string("open_date")),
                closedDate: parseDate(row.string("closed_date")),
                status: row.string("case_status"),
                ward: row.string("ward"),
                coordinate: parseCoordinate(row)
            )
        }

        if total == 0 && breakdown.isEmpty && recent.isEmpty { return nil }
        return ServiceRequestSummary(
            neighbourhood: neighbourhood,
            totalLastYear: total,
            openLastYear: open,
            closedLastYear: closed,
            statusBreakdown: statuses,
            channelBreakdown: channels,
            topSubjects: breakdown,
            topReasons: reasons,
            topTypes: types,
            monthlyTrend: trend,
            recentRequests: recent
        )
    }

    private func fetchServiceBreakdown(dataset: String, field: String, whereBase: String, limit: Int) async -> [IncidentBreakdown] {
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "\(field), count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(whereBase) AND \(field) IS NOT NULL"),
            URLQueryItem(name: "$group", value: field),
            URLQueryItem(name: "$order", value: "cnt DESC"),
            URLQueryItem(name: "$limit", value: "\(limit)")
        ])) ?? []
        return rows.compactMap { row in
            guard let value = row.string(field), let count = row.int("cnt") else { return nil }
            return IncidentBreakdown(incidentType: value, count: count)
        }
    }

    private func serviceNeighbourhoodClause(_ neighbourhood: String) -> String {
        let upper = escaped(neighbourhood.uppercased())
        let words = neighbourhood
            .uppercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 3 }
        let allWordsClause = words.isEmpty
            ? nil
            : words.map { "upper(neighbourhood) like '%\(escaped($0))%'" }.joined(separator: " AND ")

        var clauses = [
            "upper(neighbourhood)='\(upper)'",
            "upper(neighbourhood) like '%\(upper)%'"
        ]
        if let allWordsClause {
            clauses.append("(\(allWordsClause))")
        }
        return "(\(clauses.joined(separator: " OR ")))"
    }

    private func fetchPlanningContext(property: PropertyAssessment?) async -> PlanningContextSummary? {
        guard let property else { return nil }
        async let zoning = fetchZoningDescription(zoningCode: property.zoning)
        async let notices = fetchPublicNotices(property: property)
        let zoningDescription = await zoning
        let publicNotices = await notices
        if property.zoning == nil && zoningDescription == nil && publicNotices.isEmpty { return nil }
        return PlanningContextSummary(
            zoningCode: property.zoning,
            zoningDescription: zoningDescription,
            publicNotices: publicNotices
        )
    }

    private func fetchZoningDescription(zoningCode: String?) async -> String? {
        guard let dataset = datasets.zoningParcels,
              let zoningCode,
              !zoningCode.isEmpty else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "short_description,long_description"),
            URLQueryItem(name: "$where", value: "upper(zoning)='\(escaped(zoningCode.uppercased()))'"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        return rows.first?.string("short_description") ?? rows.first?.string("long_description")
    }

    private func fetchPublicNotices(property: PropertyAssessment) async -> [PublicNotice] {
        guard let dataset = datasets.publicNotices,
              let subject = property.coordinate else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "notice_type,address,description,decision,meeting_date,point"),
            URLQueryItem(name: "$where", value: "within_circle(point,\(subject.latitude),\(subject.longitude),1000)"),
            URLQueryItem(name: "$order", value: "meeting_date DESC"),
            URLQueryItem(name: "$limit", value: "20")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        return rows.compactMap { row in
            guard let noticeType = row.string("notice_type") else { return nil }
            let coordinate = parseCoordinate(row)
            let distance = coordinate.map {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: subjectLocation)
            }
            return PublicNotice(
                noticeType: noticeType,
                address: row.string("address") ?? "Address unavailable",
                description: plainText(row.string("description") ?? row.string("plain_language")),
                decision: row.string("decision"),
                meetingDate: parseDate(row.string("meeting_date")),
                distanceDescription: distance.map(distanceDescription(meters:)),
                coordinate: coordinate
            )
        }
    }

    private func fetchStreetAccess(address: NormalizedAddress, property: PropertyAssessment?) async -> StreetAccessSummary? {
        async let pavement = fetchPavementCondition(address)
        async let schoolZone = fetchSchoolSpeedLimit(address)
        async let cycling = fetchCyclingRoutes(property: property)
        async let disruptions = fetchAccessibilityDisruptions(property: property)
        async let closures = fetchLaneClosures(address)

        let pavementSummary = await pavement
        let schoolSpeedLimit = await schoolZone
        let cyclingCount = await cycling
        let activeDisruptions = await disruptions
        let activeClosures = await closures

        if pavementSummary.condition == nil,
           schoolSpeedLimit == nil,
           cyclingCount == 0,
           activeDisruptions.isEmpty,
           activeClosures.isEmpty {
            return nil
        }

        return StreetAccessSummary(
            pavementCondition: pavementSummary.condition,
            pavementSurface: pavementSummary.surface,
            schoolSpeedLimit: schoolSpeedLimit,
            cyclingRoutesNearby: cyclingCount,
            activeDisruptions: activeDisruptions,
            activeLaneClosures: activeClosures
        )
    }

    private func fetchPavementCondition(_ address: NormalizedAddress) async -> (condition: String?, surface: String?) {
        guard let dataset = datasets.pavementCondition else { return (nil, nil) }
        let token = escaped(streetCore(address.streetName))
        guard !token.isEmpty else { return (nil, nil) }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "general_condition,surface_type"),
            URLQueryItem(name: "$where", value: "upper(street_name) like '\(token)%'"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        return (rows.first?.string("general_condition"), rows.first?.string("surface_type"))
    }

    private func fetchSchoolSpeedLimit(_ address: NormalizedAddress) async -> SchoolSpeedLimit? {
        guard let dataset = datasets.schoolSpeedLimits else { return nil }
        let token = escaped(streetCore(address.streetName))
        guard !token.isEmpty else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "school,speed_limit,effective_days,effective_time"),
            URLQueryItem(name: "$where", value: "upper(street_name) like '\(token)%'"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first,
              let school = row.string("school") else { return nil }
        let speed = row.string("speed_limit") ?? row.int("speed_limit").map { "\($0)" } ?? "30"
        return SchoolSpeedLimit(
            school: school,
            speedLimit: "\(speed) km/h",
            effectiveDays: row.string("effective_days"),
            effectiveTime: row.string("effective_time")
        )
    }

    private func fetchCyclingRoutes(property: PropertyAssessment?) async -> Int {
        guard let dataset = datasets.cyclingNetwork,
              let subject = property?.coordinate else { return 0 }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),700)")
        ])) ?? []
        return rows.first?.int("cnt") ?? 0
    }

    private func fetchAccessibilityDisruptions(property: PropertyAssessment?) async -> [StreetDisruption] {
        guard let dataset = datasets.accessibilityDisruptions,
              let subject = property?.coordinate else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "title,description,category,subcategory,status,start_date,end_date,location_point"),
            URLQueryItem(name: "$where", value: "within_circle(location_point,\(subject.latitude),\(subject.longitude),1200) AND (status IS NULL OR upper(status) != 'CLOSED')"),
            URLQueryItem(name: "$order", value: "start_date DESC"),
            URLQueryItem(name: "$limit", value: "10")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        return rows.compactMap { row in
            guard let title = row.string("title") else { return nil }
            let coordinate = parseCoordinate(row)
            let distance = coordinate.map {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: subjectLocation)
            }
            let detail = [row.string("category"), row.string("subcategory"), row.string("description")]
                .compactMap { plainText($0) }
                .joined(separator: " · ")
            return StreetDisruption(
                title: title,
                detail: detail.isEmpty ? nil : detail,
                status: row.string("status"),
                startDate: parseDate(row.string("start_date")),
                endDate: parseDate(row.string("end_date")),
                distanceDescription: distance.map(distanceDescription(meters:)),
                coordinate: coordinate
            )
        }
    }

    private func fetchLaneClosures(_ address: NormalizedAddress) async -> [StreetDisruption] {
        guard let dataset = datasets.laneClosures else { return [] }
        let token = escaped(streetCore(address.streetName))
        guard !token.isEmpty else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "primary_street,cross_street,boundaries,direction,date_closed_from,date_closed_to,traffic_effect,status,complete_closure,latitude,longitude"),
            URLQueryItem(name: "$where", value: "upper(primary_street) like '\(token)%' AND (status IS NULL OR upper(status) != 'CLOSED')"),
            URLQueryItem(name: "$order", value: "date_closed_from DESC"),
            URLQueryItem(name: "$limit", value: "10")
        ])) ?? []
        return rows.compactMap { row in
            guard let street = row.string("primary_street") else { return nil }
            let title = [street, row.string("cross_street")].compactMap { $0 }.joined(separator: " at ")
            let detail = [row.string("traffic_effect"), row.string("boundaries"), row.string("direction")]
                .compactMap { $0 }
                .joined(separator: " · ")
            return StreetDisruption(
                title: title,
                detail: detail.isEmpty ? nil : detail,
                status: row.string("status") ?? row.string("complete_closure"),
                startDate: parseDate(row.string("date_closed_from")),
                endDate: parseDate(row.string("date_closed_to")),
                distanceDescription: nil,
                coordinate: parseCoordinate(row)
            )
        }
    }

    private func fetchEmergency(neighbourhood: String?) async -> EmergencySummary? {
        guard let dataset = datasets.emergencyCalls, let neighbourhood else { return nil }
        let neighUpper = escaped(neighbourhood.uppercased())
        let neighClause = "upper(neighbourhood)='\(neighUpper)'"
        let timeField = "call_time"
        let sixYearClause = "\(neighClause) AND \(timeField) >= '\(yearOffset(-6))-01-01T00:00:00'"
        let lastYearClause = "\(neighClause) AND \(timeField) > '\(yearOffset(-1))-01-01T00:00:00'"

        async let yearlyRows = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(\(timeField)) as year, count(*) as cnt"),
            URLQueryItem(name: "$where", value: sixYearClause),
            URLQueryItem(name: "$group", value: "year"),
            URLQueryItem(name: "$order", value: "year")
        ])
        async let breakdownRows = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "incident_type, count(*) as cnt"),
            URLQueryItem(name: "$where", value: lastYearClause),
            URLQueryItem(name: "$group", value: "incident_type"),
            URLQueryItem(name: "$order", value: "cnt DESC"),
            URLQueryItem(name: "$limit", value: "12")
        ])
        async let breakdownByYearRows = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(\(timeField)) as year, incident_type, count(*) as cnt"),
            URLQueryItem(name: "$where", value: sixYearClause),
            URLQueryItem(name: "$group", value: "year, incident_type"),
            URLQueryItem(name: "$order", value: "year, cnt DESC")
        ])
        async let monthlyRows = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(\(timeField)) as year, date_extract_m(\(timeField)) as month, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(neighClause) AND \(timeField) > '\(yearOffset(-2))-01-01T00:00:00'"),
            URLQueryItem(name: "$group", value: "year, month"),
            URLQueryItem(name: "$order", value: "year, month")
        ])
        async let wardRows = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "ward, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(lastYearClause) AND ward IS NOT NULL"),
            URLQueryItem(name: "$group", value: "ward"),
            URLQueryItem(name: "$order", value: "cnt DESC"),
            URLQueryItem(name: "$limit", value: "8")
        ])
        async let motorVehicleRows = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "motor_vehicle_incident, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(lastYearClause) AND motor_vehicle_incident IS NOT NULL"),
            URLQueryItem(name: "$group", value: "motor_vehicle_incident"),
            URLQueryItem(name: "$order", value: "cnt DESC")
        ])
        async let recentRows = fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "incident_number,incident_type,call_time,closed_time,motor_vehicle_incident,units,ward"),
            URLQueryItem(name: "$where", value: lastYearClause),
            URLQueryItem(name: "$order", value: "\(timeField) DESC"),
            URLQueryItem(name: "$limit", value: "500")
        ])

        let yearly = (try? await yearlyRows) ?? []
        let breakdown = (try? await breakdownRows) ?? []
        let byYear = (try? await breakdownByYearRows) ?? []
        let monthly = (try? await monthlyRows) ?? []
        let ward = (try? await wardRows) ?? []
        let motorVehicle = (try? await motorVehicleRows) ?? []
        let recent = (try? await recentRows) ?? []

        var breakdownByYear: [Int: [IncidentBreakdown]] = [:]
        for row in byYear {
            guard let year = row.int("year"),
                  let type = row.string("incident_type"),
                  let count = row.int("cnt") else { continue }
            breakdownByYear[year, default: []].append(IncidentBreakdown(incidentType: type, count: count))
        }

        let recentIncidents = recent.compactMap { row -> EmergencyIncidentRecord? in
            guard let type = row.string("incident_type") else { return nil }
            return EmergencyIncidentRecord(
                incidentNumber: row.string("incident_number"),
                incidentType: type,
                callTime: parseDate(row.string("call_time")),
                closedTime: parseDate(row.string("closed_time")),
                motorVehicleIncident: row.string("motor_vehicle_incident"),
                units: row.string("units"),
                ward: row.string("ward")
            )
        }
        let durations = recentIncidents.compactMap(\.durationMinutes).filter { $0 > 0 && $0 < 24 * 60 }
        let averageDuration = durations.isEmpty ? nil : Double(durations.reduce(0, +)) / Double(durations.count)
        let unitBreakdown = emergencyUnitBreakdown(from: recentIncidents)
        let totalLastYear = breakdown.compactMap { $0.int("cnt") }.reduce(0, +)
        let motorVehicleLastYear = motorVehicle
            .filter { ($0.string("motor_vehicle_incident") ?? "").localizedCaseInsensitiveContains("yes") }
            .compactMap { $0.int("cnt") }
            .reduce(0, +)

        return EmergencySummary(
            neighbourhood: neighbourhood,
            totalLastYear: totalLastYear,
            motorVehicleLastYear: motorVehicleLastYear,
            averageDurationMinutes: averageDuration,
            yearlyCalls: yearly.compactMap { row in
                guard let year = row.int("year"), let count = row.int("cnt") else { return nil }
                return YearCount(year: year, count: count)
            },
            monthlyTrend: monthly.compactMap { row in
                guard let year = row.int("year"),
                      let month = row.int("month"),
                      let count = row.int("cnt") else { return nil }
                return EmergencyMonth(year: year, month: month, count: count)
            },
            last12Months: breakdown.compactMap { row in
                guard let type = row.string("incident_type"), let count = row.int("cnt") else { return nil }
                return IncidentBreakdown(incidentType: type, count: count)
            },
            breakdownByYear: breakdownByYear.mapValues { $0.sorted { $0.count > $1.count } },
            wardBreakdown: ward.compactMap { row in
                guard let ward = row.string("ward"), let count = row.int("cnt") else { return nil }
                return IncidentBreakdown(incidentType: ward, count: count)
            },
            motorVehicleBreakdown: motorVehicle.compactMap { row in
                guard let flag = row.string("motor_vehicle_incident"), let count = row.int("cnt") else { return nil }
                return IncidentBreakdown(incidentType: flag, count: count)
            },
            unitBreakdown: unitBreakdown,
            recentIncidents: Array(recentIncidents.prefix(8)),
            citywideMedian: nil,
            neighbourhoodRank: nil,
            neighbourhoodCount: nil
        )
    }

    private func emergencyUnitBreakdown(from incidents: [EmergencyIncidentRecord]) -> [IncidentBreakdown] {
        var counts: [String: Int] = [:]
        for incident in incidents {
            guard let units = incident.units else { continue }
            for raw in units.split(whereSeparator: { ",; /".contains($0) }) {
                let unit = String(raw).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard !unit.isEmpty else { continue }
                let category = emergencyUnitCategory(unit)
                counts[category, default: 0] += 1
            }
        }
        return counts
            .map { IncidentBreakdown(incidentType: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private func emergencyUnitCategory(_ unit: String) -> String {
        if unit.range(of: #"^\d+$"#, options: .regularExpression) != nil { return "Ambulance" }
        if unit.hasPrefix("E") { return "Engine / pumper" }
        if unit.hasPrefix("L") { return "Ladder" }
        if unit.hasPrefix("R") { return "Rescue" }
        if unit.hasPrefix("SQ") { return "Squad" }
        if unit.hasPrefix("DC") || unit == "D" || unit.hasPrefix("P") { return "Command" }
        if unit.hasPrefix("EPIC") || unit.hasPrefix("MIRV") || unit.hasPrefix("PACE") || unit.hasPrefix("PTRS") { return "Medical specialty" }
        if unit.hasPrefix("HM") { return "Hazmat" }
        if unit.hasPrefix("W") { return "Water rescue" }
        return "Specialty / other"
    }

    private func fetchPoliceCrime(neighbourhood: String?) async -> PoliceCrimeSummary? {
        guard let neighbourhood,
              let dataset = datasets.policeCrimeMaps,
              let url = URL(string: "https://www.arcgis.com/sharing/rest/content/items/\(dataset)/data") else {
            return nil
        }

        do {
            let csv: String
            if let cached = Self.policeCrimeCSVCache {
                csv = cached
            } else {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
                      let downloaded = String(data: data, encoding: .utf8) else {
                    return nil
                }
                Self.policeCrimeCSVCache = downloaded
                csv = downloaded
            }

            var yearlyNeighbourhood: [Int: Int] = [:]
            var yearlyCityNeighbourhoods: [Int: [String: Int]] = [:]
            var crimeTypes: [String: Int] = [:]
            var crimeTypesByYear: [Int: [String: Int]] = [:]
            var offenceTypes: [String: Int] = [:]
            var offenceTypesByYear: [Int: [String: Int]] = [:]
            var latestMonth: PoliceCrimeMonth?

            for rawLine in csv.split(whereSeparator: \.isNewline).dropFirst() {
                let columns = parseCSVLine(String(rawLine))
                guard columns.count >= 7,
                      let year = Int(columns[0]),
                      let month = Int(columns[1]),
                      let count = Int(columns[4]) else { continue }
                let rowNeighbourhood = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rowNeighbourhood.isEmpty, rowNeighbourhood.uppercased() != "NA" else { continue }

                yearlyCityNeighbourhoods[year, default: [:]][rowNeighbourhood, default: 0] += count
                let rowMonth = PoliceCrimeMonth(year: year, month: month)
                if latestMonth == nil || year > latestMonth!.year || (year == latestMonth!.year && month > latestMonth!.month) {
                    latestMonth = rowMonth
                }

                guard neighbourhoodName(rowNeighbourhood, matches: neighbourhood) else { continue }
                yearlyNeighbourhood[year, default: 0] += count

                let crimeType = columns[5].trimmingCharacters(in: .whitespacesAndNewlines)
                if !crimeType.isEmpty {
                    crimeTypes[crimeType, default: 0] += count
                    crimeTypesByYear[year, default: [:]][crimeType, default: 0] += count
                }

                let offenceType = columns[6].trimmingCharacters(in: .whitespacesAndNewlines)
                if !offenceType.isEmpty {
                    offenceTypes[offenceType, default: 0] += count
                    offenceTypesByYear[year, default: [:]][offenceType, default: 0] += count
                }
            }

            let years = Set(yearlyNeighbourhood.keys).union(yearlyCityNeighbourhoods.keys).sorted()
            let yearlyCounts = years.map { year in
                let cityCounts = yearlyCityNeighbourhoods[year].map { Array($0.values) } ?? []
                let average = cityCounts.isEmpty ? 0 : Double(cityCounts.reduce(0, +)) / Double(cityCounts.count)
                return PoliceCrimeYear(
                    year: year,
                    neighbourhood: yearlyNeighbourhood[year] ?? 0,
                    citywideAverage: average
                )
            }

            let summary = PoliceCrimeSummary(
                neighbourhood: neighbourhood,
                latestMonth: latestMonth,
                yearlyCounts: yearlyCounts,
                crimeTypes: incidentBreakdowns(from: crimeTypes),
                crimeTypesByYear: crimeTypesByYear.mapValues(incidentBreakdowns),
                offenceTypes: incidentBreakdowns(from: offenceTypes),
                offenceTypesByYear: offenceTypesByYear.mapValues(incidentBreakdowns)
            )
            if summary.yearlyCounts.isEmpty && summary.crimeTypes.isEmpty && summary.offenceTypes.isEmpty { return nil }
            return summary
        } catch {
            return nil
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var isQuoted = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let nextIndex = line.index(after: index)
                if isQuoted, nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    current.append("\"")
                    index = nextIndex
                } else {
                    isQuoted.toggle()
                }
            } else if character == "," && !isQuoted {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
            index = line.index(after: index)
        }
        fields.append(current)
        return fields
    }

    private func incidentBreakdowns(from counts: [String: Int]) -> [IncidentBreakdown] {
        counts
            .map { IncidentBreakdown(incidentType: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.incidentType < rhs.incidentType }
                return lhs.count > rhs.count
            }
    }

    private func neighbourhoodName(_ lhs: String, matches rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(rhs.trimmingCharacters(in: .whitespacesAndNewlines), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private func fetchPublicHealth(neighbourhood: String?) async -> PublicHealthSummary? {
        guard let dataset = datasets.naloxone else { return nil }
        let substanceDataset = datasets.substanceUse
        let citywideNeighbourhoodYears = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(dispatch_date) as year, neighbourhood, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "dispatch_date >= '\(yearOffset(-6))-01-01T00:00:00' AND neighbourhood IS NOT NULL"),
            URLQueryItem(name: "$group", value: "year, neighbourhood"),
            URLQueryItem(name: "$order", value: "year")
        ])) ?? []
        let neighbourhoodYears: [[String: Any]]
        if let neighbourhood {
            neighbourhoodYears = (try? await fetch(dataset, queryItems: [
                URLQueryItem(name: "$select", value: "date_extract_y(dispatch_date) as year, count(*) as cnt"),
                URLQueryItem(name: "$where", value: "upper(neighbourhood)='\(escaped(neighbourhood.uppercased()))' AND dispatch_date >= '\(yearOffset(-6))-01-01T00:00:00'"),
                URLQueryItem(name: "$group", value: "year"),
                URLQueryItem(name: "$order", value: "year")
            ])) ?? []
        } else {
            neighbourhoodYears = []
        }
        let ages = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "age, count(*) as cnt"),
            URLQueryItem(name: "$group", value: "age"),
            URLQueryItem(name: "$order", value: "cnt DESC"),
            URLQueryItem(name: "$limit", value: "6")
        ])) ?? []
        let ageNeighbourhoodClause = neighbourhood.map { "upper(neighbourhood)='\(escaped($0.uppercased()))' AND " } ?? ""
        let agesByYearRows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(dispatch_date) as year, age, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(ageNeighbourhoodClause)dispatch_date >= '\(yearOffset(-6))-01-01T00:00:00' AND age IS NOT NULL"),
            URLQueryItem(name: "$group", value: "year, age"),
            URLQueryItem(name: "$order", value: "year, cnt DESC")
        ])) ?? []
        let substances: [[String: Any]]
        let substancesByYearRows: [[String: Any]]
        if let substanceDataset {
            let neighbourhoodClause = neighbourhood.map { "upper(neighbourhood)='\(escaped($0.uppercased()))' AND " } ?? ""
            substances = (try? await fetch(substanceDataset, queryItems: [
                URLQueryItem(name: "$select", value: "substance, count(*) as cnt"),
                URLQueryItem(name: "$where", value: "\(neighbourhoodClause)dispatch_date >= '\(yearOffset(-6))-01-01T00:00:00' AND substance IS NOT NULL"),
                URLQueryItem(name: "$group", value: "substance"),
                URLQueryItem(name: "$order", value: "cnt DESC"),
                URLQueryItem(name: "$limit", value: "8")
            ])) ?? []
            substancesByYearRows = (try? await fetch(substanceDataset, queryItems: [
                URLQueryItem(name: "$select", value: "date_extract_y(dispatch_date) as year, substance, count(*) as cnt"),
                URLQueryItem(name: "$where", value: "\(neighbourhoodClause)dispatch_date >= '\(yearOffset(-6))-01-01T00:00:00' AND substance IS NOT NULL"),
                URLQueryItem(name: "$group", value: "year, substance"),
                URLQueryItem(name: "$order", value: "year, cnt DESC")
            ])) ?? []
        } else {
            substances = []
            substancesByYearRows = []
        }
        var citywideCountsByYear: [Int: [Int]] = [:]
        for row in citywideNeighbourhoodYears {
            guard let year = row.int("year"), let count = row.int("cnt") else { continue }
            citywideCountsByYear[year, default: []].append(count)
        }
        var mergedYears: [Int: (neighbourhood: Int, citywideAverage: Double)] = [:]
        for (year, counts) in citywideCountsByYear where !counts.isEmpty {
            let average = Double(counts.reduce(0, +)) / Double(counts.count)
            mergedYears[year, default: (0, 0)].citywideAverage = average
        }
        for row in neighbourhoodYears {
            guard let year = row.int("year"), let count = row.int("cnt") else { continue }
            mergedYears[year, default: (0, 0)].neighbourhood = count
        }
        var ageGroupsByYear: [Int: [IncidentBreakdown]] = [:]
        for row in agesByYearRows {
            guard let year = row.int("year"),
                  let age = row.string("age"),
                  let count = row.int("cnt") else { continue }
            ageGroupsByYear[year, default: []].append(IncidentBreakdown(incidentType: age, count: count))
        }
        var substancesByYear: [Int: [IncidentBreakdown]] = [:]
        var substanceTotalsByYear: [Int: Int] = [:]
        for row in substancesByYearRows {
            guard let year = row.int("year"),
                  let substance = row.string("substance"),
                  let count = row.int("cnt") else { continue }
            substancesByYear[year, default: []].append(IncidentBreakdown(incidentType: substance, count: count))
            substanceTotalsByYear[year, default: 0] += count
        }
        for (year, count) in substanceTotalsByYear where mergedYears[year, default: (0, 0)].neighbourhood == 0 {
            mergedYears[year, default: (0, 0)].neighbourhood = count
        }
        let summary = PublicHealthSummary(
            yearlyEvents: mergedYears.keys.sorted().map { year in
                let counts = mergedYears[year] ?? (0, 0)
                return PublicHealthYear(year: year, neighbourhood: counts.neighbourhood, citywideAverage: counts.citywideAverage)
            },
            ageGroups: ages.compactMap { row in
                guard let age = row.string("age"), let count = row.int("cnt") else { return nil }
                return IncidentBreakdown(incidentType: age, count: count)
            },
            ageGroupsByYear: ageGroupsByYear.mapValues { $0.sorted { $0.count > $1.count } },
            substances: substances.compactMap { row in
                guard let substance = row.string("substance"), let count = row.int("cnt") else { return nil }
                return IncidentBreakdown(incidentType: substance, count: count)
            },
            substancesByYear: substancesByYear.mapValues { $0.sorted { $0.count > $1.count } }
        )
        if summary.yearlyEvents.isEmpty && summary.ageGroups.isEmpty && summary.substances.isEmpty { return nil }
        return summary
    }

    private func parseCoordinate(_ row: [String: Any]) -> CLLocationCoordinate2D? {
        for key in ["geometry", "the_geom", "location", "point", "location_point"] {
            if let point = row[key] as? [String: Any] {
                if let coordinates = point["coordinates"] as? [Double], coordinates.count >= 2 {
                    return CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
                }
                if let coordinates = point["coordinates"] as? [[Double]],
                   let first = coordinates.first,
                   first.count >= 2 {
                    return CLLocationCoordinate2D(latitude: first[1], longitude: first[0])
                }
                if let latS = point["latitude"] as? String,
                   let lonS = point["longitude"] as? String,
                   let lat = Double(latS), let lon = Double(lonS) {
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                if let lat = point["latitude"] as? Double, let lon = point["longitude"] as? Double {
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        }
        if let lat = row.double("latitude"), let lon = row.double("longitude") {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let lat = row.double("centroid_lat"), let lon = row.double("centroid_lon") {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let location = row.string("location"),
           let coordinate = parseWKTPoint(location) {
            return coordinate
        }
        return nil
    }

    private func plainText(_ value: String?) -> String? {
        guard let value else { return nil }
        let withoutTags = value.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let collapsed = withoutTags.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? nil : collapsed
    }

    private func parseWKTPoint(_ value: String) -> CLLocationCoordinate2D? {
        let pattern = #"POINT\s*\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let lonRange = Range(match.range(at: 1), in: value),
              let latRange = Range(match.range(at: 2), in: value),
              let lon = Double(value[lonRange]),
              let lat = Double(value[latRange]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func yearOffset(_ offset: Int) -> Int {
        Calendar.current.component(.year, from: .now) + offset
    }

    private func isAdjacent(permitAddress: String, to civicNumber: Int?) -> Bool {
        guard let civicNumber else { return false }
        let permitNumber = permitAddress.split(separator: " ").first.flatMap { Int($0) }
        return permitNumber.map { abs($0 - civicNumber) <= 20 } ?? false
    }

    private func distanceDescription(from subject: CLLocationCoordinate2D, to coordinate: CLLocationCoordinate2D) -> String {
        let distanceMeters = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: subject.latitude, longitude: subject.longitude))
        return distanceDescription(meters: distanceMeters)
    }

    private func distanceDescription(meters distanceMeters: Double) -> String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters.rounded())) m"
        }
        return String(format: "%.1f km", distanceMeters / 1000)
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "CAD").precision(.fractionLength(0)))
    }
}
