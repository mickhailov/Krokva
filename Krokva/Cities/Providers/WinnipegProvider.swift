import CoreLocation
import Foundation
import MapKit

private struct SchoolDivisionBoundaryInfo {
    var name: String?
    var code: String?
    var website: String?
}

private struct SchoolDirectoryInfo {
    var name: String
    var address: String?
    var grades: String?
    var division: String?
    var program: String?
}

private struct ServerSchoolsResponse: Decodable {
    var assigned: [ServerSchool]
    var nearby: [ServerSchool]
}

private struct ServerSchool: Decodable {
    var id: String?
    var name: String
    var address: String
    var distanceDescription: String
    var distanceMeters: Double?
    var walkingTimeDescription: String?
    var grades: String?
    var schoolType: String?
    var programs: [String]?
    var isAssigned: Bool?
    var source: String?
    var coordinate: ServerCoordinate?
}

private struct ServerCoordinate: Decodable {
    var latitude: Double
    var longitude: Double
}

private struct CensusBoundaryCandidate {
    var boundaryType: String
    var names: [String]
    var displayName: String
}

// Aggregates geocode sub-progress from two parallel tasks into a single 0…1 value.
private actor GeoProgressAggregator {
    private var permits: Double = 0
    private var vacants: Double = 0
    var combined: Double { (permits + vacants) / 2 }
    func setPermits(_ v: Double) { permits = v }
    func setVacants(_ v: Double) { vacants = v }
}

final class WinnipegProvider: SocrataProvider, CityDataProvider {
    private static var policeCrimeCSVCache: String?
    private let nearbyRadiusMeters: Double = 500

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
        schools: "5298-dhjx",
        cyclingNetwork: "kjd9-dvf5",
        policeCrimeMaps: "d920a305d0024913a64e61ee1ef1d2a3",
        addresses: "cam2-ii3u",
        schoolDivisions: "capx-4rye",
        recreationComplexes: "bmi4-vvs2",
        leisureActivities: "a2fq-ufu6",
        publicAeds: "osm-aeds",
        snowRouteAddresses: "g3p4-h83y",
        plowZones: "39ur-higg",
        wasteCollection: "6rcy-9uik",
        snowParkingBans: "mfzv-893p",
        plowZoneSchedule: "tix9-r5tc",
        businessLicenses: "d5k3-sfzx",
        seasonalPatios: "cd49-nk9h",
        waterQuality: "a5ix-gnny",
        midblockTrafficCounts: "buvf-b9wp",
        permanentTrafficCounts: "46sc-6jrs",
        censusAge: "hiqy-dd38",
        censusHouseholds: "nmk5-uwfw",
        censusLanguage: "wgmu-db32",
        censusTransportMode: "ijxa-tybv",
        censusImmigration: "g66p-wwve",
        higherPovertyAreas: "ige9-5jxk",
        electoralWards: "t4cg-yaxs",
        communityCommittees: "dvqz-nw8j",
        poolsIndoor: "rnpn-3qku",
        poolsOutdoor: "dqfv-rh5e",
        poolsWading: "npmi-43db",
        poolsSprayPad: "uwfj-6mt2",
        walkways: "jdeq-xf3y",
        publicWifi: "rzm8-wh6x",
        vacantPropertyFires: "tnm5-yaem",
        roomingHouseEnforcement: "vk2f-xwp7",
        rushHourTowing: "8phf-9kb6",
        paidParking: "rmsh-97k4",
        capitalProjects: "9xar-v8xm",
        infrastructureFunding: "rwrz-d7hc",
        facilityClosures: "fxcw-yyy2",
        heritage: "ptpx-kgiu",
        mosquitoTraps: "du7c-8488"
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
        super.init(domain: "3.99.123.190:8889", scheme: "http")
    }

    func fetchReport(for address: NormalizedAddress) async -> AddressReport {
        await fetchReport(for: address, progress: nil, subProgress: nil)
    }

    /// Binds `ReportModuleContext.current` for the duration of a module fetch so any request
    /// that throws inside it is attributed to `module` by `DataSourceHealth`.
    private func inModule<T>(_ module: ReportModule, _ operation: () async -> T) async -> T {
        await ReportModuleContext.$current.withValue(module, operation: operation)
    }

    func fetchReport(for address: NormalizedAddress, progress: ReportService.ProgressHandler?, subProgress: ReportService.SubProgressHandler?) async -> AddressReport {
        await dataSourceHealth.reset()

        await progress?(.assessment)
        async let property = inModule(.property) { await self.fetchAssessment(address) }
        async let infrastructure = inModule(.infrastructure) { await self.fetchInfrastructure(address) }

        let assessment = await property
        await progress?(.nearbyRecords)
        let nearbyStreetCores = await inModule(.property) { await self.fetchNearbyStreetCores(address: address, property: assessment) }
        await progress?(.permits)
        async let permitsRaw = inModule(.permits) { await self.fetchPermits(address, streetCores: nearbyStreetCores) }
        async let vacantOrdersRaw = inModule(.vacantOrders) { await self.fetchVacantOrders(address, streetCores: nearbyStreetCores) }
        async let values = inModule(.neighbourhoodValues) { await self.fetchNeighbourhoodValues(neighbourhood: assessment?.neighbourhood) }
        async let comparables = inModule(.comparables) { await self.fetchComparables(address: address, property: assessment) }
        async let permitActivity = inModule(.permitActivity) { await self.fetchPermitActivity(neighbourhood: assessment?.neighbourhood) }
        async let parks = inModule(.parks) { await self.fetchParks(property: assessment) }
        async let transit = inModule(.transit) { await self.fetchTransit(property: assessment) }
        async let bylaw = inModule(.bylaw) { await self.fetchBylaw(neighbourhood: assessment?.neighbourhood) }
        async let development = inModule(.development) { await self.fetchDevelopmentContext(address: address, streetCores: nearbyStreetCores) }
        async let river = inModule(.river) { await self.fetchRiverGauge(property: assessment) }
        async let library = inModule(.library) { await self.fetchLibrary(property: assessment) }
        async let serviceRequests = inModule(.serviceRequests) { await self.fetchServiceRequests(neighbourhood: assessment?.neighbourhood) }
        async let planning = inModule(.planning) { await self.fetchPlanningContext(property: assessment) }
        async let streetAccess = inModule(.streetAccess) { await self.fetchStreetAccess(address: address, property: assessment) }
        await progress?(.emergency)
        async let emergency = inModule(.emergency) { await self.fetchEmergency(neighbourhood: assessment?.neighbourhood) }
        await progress?(.health)
        async let health = inModule(.publicHealth) { await self.fetchPublicHealth(neighbourhood: assessment?.neighbourhood, coordinate: assessment?.coordinate) }
        async let policeCrime = inModule(.policeCrime) { await self.fetchPoliceCrime(neighbourhood: assessment?.neighbourhood) }
        async let civicContext = inModule(.civicContext) { await self.fetchCivicContext(address: address, property: assessment) }
        async let shortTermRentals = inModule(.shortTermRentals) { await self.fetchShortTermRentals(address: address, streetCores: nearbyStreetCores) }
        async let recreation = inModule(.recreation) { await self.fetchRecreation(property: assessment) }
        async let schools = inModule(.schools) { await self.fetchNearbySchools(property: assessment) }
        async let waste = inModule(.waste) { await self.fetchWasteCollection(address: address, property: assessment) }
        async let demographics = inModule(.demographics) { await self.fetchDemographics(address: address, property: assessment) }
        async let localGovernment = inModule(.localGovernment) { await self.fetchLocalGovernment(address: address, property: assessment) }
        async let localBusiness = inModule(.localBusiness) { await self.fetchLocalBusiness(property: assessment) }
        async let aquatics = inModule(.aquatics) { await self.fetchAquatics(property: assessment) }
        async let traffic = inModule(.traffic) { await self.fetchTraffic(address: address, property: assessment) }
        async let neighbourhoodRisk = inModule(.neighbourhoodRisk) { await self.fetchNeighbourhoodRisk(property: assessment) }
        async let waterQuality = inModule(.waterQuality) { await self.fetchWaterQuality() }
        async let capitalWorks = inModule(.capitalWorks) { await self.fetchCapitalWorks(address: address, property: assessment) }
        async let facilityClosures = inModule(.facilityClosures) { await self.fetchFacilityClosures(address: address, property: assessment) }
        async let heritage = inModule(.heritage) { await self.fetchHeritage(address: address, property: assessment) }
        async let mosquito = inModule(.mosquito) { await self.fetchMosquito(property: assessment) }

        await progress?(.infrastructure)
        let infrastructureSummary = await infrastructure
        await progress?(.mapCoordinates)
        let geoAgg = GeoProgressAggregator()
        let permitsRawValue = await permitsRaw
        let vacantOrdersRawValue = await vacantOrdersRaw
        async let geocodedPermits = geocodePermits(permitsRawValue, subject: assessment?.coordinate) { fraction in
            await geoAgg.setPermits(fraction)
            await subProgress?(await geoAgg.combined)
        }
        async let geocodedVacantOrders = geocodeVacantOrders(vacantOrdersRawValue, subject: assessment?.coordinate) { fraction in
            await geoAgg.setVacants(fraction)
            await subProgress?(await geoAgg.combined)
        }
        let permits = await geocodedPermits
        let vacantOrders = await geocodedVacantOrders
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
        let civicContextSummary = await civicContext
        let shortTermRentalSummary = await shortTermRentals
        let recreationSummary = await recreation
        let nearbySchoolsList = await schools
        let wasteSummary = await waste
        let demographicsSummary = await demographics
        let localGovernmentSummary = await localGovernment
        let localBusinessSummary = await localBusiness
        let aquaticsSummary = await aquatics
        let trafficSummary = await traffic
        let neighbourhoodRiskSummary = await neighbourhoodRisk
        let waterQualitySummary = await waterQuality
        let capitalWorksSummary = await capitalWorks
        let facilityClosureSummary = await facilityClosures
        let heritageSummary = await heritage
        let mosquitoSummary = await mosquito
        // Radon and rental-market figures are metro-wide reference values (not per-address),
        // so they are filled from static City/Province sources rather than fetched.
        let radonSummary = assessment == nil ? nil : winnipegRadon
        let rentalMarketSummary = assessment == nil ? nil : winnipegRentalMarket

        await progress?(.assembling)

        // The assessment feed has no postal code; backfill it from civic context so the
        // hero card and facts both show it.
        var propertyForReport = assessment
        if propertyForReport?.postalCode == nil {
            propertyForReport?.postalCode = civicContextSummary?.postalCode
        }

        let failedModules = await dataSourceHealth.snapshot()

        return AddressReport(
            address: address,
            providerID: cityID,
            cityName: displayName,
            providerState: .live,
            property: propertyForReport,
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
            shortTermRentals: shortTermRentalSummary,
            civicContext: civicContextSummary,
            recreation: recreationSummary,
            nearbySchools: nearbySchoolsList,
            waste: wasteSummary,
            demographics: demographicsSummary,
            localGovernment: localGovernmentSummary,
            localBusiness: localBusinessSummary,
            aquatics: aquaticsSummary,
            traffic: trafficSummary,
            neighbourhoodRisk: neighbourhoodRiskSummary,
            waterQuality: waterQualitySummary,
            capitalWorks: capitalWorksSummary,
            facilityClosures: facilityClosureSummary,
            heritage: heritageSummary,
            mosquito: mosquitoSummary,
            radon: radonSummary,
            rentalMarket: rentalMarketSummary,
            sources: sourceList(),
            failedModules: failedModules.isEmpty ? nil : failedModules
        )
    }

    private func geocodePermits(_ permits: [BuildingPermit], subject: CLLocationCoordinate2D?, onProgress: ((Double) async -> Void)? = nil) async -> [BuildingPermit] {
        guard !permits.isEmpty else { return permits }
        let lookup = await geocode(addresses: permits.map(\.address), onProgress: onProgress)
        let subjectLocation = subject.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        return permits.compactMap { p -> (BuildingPermit, Double)? in
            var copy = p
            if copy.coordinate == nil { copy.coordinate = lookup[geocodeKey(for: p.address)] }
            guard let subjectLocation, let coordinate = copy.coordinate else {
                return (copy, .greatestFiniteMagnitude)
            }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            guard distance <= nearbyRadiusMeters else { return nil }
            return (copy, distance)
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }

    private func geocodeVacantOrders(_ orders: [VacantOrder], subject: CLLocationCoordinate2D?, onProgress: ((Double) async -> Void)? = nil) async -> [VacantOrder] {
        guard !orders.isEmpty else { return orders }
        let lookup = await geocode(addresses: orders.map(\.address), onProgress: onProgress)
        let subjectLocation = subject.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        return orders.compactMap { o -> (VacantOrder, Double)? in
            var copy = o
            if copy.coordinate == nil { copy.coordinate = lookup[geocodeKey(for: o.address)] }
            guard let subjectLocation, let coordinate = copy.coordinate else {
                return (copy, .greatestFiniteMagnitude)
            }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            guard distance <= nearbyRadiusMeters else { return nil }
            copy.distanceDescription = distanceDescription(meters: distance)
            return (copy, distance)
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }

    private func geocodeKey(for address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return trimmed.uppercased() }
        let num = String(parts[0])
        let street = streetCore(String(parts[1]))
        return "\(num) \(street)"
    }

    private func geocode(addresses: [String], onProgress: ((Double) async -> Void)? = nil) async -> [String: CLLocationCoordinate2D] {
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
        let total = byStreet.count
        var completed = 0
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
                completed += 1
                if let onProgress, total > 0 {
                    await onProgress(Double(completed) / Double(total))
                }
            }
        }
        return result
    }

    private func fetchNearbyStreetCores(address: NormalizedAddress, property: PropertyAssessment?, radiusMeters: Double? = nil) async -> [String] {
        var cores = Set(addressNormalizer.streetVariants(for: address).map(streetCore).filter { !$0.isEmpty })
        guard let dataset = datasets.assessment,
              let property,
              let subject = property.coordinate else {
            return Array(cores).sorted()
        }
        let radiusMeters = radiusMeters ?? nearbyRadiusMeters

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
            ("School Zone Signage", datasets.schools),
            ("Cycling Network", datasets.cyclingNetwork),
            ("Addresses", datasets.addresses),
            ("School Divisions", datasets.schoolDivisions),
            ("Recreation Complex", datasets.recreationComplexes),
            ("LeisureONLINE Activities", datasets.leisureActivities),
            ("Snow Clearing Status & Winter Parking Bans", datasets.snowRouteAddresses),
            ("Plow Zones", datasets.plowZones),
            ("Recycling, Garbage and Yard Waste Collection Days", datasets.wasteCollection),
            ("Snow Parking Bans", datasets.snowParkingBans),
            ("Plow Zone Schedule", datasets.plowZoneSchedule),
            ("Business Licenses", datasets.businessLicenses),
            ("Seasonal Patios", datasets.seasonalPatios),
            ("Water Quality Test Results", datasets.waterQuality),
            ("Midblock Traffic Counts", datasets.midblockTrafficCounts),
            ("Permanent Count Station Traffic Counts", datasets.permanentTrafficCounts),
            ("Census - Population By Age", datasets.censusAge),
            ("Census - Households", datasets.censusHouseholds),
            ("Census - Language", datasets.censusLanguage),
            ("Census - Mode Of Transportation", datasets.censusTransportMode),
            ("Census - Citizenship & Immigration", datasets.censusImmigration),
            ("Higher Poverty Areas From the 2021 Census", datasets.higherPovertyAreas),
            ("Electoral Wards", datasets.electoralWards),
            ("Community Committee", datasets.communityCommittees),
            ("Swimming Pool Indoor", datasets.poolsIndoor),
            ("Swimming Pool Outdoor", datasets.poolsOutdoor),
            ("Swimming Pool Wading", datasets.poolsWading),
            ("Swimming Pool Spray Pad", datasets.poolsSprayPad),
            ("Walkways", datasets.walkways),
            ("Public Wifi Sites", datasets.publicWifi),
            ("Vacant Property Fires", datasets.vacantPropertyFires),
            ("Rooming House Enforcement Activity", datasets.roomingHouseEnforcement),
            ("Rush Hour Vehicle Towing Data", datasets.rushHourTowing),
            ("Block by Block On-Street Paid Parking", datasets.paidParking),
            ("Capital Projects Current Status", datasets.capitalProjects),
            ("Infrastructure Plan Funding", datasets.infrastructureFunding),
            ("Province of Manitoba - Health Protection Reports - Winnipeg", datasets.facilityClosures),
            ("Historical Resources", datasets.heritage),
            ("Daily Adult Mosquito Trap Data", datasets.mosquitoTraps)
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
                .replacingOccurrences(of: #"(?i)\b(avenue|ave|av|street|st|road|rd|drive|dr|boulevard|blvd|crescent|cres|place|pl|way|lane|ln|line|court|crt|ct|trail|trl|close|bay|bv|terrace|terr|circle|cir|grove|grv|heights|hts|bend|glen|mews|run)\b"#, with: "", options: .regularExpression)
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
        let assessmentYear = row.int("assessment_year") ?? row.int("roll_year") ?? row.int("year")
        // Estimated tax uses 2026 mill rates; direct tax year unknown so also use current year.
        let propertyTaxYear = 2026

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
            coordinate: parseCoordinate(row),
            assessmentYear: assessmentYear,
            propertyTaxYear: propertyTaxYear
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
            taggedTrees: treeCounts.tagged,
            topTreeSpecies: treeCounts.topSpecies
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

    /// The assessment feed stores `neighbourhood_area` in UPPERCASE ("RIVERVIEW"), but most
    /// other Winnipeg datasets (WFPS calls, police crime, 311) store the neighbourhood in
    /// Title Case ("Riverview"). Matching with `upper(neighbourhood)=...` forces Socrata to
    /// scan the whole table (a function on the column can't use the index) — on big datasets
    /// like WFPS that took 30s+ and blew the request timeout, silently emptying the card.
    /// Converting to the canonical Title Case lets the query hit the index (~1–3s instead).
    /// We capitalise the first letter of each word only, leaving apostrophes intact so
    /// "ST. JOHN'S" → "St. John's" (Swift's `.capitalized` would wrongly yield "John'S").
    private func properCaseNeighbourhood(_ name: String) -> String {
        let lower = name.lowercased()
        var result = ""
        var capitalizeNext = true
        for ch in lower {
            if ch == " " || ch == "-" || ch == "/" {
                capitalizeNext = true
                result.append(ch)
            } else if capitalizeNext {
                result.append(contentsOf: ch.uppercased())
                capitalizeNext = false
            } else {
                result.append(ch)
            }
        }
        return result
    }

    private func streetCore(_ name: String) -> String {
        name.replacingOccurrences(of: #"(?i)\s+(avenue|ave|av|street|st|road|rd|drive|dr|boulevard|blvd|crescent|cres|place|pl|way|lane|ln|line|court|crt|ct|trail|trl|close|bay|bv|terrace|terr|circle|cir|grove|grv|heights|hts|bend|glen|mews|run)\.?$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func fetchTrees(_ address: NormalizedAddress) async -> (public: Int, tagged: Int, topSpecies: String?) {
        guard let dataset = datasets.trees else { return (0, 0, nil) }
        let streetClause = "upper(street) like '\(escaped(streetCore(address.streetName)))%'"
        async let totalRows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt"),
            URLQueryItem(name: "$where", value: streetClause)
        ])) ?? []
        async let taggedRows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(streetClause) AND ded_tag_number IS NOT NULL")
        ])) ?? []
        async let speciesRows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "common_name, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(streetClause) AND common_name IS NOT NULL"),
            URLQueryItem(name: "$group", value: "common_name"),
            URLQueryItem(name: "$order", value: "cnt DESC"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        return (
            await totalRows.first?.int("cnt") ?? 0,
            await taggedRows.first?.int("cnt") ?? 0,
            await speciesRows.first?.string("common_name")
        )
    }

    private func fetchParks(property: PropertyAssessment?) async -> ParksSummary? {
        guard let property else { return nil }
        async let nearby = fetchNearbyParks(property: property)
        async let dogPark = fetchNearestDogPark(property: property)
        async let neighbourhood = fetchNeighbourhoodParks(neighbourhood: property.neighbourhood)
        let nearbyParks = await nearby
        let nearestPark = nearbyParks.first
        let nearestDogPark = await dogPark
        let neighbourhoodStats = await neighbourhood
        if nearestPark == nil && nearestDogPark == nil && neighbourhoodStats.count == 0 { return nil }
        return ParksSummary(
            nearestPark: nearestPark,
            nearbyParks: nearbyParks,
            neighbourhoodParkCount: neighbourhoodStats.count,
            neighbourhoodHectares: neighbourhoodStats.hectares,
            nearestDogPark: nearestDogPark
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

    private func fetchNearestDogPark(property: PropertyAssessment?, radiusMeters: Int = 3000) async -> DogParkAmenity? {
        guard let dataset = datasets.parkAssets,
              let subject = property?.coordinate else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "park_id,park_name,asset_type,point"),
            URLQueryItem(name: "$where", value: "within_circle(point,\(subject.latitude),\(subject.longitude),\(radiusMeters)) AND asset_class='OFF-LEASH DOG AREA'"),
            URLQueryItem(name: "$limit", value: "100")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        return rows.compactMap { row -> (DogParkAmenity, Double)? in
            guard let parkID = row.string("park_id"),
                  let name = row.string("park_name"),
                  let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            return (
                DogParkAmenity(
                    parkID: parkID,
                    name: name,
                    distanceDescription: distanceDescription(meters: distance),
                    classification: row.string("asset_type")?.capitalized,
                    coordinate: coordinate
                ),
                distance
            )
        }
        .sorted { $0.1 < $1.1 }
        .first?
        .0
    }

    private func fetchTransit(property: PropertyAssessment?) async -> TransitAccessSummary? {
        guard let subject = property?.coordinate,
              let onTimeDataset = datasets.transitOnTime else { return nil }
        let nearbyRows = (try? await fetch(onTimeDataset, queryItems: [
            URLQueryItem(name: "$select", value: "stop_number,route_number,route_name,deviation,location"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters)))"),
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
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters))) AND time >= '\(yearOffset(-1))-01-01T00:00:00'")
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

    private func fetchNearbySchools(property: PropertyAssessment?) async -> [SchoolAmenity] {
        guard let dataset = datasets.schools,
              let subject = property?.coordinate else { return [] }

        if let serverSchools = await fetchServerNearbySchools(subject: subject, address: property?.fullAddress), !serverSchools.isEmpty {
            return serverSchools
        }

        // School Zone Signage carries one Point per sign, so a single school appears as
        // many rows. Pull every sign within range, then collapse to one entry per school
        // using the averaged sign location as the school's approximate position. Keep a
        // wider candidate pool because some school-zone signs sit farther from the school
        // building than the building is from the subject property.
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "school,street_name,location"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),3500) AND school IS NOT NULL"),
            URLQueryItem(name: "$limit", value: "900")
        ])) ?? []

        struct SchoolAccumulator { var latSum = 0.0; var lonSum = 0.0; var count = 0; var street: String? }
        var bySchool: [String: SchoolAccumulator] = [:]
        for row in rows {
            guard let name = row.string("school")?.trimmingCharacters(in: .whitespacesAndNewlines).repairedFrenchCivicName,
                  !name.isEmpty,
                  let coordinate = parseCoordinate(row) else { continue }
            var acc = bySchool[name] ?? SchoolAccumulator()
            acc.latSum += coordinate.latitude
            acc.lonSum += coordinate.longitude
            acc.count += 1
            if acc.street == nil { acc.street = row.string("street_name") }
            bySchool[name] = acc
        }

        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        let signageCandidates = bySchool.compactMap { name, acc -> (school: SchoolAmenity, distance: Double)? in
            guard acc.count > 0 else { return nil }
            let coordinate = CLLocationCoordinate2D(
                latitude: acc.latSum / Double(acc.count),
                longitude: acc.lonSum / Double(acc.count)
            )
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            let school = SchoolAmenity(
                name: name,
                address: acc.street ?? "Winnipeg, MB",
                distanceDescription: distanceDescription(meters: distance),
                distanceMeters: distance,
                walkingTimeDescription: walkingTimeDescription(meters: distance),
                source: "Winnipeg school-zone signs",
                coordinate: coordinate
            )
            return (school, distance)
        }

        let mapKitCandidates = await fetchMapKitNearbySchools(subject: subject)
        let candidates = mergedSchoolCandidates(signageCandidates + mapKitCandidates)
            .sorted { $0.distance < $1.distance }
            .prefix(24)

        var enriched: [(school: SchoolAmenity, distance: Double)] = []
        await withTaskGroup(of: (SchoolAmenity, Double).self) { group in
            for candidate in candidates {
                group.addTask { [weak self] in
                    guard let self else { return candidate }
                    guard let info = await self.fetchSchoolDirectoryInfo(for: candidate.school) else {
                        return candidate
                    }
                    var school = candidate.school
                    if let address = info.address { school.address = address }
                    school.grades = info.grades
                    school.schoolType = schoolTypeLabel(division: info.division)
                    school.programs = programTags(from: info.program)
                    school.source = "Manitoba school directory"
                    return (school, candidate.distance)
                }
            }

            for await candidate in group {
                enriched.append(candidate)
            }
        }

        let addressCoordinates = await geocodeSchoolAddresses(enriched.map(\.school.address))
        return enriched.map { candidate -> (school: SchoolAmenity, distance: Double) in
            var school = candidate.school
            guard let coordinate = addressCoordinates[addressSearchKey(school.address)] else {
                return candidate
            }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            school.coordinate = coordinate
            school.distanceMeters = distance
            school.distanceDescription = distanceDescription(meters: distance)
            school.walkingTimeDescription = walkingTimeDescription(meters: distance)
            return (school, distance)
        }
        .sorted { $0.distance < $1.distance }
        .prefix(6)
        .map(\.school)
    }

    private func fetchServerNearbySchools(subject: CLLocationCoordinate2D, address: String?) async -> [SchoolAmenity]? {
        var components = URLComponents()
        components.scheme = scheme
        let parts = domain.split(separator: ":", maxSplits: 1)
        components.host = String(parts[0])
        if parts.count == 2, let port = Int(parts[1]) { components.port = port }
        components.path = "/api/schools/nearby"
        var queryItems = [
            URLQueryItem(name: "lat", value: "\(subject.latitude)"),
            URLQueryItem(name: "lon", value: "\(subject.longitude)"),
            URLQueryItem(name: "radius", value: "3000"),
            URLQueryItem(name: "limit", value: "8")
        ]
        if let address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "address", value: address))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return nil }
            let decoded = try JSONDecoder().decode(ServerSchoolsResponse.self, from: data)
            return (decoded.assigned + decoded.nearby).map { row in
                SchoolAmenity(
                    id: row.id.flatMap(UUID.init(uuidString:)) ?? UUID(),
                    name: row.name,
                    address: row.address,
                    distanceDescription: row.distanceDescription,
                    distanceMeters: row.distanceMeters,
                    walkingTimeDescription: row.walkingTimeDescription,
                    grades: row.grades,
                    schoolType: row.schoolType,
                    programs: row.programs ?? [],
                    isAssigned: row.isAssigned ?? false,
                    source: row.source,
                    coordinate: row.coordinate.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                )
            }
        } catch {
            return nil
        }
    }

    private func fetchMapKitNearbySchools(subject: CLLocationCoordinate2D) async -> [(school: SchoolAmenity, distance: Double)] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "school"
        request.region = MKCoordinateRegion(center: subject, latitudinalMeters: 3000, longitudinalMeters: 3000)
        request.resultTypes = .pointOfInterest

        do {
            let response = try await MKLocalSearch(request: request).start()
            let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
            return response.mapItems.compactMap { item in
                guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      isSchoolLikeName(name) else { return nil }
                let coordinate = item.placemark.coordinate
                let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
                guard distance <= 3000 else { return nil }
                let address = mapItemAddress(item) ?? item.placemark.title ?? "Winnipeg, MB"
                let school = SchoolAmenity(
                    name: name.repairedFrenchCivicName,
                    address: address,
                    distanceDescription: distanceDescription(meters: distance),
                    distanceMeters: distance,
                    walkingTimeDescription: walkingTimeDescription(meters: distance),
                    source: "Apple Maps",
                    coordinate: coordinate
                )
                return (school, distance)
            }
        } catch {
            return []
        }
    }

    private func mergedSchoolCandidates(_ candidates: [(school: SchoolAmenity, distance: Double)]) -> [(school: SchoolAmenity, distance: Double)] {
        var byName: [String: (school: SchoolAmenity, distance: Double)] = [:]
        for candidate in candidates {
            let key = normalizedSchoolName(candidate.school.name)
            guard !key.isEmpty else { continue }
            if let existing = byName[key], existing.distance <= candidate.distance { continue }
            byName[key] = candidate
        }
        return Array(byName.values)
    }

    private func isSchoolLikeName(_ name: String) -> Bool {
        let normalized = normalizedSchoolName(name)
        return normalized.contains("school")
            || normalized.contains("academy")
            || normalized.contains("collegiate")
            || normalized.contains("college")
            || normalized.contains("montessori")
            || normalized.contains("learning centre")
            || normalized.contains("ecole")
    }

    private func mapItemAddress(_ item: MKMapItem) -> String? {
        let placemark = item.placemark
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.nilIfEmpty }
            .joined(separator: " ")
            .nilIfEmpty
        let city = [placemark.locality, placemark.administrativeArea]
            .compactMap { $0?.nilIfEmpty }
            .joined(separator: ", ")
            .nilIfEmpty
        return [street, city].compactMap { $0 }.joined(separator: ", ").nilIfEmpty
    }

    private func walkingTimeDescription(meters: Double) -> String {
        let minutes = max(1, Int((meters / 80.0).rounded(.up)))
        return "\(minutes) min walk"
    }

    private func schoolTypeLabel(division: String?) -> String? {
        guard let division = division?.trimmingCharacters(in: .whitespacesAndNewlines), !division.isEmpty else {
            return nil
        }
        if division.localizedCaseInsensitiveContains("Independent") {
            return "Independent"
        }
        if division.localizedCaseInsensitiveContains("Catholic") {
            return "Catholic"
        }
        if division.localizedCaseInsensitiveContains("Winnipeg School Division") {
            return "Public · Winnipeg SD"
        }
        if division.localizedCaseInsensitiveContains("Louis Riel School Division") {
            return "Public · Louis Riel SD"
        }
        return division
            .replacingOccurrences(of: "School Division", with: "SD")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func programTags(from value: String?) -> [String] {
        guard let value else { return [] }
        let raw = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var tags: [String] = []
        func append(_ tag: String) {
            if !tags.contains(tag) { tags.append(tag) }
        }

        for item in raw {
            if item.localizedCaseInsensitiveContains("Early Immersion") {
                append("Early Immersion")
            } else if item.localizedCaseInsensitiveContains("Late Immersion") {
                append("Late Immersion")
            } else if item.localizedCaseInsensitiveContains("Middle Immersion") {
                append("Middle Immersion")
            } else if item.localizedCaseInsensitiveContains("French") {
                append("French")
            } else if item.localizedCaseInsensitiveContains("English") {
                append("English")
            } else if item.localizedCaseInsensitiveContains("Montessori") {
                append("Montessori")
            } else if item.count <= 22 {
                append(item)
            }
        }
        return Array(tags.prefix(4))
    }

    private func fetchSchoolDirectoryInfo(for school: SchoolAmenity) async -> SchoolDirectoryInfo? {
        var ids: [String] = []
        for term in schoolDirectorySearchTerms(for: school.name) {
            ids.append(contentsOf: await fetchManitobaSchoolIDs(matching: term))
        }
        ids = Array(NSOrderedSet(array: ids).compactMap { $0 as? String })
        guard !ids.isEmpty else { return nil }

        var matches: [SchoolDirectoryInfo] = []
        await withTaskGroup(of: SchoolDirectoryInfo?.self) { group in
            for id in ids.prefix(8) {
                group.addTask { await self.fetchManitobaSchoolDetail(id: id) }
            }
            for await info in group {
                if let info { matches.append(info) }
            }
        }

        let schoolName = normalizedSchoolName(school.name)
        let street = streetCore(school.address)
        return matches
            .filter { info in
                guard let address = info.address else { return false }
                return address.localizedCaseInsensitiveContains("Winnipeg")
                    || info.division?.localizedCaseInsensitiveContains("Winnipeg") == true
                    || streetCore(address) == street
            }
            .sorted { lhs, rhs in
                scoreSchoolDirectoryMatch(lhs, schoolName: schoolName, street: street)
                    > scoreSchoolDirectoryMatch(rhs, schoolName: schoolName, street: street)
            }
            .first
    }

    private func fetchManitobaSchoolIDs(matching name: String) async -> [String] {
        guard let url = URL(string: "https://web.gov.mb.ca/school/school?action=school") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var body = URLComponents()
        body.queryItems = [URLQueryItem(name: "SchoolText", value: name)]
        let query = body.percentEncodedQuery ?? "SchoolText=\(formEncoded(name))"
        request.httpBody = "\(query)&SchoolSearch=Submit".data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
                  let html = String(data: data, encoding: .utf8) else { return [] }
            return regexCaptures(pattern: #"singleschool&name=(\d+)""#, in: html)
        } catch {
            return []
        }
    }

    private func fetchManitobaSchoolDetail(id: String) async -> SchoolDirectoryInfo? {
        guard let url = URL(string: "https://web.gov.mb.ca/school/school?action=singleschool&name=\(id)") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
                  let html = String(data: data, encoding: .utf8) else { return nil }

            let rawName = firstRegexCapture(pattern: #"<div class="sc_name">([^<]+)</div>"#, in: html)
            let name = rawName?
                .htmlDecoded
                .replacingOccurrences(of: #"\s*#\d+$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let name, !name.isEmpty else { return nil }

            let address = firstRegexCapture(pattern: #"<div class="sc_name">[^<]+</div><div>(.*?)<br />"#, in: html)?
                .htmlDecoded
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let city = firstRegexCapture(pattern: #"<br />([^<]*Manitoba)<br />"#, in: html)?
                .htmlDecoded
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fullAddress = [address, city].compactMap { $0?.nilIfEmpty }.joined(separator: ", ").nilIfEmpty
            let grades = firstRegexCapture(pattern: #"<strong>Grades:</strong>(?:&nbsp;|\s)*([^<]+)<br />"#, in: html)?
                .htmlDecoded
                .replacingOccurrences(of: " to ", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let program = firstRegexCapture(pattern: #"<strong>Program:</strong>(?:&nbsp;|\s)*([^<]+)</div>"#, in: html)?
                .htmlDecoded
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let division = firstRegexCapture(pattern: #"<div class="sc_div">\s*([^<]+)</div>"#, in: html)?
                .htmlDecoded
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return SchoolDirectoryInfo(name: name, address: fullAddress, grades: grades?.nilIfEmpty, division: division?.nilIfEmpty, program: program?.nilIfEmpty)
        } catch {
            return nil
        }
    }

    private func geocodeSchoolAddresses(_ addresses: [String]) async -> [String: CLLocationCoordinate2D] {
        guard let dataset = datasets.assessment else { return [:] }
        let keys = Set(addresses.map(addressSearchKey).filter { !$0.isEmpty })
        var byStreet: [String: Set<String>] = [:]
        for key in keys {
            let parts = key.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            byStreet[String(parts[1]), default: []].insert(String(parts[0]))
        }

        var result: [String: CLLocationCoordinate2D] = [:]
        await withTaskGroup(of: [(String, CLLocationCoordinate2D)].self) { group in
            for (street, nums) in byStreet {
                let numList = nums.map { "'\($0)'" }.joined(separator: ",")
                let token = escaped(street)
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    let rows = (try? await self.fetch(dataset, queryItems: [
                        URLQueryItem(name: "$select", value: "street_number,street_name,centroid_lat,centroid_lon,geometry"),
                        URLQueryItem(name: "$where", value: "upper(street_name)='\(token)' AND street_number in (\(numList))"),
                        URLQueryItem(name: "$limit", value: "50")
                    ])) ?? []
                    return rows.compactMap { row -> (String, CLLocationCoordinate2D)? in
                        guard let number = row.string("street_number"),
                              let coordinate = self.parseCoordinate(row) else { return nil }
                        return ("\(number) \(street)", coordinate)
                    }
                }
            }

            for await pairs in group {
                for (key, coordinate) in pairs where result[key] == nil {
                    result[key] = coordinate
                }
            }
        }
        return result
    }

    private func schoolDirectorySearchTerms(for name: String) -> [String] {
        var terms: [String] = []
        func append(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !terms.contains(trimmed) { terms.append(trimmed) }
        }

        append(name)
        let withoutParenthetical = name
            .replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        append(withoutParenthetical)
        append(withoutParenthetical.replacingOccurrences(of: "Savior", with: "Saviour", options: [.caseInsensitive]))
        append(withoutParenthetical.replacingOccurrences(of: "Saviour", with: "Savior", options: [.caseInsensitive]))
        return terms
    }

    private func addressSearchKey(_ address: String) -> String {
        let firstLine = address.split(separator: ",", maxSplits: 1).first.map(String.init) ?? address
        let parts = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, Int(parts[0]) != nil else { return "" }
        let street = streetCore(String(parts[1]))
        guard !street.isEmpty else { return "" }
        return "\(parts[0]) \(street)"
    }

    private func normalizedSchoolName(_ value: String) -> String {
        value.htmlDecoded
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_CA"))
            .replacingOccurrences(of: #"(?i)^ecole\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scoreSchoolDirectoryMatch(_ info: SchoolDirectoryInfo, schoolName: String, street: String) -> Int {
        let candidateName = normalizedSchoolName(info.name)
        var score = 0
        if candidateName == schoolName { score += 100 }
        if candidateName.contains(schoolName) || schoolName.contains(candidateName) { score += 30 }
        if let address = info.address, streetCore(address) == street { score += 25 }
        if info.address?.localizedCaseInsensitiveContains("Winnipeg") == true { score += 10 }
        if info.division?.localizedCaseInsensitiveContains("Winnipeg") == true { score += 10 }
        return score
    }

    private func formEncoded(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func firstRegexCapture(pattern: String, in text: String) -> String? {
        regexCaptures(pattern: pattern, in: text).first
    }

    private func regexCaptures(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[captureRange])
        }
    }

    private func fetchCivicContext(address: NormalizedAddress, property: PropertyAssessment?) async -> AddressCivicContext? {
        // Ward / neighbourhood / school division come from the Addresses dataset; postal code
        // and plow zone are NOT columns there, so they are sourced separately (snow-route
        // address dataset for postal code, plow-zone polygons for the zone).
        async let addressRow = fetchCivicAddressRow(address: address, property: property)
        async let postal = fetchPostalCode(address: address)
        async let plow = fetchPlowZone(coordinate: property?.coordinate)

        let row = await addressRow
        let postalCode = await postal
        let plowZone = await plow

        guard row != nil || postalCode != nil || plowZone != nil else { return nil }

        let schoolDivision = row?.string("school_division")
        let divisionInfo = await fetchSchoolDivisionInfo(named: schoolDivision)
        return AddressCivicContext(
            addressID: row?.string("address_id"),
            ward: row?.string("ward"),
            neighbourhood: row?.string("neighbourhood"),
            postalCode: postalCode,
            plowZone: plowZone,
            schoolDivision: schoolDivision,
            schoolDivisionBoundaryName: divisionInfo?.name,
            schoolDivisionCode: divisionInfo?.code,
            schoolDivisionWard: row?.string("school_division_ward"),
            schoolDivisionWebsite: divisionInfo?.website
        )
    }

    private func fetchCivicAddressRow(address: NormalizedAddress, property: PropertyAssessment?) async -> [String: Any]? {
        guard let dataset = datasets.addresses else { return nil }
        let select = "full_address,ward,neighbourhood,school_division,school_division_ward"
        var rows: [[String: Any]] = []

        if let fullAddress = property?.fullAddress, !fullAddress.isEmpty {
            rows = (try? await fetch(dataset, queryItems: [
                URLQueryItem(name: "$select", value: select),
                URLQueryItem(name: "$where", value: "upper(full_address)='\(escaped(fullAddress.uppercased()))'"),
                URLQueryItem(name: "$limit", value: "1")
            ])) ?? []
        }

        if rows.isEmpty, let civic = address.civicNumber {
            // The Addresses dataset stores `street_name` WITHOUT the street type (e.g. "ARNOLD",
            // not "ARNOLD AVE"), so the assessment's full_address ("196 ARNOLD AVENUE") never
            // matches above. Match on the bare street core first, then fall back to the full
            // street-name variants for the rare dataset that keeps the type.
            var streetTokens = Set(addressNormalizer.streetVariants(for: address).map { $0.uppercased() })
            let core = streetCore(address.streetName)
            if !core.isEmpty { streetTokens.insert(core) }
            let streetClauses = streetTokens
                .map { "upper(street_name)='\(escaped($0))'" }
                .joined(separator: " OR ")
            if !streetClauses.isEmpty {
                rows = (try? await fetch(dataset, queryItems: [
                    URLQueryItem(name: "$select", value: select),
                    URLQueryItem(name: "$where", value: "street_number='\(civic)' AND (\(streetClauses))"),
                    URLQueryItem(name: "$limit", value: "1")
                ])) ?? []
            }
        }

        return rows.first
    }

    private func fetchPostalCode(address: NormalizedAddress) async -> String? {
        guard let dataset = datasets.snowRouteAddresses,
              let civic = address.civicNumber else { return nil }
        // In the snow-route dataset street_name excludes the type (e.g. "SOLSTICE", not
        // "SOLSTICE LANE"), so match on the street core.
        let token = escaped(streetCore(address.streetName))
        guard !token.isEmpty else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "postal_code"),
            URLQueryItem(name: "$where", value: "address_number='\(civic)' AND upper(street_name)='\(token)' AND postal_code IS NOT NULL"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        return rows.first?.string("postal_code")
    }

    private func fetchPlowZone(coordinate: CLLocationCoordinate2D?) async -> String? {
        guard let dataset = datasets.plowZones, let coordinate else { return nil }
        let point = "POINT (\(coordinate.longitude) \(coordinate.latitude))"
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "plow_zone,city_area"),
            URLQueryItem(name: "$where", value: "intersects(the_geom,'\(point)')"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first, let zone = row.string("plow_zone") else { return nil }
        if let area = row.string("city_area"), !area.isEmpty {
            return "\(zone) · \(area)"
        }
        return zone
    }

    private func fetchSchoolDivisionInfo(named name: String?) async -> SchoolDivisionBoundaryInfo? {
        guard let dataset = datasets.schoolDivisions,
              let name,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let token = escaped(name.uppercased())
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "name,division,website"),
            URLQueryItem(name: "$where", value: "upper(name)='\(token)' OR upper(division)='\(token)'"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first else { return nil }
        return SchoolDivisionBoundaryInfo(
            name: row.string("name"),
            code: row.string("division"),
            website: row.string("website")
        )
    }

    private func fetchShortTermRentals(address: NormalizedAddress, streetCores: [String]) async -> ShortTermRentalSummary? {
        guard let dataset = datasets.shortTermRentals else { return nil }
        let cores = limitedStreetCores(streetCores, limit: 8)
        let streetClauses = cores
            .map { "upper(short_term_rental_accommodation_address) like '%\(escaped($0))%'" }
            .joined(separator: " OR ")
        guard !streetClauses.isEmpty else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "primary_non_primary,short_term_rental_accommodation_address,date_licence_was_issued,electoral_ward"),
            URLQueryItem(name: "$where", value: "(\(streetClauses))"),
            URLQueryItem(name: "$order", value: "date_licence_was_issued DESC"),
            URLQueryItem(name: "$limit", value: "100")
        ])) ?? []
        guard !rows.isEmpty else { return nil }

        let records = rows.map { row in
            ShortTermRentalRecord(
                address: row.string("short_term_rental_accommodation_address") ?? "Address unavailable",
                primaryStatus: row.string("primary_non_primary"),
                issuedDate: parseDate(row.string("date_licence_was_issued")),
                ward: row.string("electoral_ward")
            )
        }
        let nonPrimary = records.filter { ($0.primaryStatus ?? "").localizedCaseInsensitiveContains("non") }.count
        let primary = records.filter {
            let status = $0.primaryStatus ?? ""
            return status.localizedCaseInsensitiveContains("primary") && !status.localizedCaseInsensitiveContains("non")
        }.count

        return ShortTermRentalSummary(
            total: records.count,
            primaryCount: primary,
            nonPrimaryCount: nonPrimary,
            recent: Array(records.prefix(8))
        )
    }

    private func fetchRecreation(property: PropertyAssessment?) async -> RecreationSummary? {
        async let complexesTask = fetchNearbyRecreationComplexes(property: property)
        async let centresTask = fetchNearbyCommunityCentres(property: property)
        let complexes = await complexesTask
        let communityCentres = await centresTask
        let activities = await fetchLeisureActivities(for: complexes)
        if complexes.isEmpty && activities.isEmpty && communityCentres.isEmpty { return nil }
        return RecreationSummary(nearestComplex: complexes.first, complexes: complexes, activities: activities, communityCentres: communityCentres)
    }

    private func fetchNearbyRecreationComplexes(property: PropertyAssessment?, limit: Int = 8) async -> [RecreationComplex] {
        guard let dataset = datasets.recreationComplexes,
              let subject = property?.coordinate else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "complex_name,address,location_1_geom,skate_park,fitness_leisure_centre,outdoor_pool,indoor_pool,arena,community_centre,wading_pool,library,indoor_soccer,spray_pad"),
            URLQueryItem(name: "$where", value: "within_circle(location_1_geom,\(subject.latitude),\(subject.longitude),5000)"),
            URLQueryItem(name: "$limit", value: "80")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        return rows.compactMap { row -> (RecreationComplex, Double)? in
            guard let name = row.string("complex_name"),
                  let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            let amenities: [(String, String)] = [
                ("Arena", "arena"),
                ("Community centre", "community_centre"),
                ("Fitness", "fitness_leisure_centre"),
                ("Indoor pool", "indoor_pool"),
                ("Outdoor pool", "outdoor_pool"),
                ("Wading pool", "wading_pool"),
                ("Spray pad", "spray_pad"),
                ("Skate park", "skate_park"),
                ("Indoor soccer", "indoor_soccer"),
                ("Library", "library")
            ]
            let enabled = amenities.compactMap { label, key in row.bool(key) ? label : nil }
            return (
                RecreationComplex(
                    name: name,
                    address: row.string("address"),
                    distanceDescription: distanceDescription(meters: distance),
                    amenities: enabled,
                    coordinate: coordinate
                ),
                distance
            )
        }
        .sorted { $0.1 < $1.1 }
        .prefix(limit)
        .map(\.0)
    }

    private func fetchNearbyCommunityCentres(property: PropertyAssessment?, limit: Int = 5) async -> [CommunityCentre] {
        guard let dataset = datasets.recreationComplexes,
              let subject = property?.coordinate else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "complex_name,address,location_1_geom"),
            URLQueryItem(name: "$where", value: "within_circle(location_1_geom,\(subject.latitude),\(subject.longitude),3000) AND community_centre=true"),
            URLQueryItem(name: "$limit", value: "80")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        return rows.compactMap { row -> (CommunityCentre, Double)? in
            guard let name = row.string("complex_name"),
                  let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            return (
                CommunityCentre(
                    name: name,
                    address: row.string("address"),
                    distanceDescription: distanceDescription(meters: distance),
                    coordinate: coordinate
                ),
                distance
            )
        }
        .sorted { $0.1 < $1.1 }
        .prefix(limit)
        .map(\.0)
    }

    private func fetchLeisureActivities(for complexes: [RecreationComplex]) async -> [RecreationActivity] {
        guard let dataset = datasets.leisureActivities else { return [] }
        let placeNames = Array(Set(complexes.map(\.name).filter { !$0.isEmpty }).prefix(6))
        guard !placeNames.isEmpty else { return [] }
        let placeList = placeNames.map { "'\(escaped($0.uppercased()))'" }.joined(separator: ",")
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "activity_name,place_name,category,activity_type,activity_status,default_beginning_date,default_ending_date,open_spaces,public_url"),
            URLQueryItem(name: "$where", value: "upper(place_name) in (\(placeList)) AND default_beginning_date >= '\(yearOffset(0))-01-01T00:00:00'"),
            URLQueryItem(name: "$order", value: "default_beginning_date ASC"),
            URLQueryItem(name: "$limit", value: "24")
        ])) ?? []
        return rows.compactMap { row in
            guard let name = row.string("activity_name") else { return nil }
            return RecreationActivity(
                name: name,
                placeName: row.string("place_name"),
                category: row.string("category"),
                activityType: row.string("activity_type"),
                status: row.string("activity_status"),
                startDate: parseDate(row.string("default_beginning_date")),
                endDate: parseDate(row.string("default_ending_date")),
                openSpaces: row.string("open_spaces"),
                publicURL: row.string("public_url")
            )
        }
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
        // Index-friendly Title-Case match instead of upper() — the 311 dataset is large and the
        // full-scan version risks the request timeout (see properCaseNeighbourhood / fetchEmergency).
        let trimmed = neighbourhood.trimmingCharacters(in: .whitespacesAndNewlines)
        return "neighbourhood='\(escaped(properCaseNeighbourhood(trimmed)))'"
    }

    private func fetchPlanningContext(property: PropertyAssessment?) async -> PlanningContextSummary? {
        guard let property else { return nil }
        async let zoning = fetchZoningDescription(zoningCode: property.zoning)
        async let notices = fetchPublicNotices(property: property)
        let zoningInfo = await zoning
        let publicNotices = await notices
        if property.zoning == nil && zoningInfo.short == nil && zoningInfo.long == nil && publicNotices.isEmpty { return nil }
        return PlanningContextSummary(
            zoningCode: property.zoning,
            zoningDescription: zoningInfo.short ?? zoningInfo.long,
            zoningIntent: zoningInfo.long,
            publicNotices: publicNotices
        )
    }

    private func fetchZoningDescription(zoningCode: String?) async -> (short: String?, long: String?) {
        guard let dataset = datasets.zoningParcels,
              let zoningCode,
              !zoningCode.isEmpty else { return (nil, nil) }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "short_description,long_description"),
            URLQueryItem(name: "$where", value: "upper(zoning)='\(escaped(zoningCode.uppercased()))'"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        let short = rows.first?.string("short_description")
        let long = rows.first?.string("long_description")
        // Don't repeat the same text in both slots — the card shows them separately.
        return (short, long == short ? nil : long)
    }

    private func fetchPublicNotices(property: PropertyAssessment) async -> [PublicNotice] {
        guard let dataset = datasets.publicNotices,
              let subject = property.coordinate else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "notice_type,address,description,decision,meeting_date,point"),
            URLQueryItem(name: "$where", value: "within_circle(point,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters)))"),
            URLQueryItem(name: "$order", value: "meeting_date DESC"),
            URLQueryItem(name: "$limit", value: "20")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        return rows.compactMap { row -> (PublicNotice, Double)? in
            guard let noticeType = row.string("notice_type") else { return nil }
            guard let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            return (PublicNotice(
                noticeType: noticeType,
                address: row.string("address") ?? "Address unavailable",
                description: plainText(row.string("description") ?? row.string("plain_language")),
                decision: row.string("decision"),
                meetingDate: parseDate(row.string("meeting_date")),
                distanceDescription: distanceDescription(meters: distance),
                coordinate: coordinate
            ), distance)
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
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
           pavementSummary.surface == nil,
           pavementSummary.roadType == nil,
           schoolSpeedLimit == nil,
           cyclingCount == 0,
           activeDisruptions.isEmpty,
           activeClosures.isEmpty {
            return nil
        }

        return StreetAccessSummary(
            pavementCondition: pavementSummary.condition,
            pavementSurface: pavementSummary.surface,
            roadType: pavementSummary.roadType,
            schoolSpeedLimit: schoolSpeedLimit,
            cyclingRoutesNearby: cyclingCount,
            activeDisruptions: activeDisruptions,
            activeLaneClosures: activeClosures
        )
    }

    private func fetchPavementCondition(_ address: NormalizedAddress) async -> (condition: String?, surface: String?, roadType: String?) {
        guard let dataset = datasets.pavementCondition else { return (nil, nil, nil) }
        let token = escaped(streetCore(address.streetName))
        guard !token.isEmpty else { return (nil, nil, nil) }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "general_condition,surface_type"),
            URLQueryItem(name: "$where", value: "upper(street_name) like '\(token)%'"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        return (rows.first?.string("general_condition"), rows.first?.string("surface_type"), nil)
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
              let school = row.string("school")?.repairedFrenchCivicName else { return nil }
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
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters)))")
        ])) ?? []
        return rows.first?.int("cnt") ?? 0
    }

    private func fetchAccessibilityDisruptions(property: PropertyAssessment?) async -> [StreetDisruption] {
        guard let dataset = datasets.accessibilityDisruptions,
              let subject = property?.coordinate else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "title,description,category,subcategory,status,start_date,end_date,location_point"),
            URLQueryItem(name: "$where", value: "within_circle(location_point,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters))) AND (status IS NULL OR upper(status) != 'CLOSED')"),
            URLQueryItem(name: "$order", value: "start_date DESC"),
            URLQueryItem(name: "$limit", value: "10")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        return rows.compactMap { row -> (StreetDisruption, Double)? in
            guard let title = row.string("title") else { return nil }
            guard let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            let detail = [row.string("category"), row.string("subcategory"), row.string("description")]
                .compactMap { plainText($0) }
                .joined(separator: " · ")
            return (StreetDisruption(
                title: title,
                detail: detail.isEmpty ? nil : detail,
                status: row.string("status"),
                startDate: parseDate(row.string("start_date")),
                endDate: parseDate(row.string("end_date")),
                distanceDescription: distanceDescription(meters: distance),
                coordinate: coordinate
            ), distance)
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
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
        // Match the index-friendly Title-Case spelling instead of wrapping the column in
        // upper() — see properCaseNeighbourhood. The full-scan version timed out for WFPS.
        let neighName = escaped(properCaseNeighbourhood(neighbourhood))
        let neighClause = "neighbourhood='\(neighName)'"
        let timeField = "call_time"
        let sixYearClause = "\(neighClause) AND \(timeField) >= '\(yearOffset(-6))-01-01T00:00:00'"
        let lastYearStart = yearOffset(-1)
        let twoYearStart = yearOffset(-2)

        async let citywideYearRows = fetchEmergencyCitywideYearRows(dataset: dataset, timeField: timeField, startYear: yearOffset(-6))

        // Socrata-side grouping on the WFPS dataset is slow enough to hit the app's
        // 10-second request timeout for ordinary neighbourhoods like Lord Roberts.
        // Pull the indexed neighbourhood slice once and aggregate locally instead.
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "incident_number,incident_type,call_time,closed_time,motor_vehicle_incident,units,ward"),
            URLQueryItem(name: "$where", value: sixYearClause),
            URLQueryItem(name: "$order", value: "\(timeField) DESC"),
            URLQueryItem(name: "$limit", value: "50000")
        ])) ?? []

        let incidents = rows.compactMap { row -> EmergencyIncidentRecord? in
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

        var yearlyCounts: [Int: Int] = [:]
        var monthlyCounts: [String: (year: Int, month: Int, count: Int)] = [:]
        var typeCounts: [String: Int] = [:]
        var typeCountsByYear: [Int: [String: Int]] = [:]
        var wardCounts: [String: Int] = [:]
        var motorVehicleCounts: [String: Int] = [:]
        let calendar = Calendar(identifier: .gregorian)

        for incident in incidents {
            guard let callTime = incident.callTime else { continue }
            let year = calendar.component(.year, from: callTime)
            let month = calendar.component(.month, from: callTime)
            yearlyCounts[year, default: 0] += 1
            typeCountsByYear[year, default: [:]][incident.incidentType, default: 0] += 1

            if year >= twoYearStart {
                let key = "\(year)-\(month)"
                var current = monthlyCounts[key] ?? (year, month, 0)
                current.count += 1
                monthlyCounts[key] = current
            }

            guard year >= lastYearStart else { continue }
            typeCounts[incident.incidentType, default: 0] += 1
            if let ward = incident.ward, !ward.isEmpty {
                wardCounts[ward, default: 0] += 1
            }
            if let flag = incident.motorVehicleIncident, !flag.isEmpty {
                motorVehicleCounts[flag, default: 0] += 1
            }
        }

        var citywideCountsByYear: [Int: [Int]] = [:]
        for row in await citywideYearRows {
            guard let year = row.int("year"), let count = row.int("cnt") else { continue }
            citywideCountsByYear[year, default: []].append(count)
        }

        let recentIncidents = Array(incidents.prefix(8))
        let durations = incidents.compactMap(\.durationMinutes).filter { $0 > 0 && $0 < 24 * 60 }
        let averageDuration = durations.isEmpty ? nil : Double(durations.reduce(0, +)) / Double(durations.count)
        let unitBreakdown = emergencyUnitBreakdown(from: recentIncidents)
        let totalLastYear = typeCounts.values.reduce(0, +)
        let motorVehicleLastYear = motorVehicleCounts
            .filter { $0.key.localizedCaseInsensitiveContains("yes") }
            .map(\.value)
            .reduce(0, +)

        return EmergencySummary(
            neighbourhood: neighbourhood,
            totalLastYear: totalLastYear,
            motorVehicleLastYear: motorVehicleLastYear,
            averageDurationMinutes: averageDuration,
            yearlyCalls: yearlyCounts
                .map { year, count in
                    let cityCounts = citywideCountsByYear[year] ?? []
                    let citywideAverage = cityCounts.isEmpty ? 0 : Double(cityCounts.reduce(0, +)) / Double(cityCounts.count)
                    return YearCount(year: year, count: count, citywideAverage: citywideAverage)
                }
                .sorted { $0.year < $1.year },
            monthlyTrend: monthlyCounts.values
                .map { EmergencyMonth(year: $0.year, month: $0.month, count: $0.count) }
                .sorted { $0.year == $1.year ? $0.month < $1.month : $0.year < $1.year },
            last12Months: typeCounts
                .map { IncidentBreakdown(incidentType: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
                .prefix(12)
                .map { $0 },
            breakdownByYear: typeCountsByYear.mapValues { counts in
                counts
                    .map { IncidentBreakdown(incidentType: $0.key, count: $0.value) }
                    .sorted { $0.count > $1.count }
            },
            wardBreakdown: wardCounts
                .map { IncidentBreakdown(incidentType: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
                .prefix(8)
                .map { $0 },
            motorVehicleBreakdown: motorVehicleCounts
                .map { IncidentBreakdown(incidentType: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count },
            unitBreakdown: unitBreakdown,
            recentIncidents: recentIncidents,
            citywideMedian: nil,
            neighbourhoodRank: nil,
            neighbourhoodCount: nil
        )
    }

    private func fetchEmergencyCitywideYearRows(dataset: String, timeField: String, startYear: Int) async -> [[String: Any]] {
        (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(\(timeField)) as year, neighbourhood, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "\(timeField) >= '\(startYear)-01-01T00:00:00' AND neighbourhood IS NOT NULL"),
            URLQueryItem(name: "$group", value: "year, neighbourhood"),
            URLQueryItem(name: "$order", value: "year"),
            URLQueryItem(name: "$limit", value: "50000")
        ])) ?? []
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
            // City-wide totals per type (across all neighbourhoods) used to derive a per-type average.
            var cityCrimeTypes: [String: Int] = [:]
            var cityCrimeTypesByYear: [Int: [String: Int]] = [:]
            var cityOffenceTypes: [String: Int] = [:]
            var cityOffenceTypesByYear: [Int: [String: Int]] = [:]
            var cityNeighbourhoods: Set<String> = []
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
                cityNeighbourhoods.insert(rowNeighbourhood)
                let rowMonth = PoliceCrimeMonth(year: year, month: month)
                if latestMonth == nil || year > latestMonth!.year || (year == latestMonth!.year && month > latestMonth!.month) {
                    latestMonth = rowMonth
                }

                let crimeType = columns[5].trimmingCharacters(in: .whitespacesAndNewlines)
                let offenceType = columns[6].trimmingCharacters(in: .whitespacesAndNewlines)

                if !crimeType.isEmpty {
                    cityCrimeTypes[crimeType, default: 0] += count
                    cityCrimeTypesByYear[year, default: [:]][crimeType, default: 0] += count
                }
                if !offenceType.isEmpty {
                    cityOffenceTypes[offenceType, default: 0] += count
                    cityOffenceTypesByYear[year, default: [:]][offenceType, default: 0] += count
                }

                guard neighbourhoodName(rowNeighbourhood, matches: neighbourhood) else { continue }
                yearlyNeighbourhood[year, default: 0] += count

                if !crimeType.isEmpty {
                    crimeTypes[crimeType, default: 0] += count
                    crimeTypesByYear[year, default: [:]][crimeType, default: 0] += count
                }
                if !offenceType.isEmpty {
                    offenceTypes[offenceType, default: 0] += count
                    offenceTypesByYear[year, default: [:]][offenceType, default: 0] += count
                }
            }

            let years = Set(yearlyNeighbourhood.keys).union(yearlyCityNeighbourhoods.keys).sorted()
            let allNeighbourhoodCount = cityNeighbourhoods.count
            let yearlyCounts = years.map { year in
                let cityTotal = yearlyCityNeighbourhoods[year]?.values.reduce(0, +) ?? 0
                let average = allNeighbourhoodCount > 0 ? Double(cityTotal) / Double(allNeighbourhoodCount) : 0
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
                crimeTypes: incidentBreakdowns(from: crimeTypes,
                                               cityTotals: cityCrimeTypes,
                                               neighbourhoodCount: allNeighbourhoodCount),
                crimeTypesByYear: crimeTypesByYear.reduce(into: [:]) { result, entry in
                    let (year, counts) = entry
                    result[year] = incidentBreakdowns(from: counts,
                                                      cityTotals: cityCrimeTypesByYear[year] ?? [:],
                                                      neighbourhoodCount: allNeighbourhoodCount)
                },
                offenceTypes: incidentBreakdowns(from: offenceTypes,
                                                 cityTotals: cityOffenceTypes,
                                                 neighbourhoodCount: allNeighbourhoodCount),
                offenceTypesByYear: offenceTypesByYear.reduce(into: [:]) { result, entry in
                    let (year, counts) = entry
                    result[year] = incidentBreakdowns(from: counts,
                                                      cityTotals: cityOffenceTypesByYear[year] ?? [:],
                                                      neighbourhoodCount: allNeighbourhoodCount)
                }
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

    /// Builds breakdowns annotated with the city-wide average count per neighbourhood for each type.
    private func incidentBreakdowns(from counts: [String: Int],
                                    cityTotals: [String: Int],
                                    neighbourhoodCount: Int) -> [IncidentBreakdown] {
        counts
            .map { type, count in
                let average = neighbourhoodCount > 0
                    ? Double(cityTotals[type] ?? 0) / Double(neighbourhoodCount)
                    : 0
                return IncidentBreakdown(incidentType: type, count: count, citywideAverage: average)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.incidentType < rhs.incidentType }
                return lhs.count > rhs.count
            }
    }

    private func neighbourhoodName(_ lhs: String, matches rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(rhs.trimmingCharacters(in: .whitespacesAndNewlines), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private func fetchPublicHealth(neighbourhood: String?, coordinate: CLLocationCoordinate2D? = nil) async -> PublicHealthSummary? {
        guard let dataset = datasets.naloxone else { return nil }
        let substanceDataset = datasets.substanceUse
        let citywideNeighbourhoodYears = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "date_extract_y(dispatch_date) as year, neighbourhood, count(*) as cnt"),
            URLQueryItem(name: "$where", value: "dispatch_date >= '\(yearOffset(-6))-01-01T00:00:00' AND neighbourhood IS NOT NULL"),
            URLQueryItem(name: "$group", value: "year, neighbourhood"),
            URLQueryItem(name: "$order", value: "year"),
            URLQueryItem(name: "$limit", value: "50000")
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
        let citySubstances: [[String: Any]]
        let citySubstancesByYearRows: [[String: Any]]
        let citySubstanceNeighbourhoodCount: Int
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
            citySubstances = (try? await fetch(substanceDataset, queryItems: [
                URLQueryItem(name: "$select", value: "substance, count(*) as cnt"),
                URLQueryItem(name: "$where", value: "dispatch_date >= '\(yearOffset(-6))-01-01T00:00:00' AND substance IS NOT NULL AND neighbourhood IS NOT NULL"),
                URLQueryItem(name: "$group", value: "substance")
            ])) ?? []
            citySubstancesByYearRows = (try? await fetch(substanceDataset, queryItems: [
                URLQueryItem(name: "$select", value: "date_extract_y(dispatch_date) as year, substance, count(*) as cnt"),
                URLQueryItem(name: "$where", value: "dispatch_date >= '\(yearOffset(-6))-01-01T00:00:00' AND substance IS NOT NULL AND neighbourhood IS NOT NULL"),
                URLQueryItem(name: "$group", value: "year, substance")
            ])) ?? []
            let citySubstanceNeighbourhoodRows = (try? await fetch(substanceDataset, queryItems: [
                URLQueryItem(name: "$select", value: "count(distinct neighbourhood) as nbh"),
                URLQueryItem(name: "$where", value: "dispatch_date >= '\(yearOffset(-6))-01-01T00:00:00' AND substance IS NOT NULL AND neighbourhood IS NOT NULL")
            ])) ?? []
            citySubstanceNeighbourhoodCount = citySubstanceNeighbourhoodRows.first.flatMap { $0.int("nbh") } ?? 0
        } else {
            substances = []
            substancesByYearRows = []
            citySubstances = []
            citySubstancesByYearRows = []
            citySubstanceNeighbourhoodCount = 0
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
        var citySubstanceTotals: [String: Int] = [:]
        for row in citySubstances {
            guard let substance = row.string("substance"), let count = row.int("cnt") else { continue }
            citySubstanceTotals[substance] = count
        }
        var citySubstanceTotalsByYear: [Int: [String: Int]] = [:]
        for row in citySubstancesByYearRows {
            guard let year = row.int("year"),
                  let substance = row.string("substance"),
                  let count = row.int("cnt") else { continue }
            citySubstanceTotalsByYear[year, default: [:]][substance] = count
        }
        func cityAvgForSubstance(_ substance: String) -> Double {
            citySubstanceNeighbourhoodCount > 0
                ? Double(citySubstanceTotals[substance] ?? 0) / Double(citySubstanceNeighbourhoodCount)
                : 0
        }
        func cityAvgForSubstance(_ substance: String, year: Int) -> Double {
            citySubstanceNeighbourhoodCount > 0
                ? Double(citySubstanceTotalsByYear[year]?[substance] ?? 0) / Double(citySubstanceNeighbourhoodCount)
                : 0
        }
        async let erFacility = fetchNearestER(from: coordinate)
        async let walkInData = fetchNearestWalkIn(from: coordinate)
        async let aedData = fetchNearbyAEDs(from: coordinate)

        var summary = PublicHealthSummary(
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
                return IncidentBreakdown(incidentType: substance, count: count, citywideAverage: cityAvgForSubstance(substance))
            },
            substancesByYear: substancesByYear.reduce(into: [:]) { result, entry in
                let (year, items) = entry
                result[year] = items
                    .map { item in
                        IncidentBreakdown(
                            incidentType: item.incidentType,
                            count: item.count,
                            citywideAverage: cityAvgForSubstance(item.incidentType, year: year)
                        )
                    }
                    .sorted { $0.count > $1.count }
            }
        )
        var nearestER = await erFacility
        if let waitTime = await fetchWinnipegEmergencyWaitTime(for: nearestER?.name) {
            nearestER?.currentWaitMinutes = waitTime.waitMinutes
            nearestER?.avgWaitMinutes = waitTime.waitMinutes
            nearestER?.waitingPatients = waitTime.waitingPatients
            nearestER?.treatingPatients = waitTime.treatingPatients
            nearestER?.waitTimeUpdatedAt = waitTime.updatedAt
            nearestER?.waitTimeAttribution = "Emergency wait times from Winnipeg Regional Health Authority (wrha.mb.ca)."
        }
        summary.nearestER = nearestER
        let wid = await walkInData
        summary.nearestWalkIn = wid.facility
        summary.walkInClinicsNearby = wid.count
        let aeds = await aedData
        summary.nearestAED = aeds.nearest
        summary.aedsNearby = aeds.count
        if summary.yearlyEvents.isEmpty && summary.ageGroups.isEmpty && summary.substances.isEmpty && summary.nearestER == nil && summary.nearestWalkIn == nil && summary.nearestAED == nil { return nil }
        return summary
    }

    private func fetchNearbyAEDs(from coordinate: CLLocationCoordinate2D?) async -> (nearest: DefibrillatorAccess?, count: Int) {
        guard let dataset = datasets.publicAeds,
              let coordinate else { return (nil, 0) }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "name,location_description,access,indoor,source,location"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(coordinate.latitude),\(coordinate.longitude),500)"),
            URLQueryItem(name: "$limit", value: "50")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let matches = rows.compactMap { row -> (DefibrillatorAccess, Double)? in
            guard let aedCoordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: aedCoordinate.latitude, longitude: aedCoordinate.longitude).distance(from: subjectLocation)
            let access = row.string("access")
            return (
                DefibrillatorAccess(
                    name: row.string("name") ?? "Public AED",
                    locationDescription: row.string("location_description"),
                    access: access,
                    indoor: row.bool("indoor"),
                    distanceDescription: distanceDescription(meters: distance),
                    coordinate: aedCoordinate,
                    source: row.string("source")
                ),
                distance
            )
        }
        .sorted { $0.1 < $1.1 }
        return (matches.first?.0, matches.count)
    }

    private func fetchNearestER(from coordinate: CLLocationCoordinate2D?) async -> HealthFacilityAccess? {
        guard let coordinate else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "emergency room"
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 30000, longitudinalMeters: 30000)
        guard let results = try? await MKLocalSearch(request: request).start(),
              let nearest = nearestMapItem(to: coordinate, in: results.mapItems) else { return nil }
        let name = nearest.name ?? "Emergency Room"
        let number = nearest.placemark.subThoroughfare ?? ""
        let street = nearest.placemark.thoroughfare ?? ""
        let address: String? = street.isEmpty ? nil : "\(number) \(street)".trimmingCharacters(in: .whitespaces)
        let city = nearest.placemark.locality
        let province = nearest.placemark.administrativeArea
        let dirRequest = MKDirections.Request()
        dirRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        dirRequest.destination = nearest
        dirRequest.transportType = .automobile
        var driveMinutes: Double?
        if let eta = try? await MKDirections(request: dirRequest).calculateETA() {
            driveMinutes = eta.expectedTravelTime / 60
        }
        return HealthFacilityAccess(name: name, address: address, city: city, province: province, driveMinutes: driveMinutes)
    }

    private func fetchWinnipegEmergencyWaitTime(for facilityName: String?) async -> WRHAEmergencyWaitTime? {
        do {
            let waitTimes = try await WRHAWaitTimesClient().emergencyWaitTimes()
            return matchWinnipegEmergencyWaitTime(for: facilityName, waitTimes: waitTimes)
        } catch {
            return nil
        }
    }

    private func matchWinnipegEmergencyWaitTime(for facilityName: String?, waitTimes: [WRHAEmergencyWaitTime]) -> WRHAEmergencyWaitTime? {
        guard let facilityName else { return nil }
        let normalizedTarget = normalizedFacilityName(facilityName)

        if normalizedTarget.contains("health sciences") || normalizedTarget == "hsc" {
            return waitTimes.first { $0.facilityName.localizedCaseInsensitiveContains("Adult") }
        }
        if normalizedTarget.contains("boniface") {
            return waitTimes.first { $0.facilityName.localizedCaseInsensitiveContains("Boniface") }
        }
        if normalizedTarget.contains("grace") {
            return waitTimes.first { $0.facilityName.localizedCaseInsensitiveContains("Grace") }
        }

        return waitTimes.first { waitTime in
            let normalizedWaitName = normalizedFacilityName(waitTime.facilityName)
            return normalizedTarget == normalizedWaitName
                || normalizedTarget.contains(normalizedWaitName)
                || normalizedWaitName.contains(normalizedTarget)
        }
    }

    private func normalizedFacilityName(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "hospital", with: "")
            .replacingOccurrences(of: "health centre", with: "")
            .replacingOccurrences(of: "health center", with: "")
            .replacingOccurrences(of: "emergency", with: "")
            .replacingOccurrences(of: "department", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fetchNearestWalkIn(from coordinate: CLLocationCoordinate2D?) async -> (facility: HealthFacilityAccess?, count: Int?) {
        guard let coordinate else { return (nil, nil) }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "walk-in clinic"
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000)
        guard let results = try? await MKLocalSearch(request: request).start() else { return (nil, nil) }
        let subjectLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let items = results.mapItems.sorted { lhs, rhs in
            let lhsDistance = lhs.placemark.location?.distance(from: subjectLocation) ?? .greatestFiniteMagnitude
            let rhsDistance = rhs.placemark.location?.distance(from: subjectLocation) ?? .greatestFiniteMagnitude
            return lhsDistance < rhsDistance
        }
        let count = items.isEmpty ? nil : items.count
        guard let nearest = items.first else { return (nil, count) }
        let name = nearest.name ?? "Walk-in Clinic"
        let number = nearest.placemark.subThoroughfare ?? ""
        let street = nearest.placemark.thoroughfare ?? ""
        let address: String? = street.isEmpty ? nil : "\(number) \(street)".trimmingCharacters(in: .whitespaces)
        let dirRequest = MKDirections.Request()
        dirRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        dirRequest.destination = nearest
        dirRequest.transportType = .automobile
        var driveMinutes: Double?
        if let eta = try? await MKDirections(request: dirRequest).calculateETA() {
            driveMinutes = eta.expectedTravelTime / 60
        }
        return (HealthFacilityAccess(name: name, address: address, city: nearest.placemark.locality, province: nearest.placemark.administrativeArea, driveMinutes: driveMinutes), count)
    }

    private func nearestMapItem(to coordinate: CLLocationCoordinate2D, in items: [MKMapItem]) -> MKMapItem? {
        let subjectLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return items.min { lhs, rhs in
            let lhsDistance = lhs.placemark.location?.distance(from: subjectLocation) ?? .greatestFiniteMagnitude
            let rhsDistance = rhs.placemark.location?.distance(from: subjectLocation) ?? .greatestFiniteMagnitude
            return lhsDistance < rhsDistance
        }
    }

    // MARK: - Waste collection & winter operations

    private func fetchWasteCollection(address: NormalizedAddress, property: PropertyAssessment?) async -> WasteCollectionSummary? {
        async let dayRow = fetchWasteRow(address: address, property: property)
        async let zone = fetchPlowZoneRaw(coordinate: property?.coordinate)
        async let ban = fetchActiveSnowBan()

        let row = await dayRow
        let plowZone = await zone
        let activeBan = await ban
        let nextWindow = await fetchNextPlowWindow(zone: plowZone)

        let garbage = row?.string("garbage_collection_day")
        let recycle = row?.string("recycle_collection_day")
        let yard = row?.string("yard_waste_collection_day")

        if garbage == nil && recycle == nil && yard == nil && plowZone == nil && activeBan == nil {
            return nil
        }
        return WasteCollectionSummary(
            garbageDay: garbage?.capitalized,
            recycleDay: recycle?.capitalized,
            yardWasteDay: yard?.capitalized,
            matchedAddress: row?.string("combined_address"),
            plowZone: plowZone,
            nextPlowWindow: nextWindow,
            activeSnowBan: activeBan
        )
    }

    private func fetchWasteRow(address: NormalizedAddress, property: PropertyAssessment?) async -> [String: Any]? {
        guard let dataset = datasets.wasteCollection else { return nil }
        if let full = property?.fullAddress, !full.isEmpty {
            let rows = (try? await fetch(dataset, queryItems: [
                URLQueryItem(name: "$where", value: "upper(combined_address)='\(escaped(full.uppercased()))'"),
                URLQueryItem(name: "$limit", value: "1")
            ])) ?? []
            if let row = rows.first { return row }
        }
        guard let civic = address.civicNumber else { return nil }
        let core = escaped(streetCore(address.streetName))
        guard !core.isEmpty else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: "upper(combined_address) like '\(civic) \(core)%'"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        return rows.first
    }

    private func fetchPlowZoneRaw(coordinate: CLLocationCoordinate2D?) async -> String? {
        guard let dataset = datasets.plowZones, let coordinate else { return nil }
        let point = "POINT (\(coordinate.longitude) \(coordinate.latitude))"
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "plow_zone"),
            URLQueryItem(name: "$where", value: "intersects(the_geom,'\(point)')"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        return rows.first?.string("plow_zone")
    }

    private func fetchNextPlowWindow(zone: String?) async -> String? {
        guard let dataset = datasets.plowZoneSchedule, let zone, !zone.isEmpty else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "shift_number,shift_start,shift_end,plow_zone"),
            URLQueryItem(name: "$where", value: "upper(plow_zone)='\(escaped(zone.uppercased()))' AND shift_end >= '\(isoNow())'"),
            URLQueryItem(name: "$order", value: "shift_start ASC"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first,
              let start = parseDate(row.string("shift_start")) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h a"
        return formatter.string(from: start)
    }

    private func fetchActiveSnowBan() async -> SnowBanInfo? {
        guard let dataset = datasets.snowParkingBans else { return nil }
        let now = isoNow()
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "description,ban_start,ban_end"),
            URLQueryItem(name: "$where", value: "ban_start <= '\(now)' AND (ban_end IS NULL OR ban_end >= '\(now)')"),
            URLQueryItem(name: "$order", value: "ban_start DESC"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first,
              let description = row.string("description") else { return nil }
        return SnowBanInfo(
            description: plainText(description) ?? description,
            start: parseDate(row.string("ban_start")),
            end: parseDate(row.string("ban_end"))
        )
    }

    // MARK: - Demographics

    private func fetchDemographics(address: NormalizedAddress, property: PropertyAssessment?) async -> DemographicsSummary? {
        guard property != nil || address.civicNumber != nil else { return nil }
        let civicRow = await fetchCivicAddressRow(address: address, property: property)
        for candidate in censusBoundaryCandidates(property: property, civicRow: civicRow) {
            if let summary = await fetchDemographics(candidate: candidate, coordinate: property?.coordinate) {
                return summary
            }
        }
        return nil
    }

    private func censusBoundaryCandidates(property: PropertyAssessment?, civicRow: [String: Any]?) -> [CensusBoundaryCandidate] {
        var candidates: [CensusBoundaryCandidate] = []
        var seen = Set<String>()

        func append(type: String, names: [String], displayName: String) {
            let normalizedNames = names
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !normalizedNames.isEmpty else { return }
            let key = "\(type)|\(normalizedNames.joined(separator: "|"))".uppercased()
            guard seen.insert(key).inserted else { return }
            candidates.append(CensusBoundaryCandidate(boundaryType: type, names: normalizedNames, displayName: displayName))
        }

        if let neighbourhood = property?.neighbourhood, !neighbourhood.isEmpty {
            append(type: "Neighbourhood", names: [neighbourhood], displayName: neighbourhood.capitalized)
        }
        if let neighbourhood = civicRow?.string("neighbourhood"), !neighbourhood.isEmpty {
            append(type: "Neighbourhood", names: [neighbourhood], displayName: neighbourhood.capitalized)
        }
        if let ward = civicRow?.string("ward"), !ward.isEmpty {
            append(type: "Ward", names: [ward, "\(ward) Ward"], displayName: "\(ward) Ward")
        }
        append(type: "City", names: ["City of Winnipeg"], displayName: "City of Winnipeg")
        return candidates
    }

    private func censusBoundaryClause(_ candidate: CensusBoundaryCandidate) -> String {
        let names = candidate.names
            .map { "upper(boundary_name)='\(escaped($0.uppercased()))'" }
            .joined(separator: " OR ")
        return "boundary_type='\(escaped(candidate.boundaryType))' AND (\(names))"
    }

    private func fetchDemographics(candidate: CensusBoundaryCandidate, coordinate: CLLocationCoordinate2D?) async -> DemographicsSummary? {
        let nClause = censusBoundaryClause(candidate)

        async let ageRows = fetchOptional(datasets.censusAge, [
            URLQueryItem(name: "$where", value: nClause),
            URLQueryItem(name: "$limit", value: "1")
        ])
        async let householdRows = fetchOptional(datasets.censusHouseholds, [
            URLQueryItem(name: "$select", value: "income_median,size_average_person,census_year"),
            URLQueryItem(name: "$where", value: nClause),
            URLQueryItem(name: "$order", value: "census_year DESC"),
            URLQueryItem(name: "$limit", value: "1")
        ])
        async let transportRows = fetchOptional(datasets.censusTransportMode, [
            URLQueryItem(name: "$select", value: "car_total,passenger_total,public_total,walk_total,bicycle_total,census_year"),
            URLQueryItem(name: "$where", value: nClause),
            URLQueryItem(name: "$order", value: "census_year DESC"),
            URLQueryItem(name: "$limit", value: "1")
        ])
        async let immigrationRows = fetchOptional(datasets.censusImmigration, [
            URLQueryItem(name: "$select", value: "born_total_immigrants,generation_total_population"),
            URLQueryItem(name: "$where", value: nClause),
            URLQueryItem(name: "$limit", value: "1")
        ])
        async let languageRow = fetchTopNonOfficialLanguage(clause: nClause)
        async let poverty = fetchPovertyInfo(coordinate: coordinate)

        let age = (await ageRows).first
        let household = (await householdRows).first
        let transport = (await transportRows).first
        let immigration = (await immigrationRows).first
        let topLanguage = await languageRow
        let povertyInfo = await poverty

        var children: Double?
        var seniors: Double?
        var population: Int?
        if let age {
            let total = age.double("age_total")
            population = age.int("age_total")
            let kids = [age.double("age_0_4_total"), age.double("age_5_9_total"), age.double("age_10_14_total")].compactMap { $0 }.reduce(0, +)
            let old = ["age_65_69_total", "age_70_74_total", "age_75_79_total", "age_80_84_total", "age_85_total"]
                .compactMap { age.double($0) }.reduce(0, +)
            if let total, total > 0 {
                children = kids / total * 100
                seniors = old / total * 100
            }
        }

        var commuteModes: [IncidentBreakdown] = []
        if let transport {
            let pairs: [(String, String)] = [
                ("Drive", "car_total"), ("Carpool", "passenger_total"),
                ("Transit", "public_total"), ("Walk", "walk_total"), ("Bicycle", "bicycle_total")
            ]
            commuteModes = pairs.compactMap { label, key in
                guard let count = transport.int(key), count > 0 else { return nil }
                return IncidentBreakdown(incidentType: label, count: count)
            }
        }

        var immigrantPercent: Double?
        if let immigration,
           let immigrants = immigration.double("born_total_immigrants"),
           let base = immigration.double("generation_total_population"), base > 0 {
            immigrantPercent = immigrants / base * 100
        }

        let hasData = population != nil || household?.double("income_median") != nil ||
            !commuteModes.isEmpty || immigrantPercent != nil || topLanguage != nil || povertyInfo != nil
        guard hasData else { return nil }

        return DemographicsSummary(
            boundaryName: candidate.displayName,
            totalPopulation: population,
            childrenPercent: children,
            seniorsPercent: seniors,
            medianHouseholdIncome: household?.double("income_median"),
            averageHouseholdSize: household?.double("size_average_person"),
            immigrantPercent: immigrantPercent,
            topNonOfficialLanguage: topLanguage,
            commuteModes: commuteModes,
            isHighPovertyArea: povertyInfo?.high,
            giniIndex: povertyInfo?.gini
        )
    }

    private func fetchTopNonOfficialLanguage(clause: String) async -> String? {
        guard let dataset = datasets.censusLanguage else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: clause),
            URLQueryItem(name: "$order", value: "census_year DESC"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first else { return nil }
        var best: (name: String, count: Int)?
        for (key, value) in row {
            guard key.hasPrefix("language2_"), key != "language2_total" else { continue }
            let count = Int((value as? String) ?? "") ?? (value as? Int) ?? 0
            if count > (best?.count ?? 0) {
                let name = key.replacingOccurrences(of: "language2_", with: "")
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
                best = (name, count)
            }
        }
        return best?.name
    }

    private func fetchPovertyInfo(coordinate: CLLocationCoordinate2D?) async -> (high: Bool?, gini: Double?)? {
        guard let dataset = datasets.higherPovertyAreas, let coordinate else { return nil }
        let point = "POINT (\(coordinate.longitude) \(coordinate.latitude))"
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "is_high_poverty_area,gini_index"),
            URLQueryItem(name: "$where", value: "intersects(location,'\(point)')"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first else { return nil }
        return (row.bool("is_high_poverty_area"), row.double("gini_index"))
    }

    // MARK: - Local government

    private func fetchLocalGovernment(address: NormalizedAddress, property: PropertyAssessment?) async -> LocalGovernmentSummary? {
        let coordinateSummary = await fetchLocalGovernment(coordinate: property?.coordinate)
        if coordinateSummary?.wardName != nil, coordinateSummary?.councillor != nil {
            return coordinateSummary
        }

        let civicRow = await fetchCivicAddressRow(address: address, property: property)
        let wardSummary = await fetchLocalGovernment(wardName: civicRow?.string("ward"))
        return mergeLocalGovernment(primary: coordinateSummary, fallback: wardSummary)
    }

    private func fetchLocalGovernment(coordinate: CLLocationCoordinate2D?) async -> LocalGovernmentSummary? {
        guard let coordinate else { return nil }
        let point = "POINT (\(coordinate.longitude) \(coordinate.latitude))"
        async let wardRows = fetchOptional(datasets.electoralWards, [
            URLQueryItem(name: "$select", value: "councillor,name,phone,website"),
            URLQueryItem(name: "$where", value: "intersects(the_geom,'\(point)')"),
            URLQueryItem(name: "$limit", value: "1")
        ])
        async let committeeRows = fetchOptional(datasets.communityCommittees, [
            URLQueryItem(name: "$select", value: "desc"),
            URLQueryItem(name: "$where", value: "intersects(the_geom,'\(point)')"),
            URLQueryItem(name: "$limit", value: "1")
        ])

        let ward = (await wardRows).first
        let committee = (await committeeRows).first
        guard ward != nil || committee != nil else { return nil }
        return LocalGovernmentSummary(
            wardName: ward?.string("name"),
            councillor: ward?.string("councillor"),
            councillorPhone: ward?.string("phone"),
            councillorWebsite: ward?.string("website"),
            communityCommittee: committee?.string("desc")
        )
    }

    private func fetchLocalGovernment(wardName: String?) async -> LocalGovernmentSummary? {
        guard let wardName = wardName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !wardName.isEmpty else { return nil }
        let rows = await fetchOptional(datasets.electoralWards, [
            URLQueryItem(name: "$select", value: "councillor,name,phone,website"),
            URLQueryItem(name: "$where", value: "upper(name)='\(escaped(wardName.uppercased()))'"),
            URLQueryItem(name: "$limit", value: "1")
        ])
        guard let ward = rows.first else { return nil }
        return LocalGovernmentSummary(
            wardName: ward.string("name"),
            councillor: ward.string("councillor"),
            councillorPhone: ward.string("phone"),
            councillorWebsite: ward.string("website")
        )
    }

    private func mergeLocalGovernment(primary: LocalGovernmentSummary?, fallback: LocalGovernmentSummary?) -> LocalGovernmentSummary? {
        guard primary != nil || fallback != nil else { return nil }
        return LocalGovernmentSummary(
            wardName: primary?.wardName ?? fallback?.wardName,
            councillor: primary?.councillor ?? fallback?.councillor,
            councillorPhone: primary?.councillorPhone ?? fallback?.councillorPhone,
            councillorWebsite: primary?.councillorWebsite ?? fallback?.councillorWebsite,
            communityCommittee: primary?.communityCommittee ?? fallback?.communityCommittee
        )
    }

    // MARK: - Local businesses

    private func fetchLocalBusiness(property: PropertyAssessment?) async -> LocalBusinessSummary? {
        guard let subject = property?.coordinate else { return nil }
        async let businessRows = fetchOptional(datasets.businessLicenses, [
            URLQueryItem(name: "$select", value: "trade_name,folder_description,subdescription,status,location"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),500) AND upper(status) not like '%CLOSED%' AND upper(status) not like '%CANCEL%'"),
            URLQueryItem(name: "$limit", value: "300")
        ])
        async let patioRows = fetchOptional(datasets.seasonalPatios, [
            URLQueryItem(name: "$select", value: "name,address,operational_dates,location"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters)))"),
            URLQueryItem(name: "$limit", value: "20")
        ])

        let businesses = await businessRows
        let patioData = await patioRows
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)

        var categoryCounts: [String: Int] = [:]
        var records: [(LocalBusinessRecord, Double)] = []
        for row in businesses {
            guard let name = row.string("trade_name"), !name.isEmpty else { continue }
            let category = cleanBusinessCategory(row.string("folder_description") ?? row.string("subdescription"))
            if let category { categoryCounts[category, default: 0] += 1 }
            let coordinate = parseCoordinate(row)
            let distance = coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: subjectLocation) } ?? .greatestFiniteMagnitude
            records.append((LocalBusinessRecord(
                name: name.capitalized,
                category: category,
                distanceDescription: coordinate == nil ? nil : distanceDescription(meters: distance),
                coordinate: coordinate
            ), distance))
        }

        let topCategories = categoryCounts
            .map { IncidentBreakdown(incidentType: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(6)
        let recent = records.sorted { $0.1 < $1.1 }.prefix(8).map(\.0)

        let patios: [LocalBusinessRecord] = patioData.compactMap { row -> (LocalBusinessRecord, Double)? in
            guard let name = row.string("name") else { return nil }
            guard let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            return (LocalBusinessRecord(
                name: name,
                category: row.string("operational_dates"),
                distanceDescription: distanceDescription(meters: distance),
                coordinate: coordinate
            ), distance)
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)

        if records.isEmpty && patios.isEmpty { return nil }
        return LocalBusinessSummary(
            totalNearby: records.count,
            topCategories: Array(topCategories),
            recent: Array(recent),
            patios: Array(patios.prefix(6))
        )
    }

    private func cleanBusinessCategory(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        return raw
            .replacingOccurrences(of: "License - ", with: "")
            .replacingOccurrences(of: "Licence - ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Aquatics & amenities

    private func fetchAquatics(property: PropertyAssessment?) async -> AquaticsAmenitiesSummary? {
        guard let subject = property?.coordinate else { return nil }
        async let indoor = fetchNearestPool(datasets.poolsIndoor, kind: "Indoor", subject: subject, featureKeys: [("Lap swim", "lap_swim"), ("Sauna", "sauna"), ("Whirlpool", "whirlpool"), ("Slide", "pool_slide"), ("Diving board", "diving_board")])
        async let outdoor = fetchNearestPool(datasets.poolsOutdoor, kind: "Outdoor", subject: subject, featureKeys: [("Lap swim", "lap_swim"), ("Slide", "pool_slide"), ("Diving board", "diving_board"), ("Spray features", "spray_features")])
        async let wading = fetchNearestPool(datasets.poolsWading, kind: "Wading", subject: subject, featureKeys: [("Sprayer", "sprayer"), ("Playground", "playground"), ("Slide", "pool_slide")])
        async let spray = fetchNearestPool(datasets.poolsSprayPad, kind: "Spray pad", subject: subject, featureKeys: [("Playground", "playground"), ("Waterslide", "waterslide")])
        async let walkways = fetchWalkwayCount(subject: subject)
        async let wifi = fetchNearestWifi(subject: subject)

        let pools = [await indoor, await outdoor, await wading, await spray]
            .compactMap { $0 }
            .sorted { ($0.1) < ($1.1) }
            .map(\.0)
        let walkwayCount = await walkways
        let nearestWifi = await wifi

        if pools.isEmpty && walkwayCount == 0 && nearestWifi == nil { return nil }
        return AquaticsAmenitiesSummary(pools: pools, walkwaysNearby: walkwayCount, nearestWifi: nearestWifi)
    }

    private func fetchNearestPool(_ dataset: String?, kind: String, subject: CLLocationCoordinate2D, featureKeys: [(String, String)]) async -> (PoolAmenity, Double)? {
        guard let dataset else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: "within_circle(point,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters)))"),
            URLQueryItem(name: "$limit", value: "60")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        let nearest = rows.compactMap { row -> (PoolAmenity, Double)? in
            guard let name = row.string("name"), let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            let features = featureKeys.compactMap { label, key in row.bool(key) ? label : nil }
            return (PoolAmenity(
                name: name,
                kind: kind,
                address: row.string("address"),
                isOpen: row.bool("is_open"),
                distanceDescription: distanceDescription(meters: distance),
                features: features,
                website: row.string("website"),
                coordinate: coordinate
            ), distance)
        }.min { $0.1 < $1.1 }
        return nearest
    }

    private func fetchWalkwayCount(subject: CLLocationCoordinate2D) async -> Int {
        guard let dataset = datasets.walkways else { return 0 }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters)))")
        ])) ?? []
        return rows.first?.int("cnt") ?? 0
    }

    private func fetchNearestWifi(subject: CLLocationCoordinate2D) async -> NamedAmenity? {
        guard let dataset = datasets.publicWifi else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "site_name_english,location"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters)))"),
            URLQueryItem(name: "$limit", value: "40")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        return rows.compactMap { row -> (NamedAmenity, Double)? in
            guard let name = row.string("site_name_english"), let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            return (NamedAmenity(name: name, distanceDescription: distanceDescription(meters: distance), coordinate: coordinate), distance)
        }.min { $0.1 < $1.1 }?.0
    }

    // MARK: - Traffic

    private func fetchTraffic(address: NormalizedAddress, property: PropertyAssessment?) async -> TrafficSummary? {
        async let street = fetchStreetTrafficStudy(address: address)
        async let permanent = fetchNearestPermanentCount(property: property)
        let streetStudy = await street
        let permanentStation = await permanent
        guard streetStudy != nil || permanentStation != nil else { return nil }
        return TrafficSummary(streetStudy: streetStudy, nearestPermanentStation: permanentStation)
    }

    private func fetchStreetTrafficStudy(address: NormalizedAddress) async -> TrafficStudy? {
        guard let dataset = datasets.midblockTrafficCounts else { return nil }
        let core = escaped(streetCore(address.streetName))
        guard !core.isEmpty else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count_date,location_description,count_15_minutes,count_direction"),
            URLQueryItem(name: "$where", value: "upper(street) like '\(core)%'"),
            URLQueryItem(name: "$order", value: "count_date DESC"),
            URLQueryItem(name: "$limit", value: "400")
        ])) ?? []
        guard !rows.isEmpty else { return nil }
        let latestDate = rows.first?.string("count_date")
        let latestDay = latestDate.map(trafficCountDay)
        let latestLocation = rows.first?.string("location_description")
        let sameStudy = rows.filter { row in
            guard row.string("count_date").map(trafficCountDay) == latestDay else { return false }
            if let latestLocation {
                return row.string("location_description") == latestLocation
            }
            return true
        }
        let intervalTotals = Dictionary(grouping: sameStudy, by: { $0.string("count_date") ?? "" })
            .values
            .map { intervalRows in intervalRows.compactMap { $0.int("count_15_minutes") }.reduce(0, +) }
            .filter { $0 > 0 }
        let hourlyAverage = intervalTotals.isEmpty
            ? nil
            : Int((Double(intervalTotals.reduce(0, +)) / Double(intervalTotals.count) * 4).rounded())
        let directions = Set(sameStudy.compactMap { $0.string("count_direction") }.filter { !$0.isEmpty })
        return TrafficStudy(
            locationDescription: latestLocation ?? address.streetName,
            vehiclesCounted: hourlyAverage,
            countDate: parseDate(latestDate),
            direction: directions.count > 1 ? "Both directions" : directions.first,
            distanceDescription: nil,
            countMetricLabel: "Avg. vehicles / hour",
            countSummaryUnit: "vehicles/hr avg",
            countNote: "Midblock traffic data is recorded in 15-minute intervals. This hourly figure is the average 15-minute count for the latest study day multiplied by four."
        )
    }

    private func fetchNearestPermanentCount(property: PropertyAssessment?) async -> TrafficStudy? {
        guard let dataset = datasets.permanentTrafficCounts,
              let subject = property?.coordinate else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "site,total,timestamp,latitude,longitude"),
            URLQueryItem(name: "$where", value: "within_circle(location,\(subject.latitude),\(subject.longitude),\(Int(nearbyRadiusMeters)))"),
            URLQueryItem(name: "$order", value: "timestamp DESC"),
            URLQueryItem(name: "$limit", value: "200")
        ])) ?? []
        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        let nearest = rows.compactMap { row -> (TrafficStudy, Double)? in
            guard let site = row.string("site"), let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            return (TrafficStudy(
                locationDescription: site,
                vehiclesCounted: row.int("total"),
                countDate: parseDate(row.string("timestamp")),
                direction: nil,
                distanceDescription: distanceDescription(meters: distance),
                countMetricLabel: "Vehicles (latest count)",
                countSummaryUnit: "vehicles",
                countNote: nil
            ), distance)
        }.min { $0.1 < $1.1 }
        return nearest?.0
    }

    private func trafficCountDay(_ value: String) -> String {
        String(value.prefix(10))
    }

    // MARK: - Neighbourhood risk

    private func fetchNeighbourhoodRisk(property: PropertyAssessment?) async -> NeighbourhoodRiskSummary? {
        guard let property else { return nil }
        async let rooming = fetchRoomingHouse(neighbourhood: property.neighbourhood)
        async let fires = fetchVacantFireTrend()
        async let towing = fetchTowingNearby(coordinate: property.coordinate)
        async let parking = fetchPaidParkingNearby(coordinate: property.coordinate)
        async let graffiti = fetchGraffitiCount(neighbourhood: property.neighbourhood)

        let roomingActivity = await rooming
        let fireTrend = await fires
        let towingCount = await towing
        let parkingInfo = await parking
        let graffitiCount = await graffiti

        if roomingActivity == nil && fireTrend.isEmpty && towingCount == 0 && parkingInfo.count == 0 && (graffitiCount ?? 0) == 0 {
            return nil
        }
        return NeighbourhoodRiskSummary(
            roomingHouse: roomingActivity,
            vacantFireTrend: fireTrend,
            towingNearby: towingCount,
            paidParkingNearby: parkingInfo.count,
            nearestPaidParking: parkingInfo.nearest,
            graffitiReports: graffitiCount
        )
    }

    private func fetchGraffitiCount(neighbourhood: String?) async -> Int? {
        guard let neighbourhood, let dataset = datasets.serviceRequests else { return nil }
        let whereClause = "\(serviceNeighbourhoodClause(neighbourhood)) AND type LIKE 'Graffiti%'"
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt"),
            URLQueryItem(name: "$where", value: whereClause)
        ])) ?? []
        guard let count = rows.first?.int("cnt"), count > 0 else { return nil }
        return count
    }

    private func fetchRoomingHouse(neighbourhood: String) async -> RoomingHouseActivity? {
        guard let dataset = datasets.roomingHouseEnforcement else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: "upper(neighbourhood)='\(escaped(neighbourhood.uppercased()))'"),
            URLQueryItem(name: "$order", value: "year DESC"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first, let year = row.int("year") else { return nil }
        return RoomingHouseActivity(
            year: year,
            complaintDriven: row.int("complaint_driven"),
            proactive: row.int("proactive_enforcement"),
            inProgress: row.int("in_progress"),
            completed: row.int("completed")
        )
    }

    private func fetchVacantFireTrend() async -> [YearCount] {
        guard let dataset = datasets.vacantPropertyFires else { return [] }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "month,value"),
            URLQueryItem(name: "$limit", value: "2000")
        ])) ?? []
        var byYear: [Int: Int] = [:]
        for row in rows {
            guard let value = row.int("value") else { continue }
            var year: Int?
            if let date = parseDate(row.string("month")) {
                year = Calendar.current.component(.year, from: date)
            } else if let raw = row.string("month"), let parsed = Int(raw.prefix(4)) {
                year = parsed
            }
            guard let year else { continue }
            byYear[year, default: 0] += value
        }
        let currentYear = yearOffset(0)
        return byYear.keys.sorted()
            .filter { $0 >= currentYear - 6 }
            .map { YearCount(year: $0, count: byYear[$0] ?? 0) }
    }

    private func fetchTowingNearby(coordinate: CLLocationCoordinate2D?) async -> Int {
        guard let dataset = datasets.rushHourTowing, let coordinate else { return 0 }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count(*) as cnt"),
            URLQueryItem(name: "$where", value: "within_circle(gps_pickup,\(coordinate.latitude),\(coordinate.longitude),500)")
        ])) ?? []
        return rows.first?.int("cnt") ?? 0
    }

    private func fetchPaidParkingNearby(coordinate: CLLocationCoordinate2D?) async -> (count: Int, nearest: String?) {
        guard let dataset = datasets.paidParking, let coordinate else { return (0, nil) }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "restriction,time_limit,street,center_point"),
            URLQueryItem(name: "$where", value: "within_circle(center_point,\(coordinate.latitude),\(coordinate.longitude),\(Int(nearbyRadiusMeters)))"),
            URLQueryItem(name: "$limit", value: "60")
        ])) ?? []
        guard !rows.isEmpty else { return (0, nil) }
        let subjectLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearest = rows.compactMap { row -> (String, Double)? in
            guard let coordinate = parseCoordinate(row) else { return nil }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            let label = [row.string("street"), row.string("time_limit")].compactMap { $0 }.joined(separator: " · ")
            return (label.isEmpty ? (row.string("restriction") ?? "Paid parking") : label, distance)
        }.min { $0.1 < $1.1 }
        return (rows.count, nearest?.0)
    }

    // MARK: - Water quality

    private func fetchWaterQuality() async -> WaterQualitySummary? {
        guard let dataset = datasets.waterQuality else { return nil }
        let yearRows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "max(year) as y")
        ])) ?? []
        guard let latestYear = yearRows.first?.int("y") else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "area,parameter,units,average,minimum,maximum"),
            URLQueryItem(name: "$where", value: "year=\(latestYear) AND average IS NOT NULL"),
            URLQueryItem(name: "$limit", value: "60")
        ])) ?? []
        guard !rows.isEmpty else { return nil }
        var seen = Set<String>()
        var readings: [WaterQualityReading] = []
        var area: String?
        for row in rows {
            guard let parameter = row.string("parameter"), !seen.contains(parameter) else { continue }
            seen.insert(parameter)
            if area == nil { area = row.string("area") }
            readings.append(WaterQualityReading(parameter: parameter, average: row.double("average"), minimum: row.double("minimum"), maximum: row.double("maximum"), units: row.string("units")))
            if readings.count >= 8 { break }
        }
        guard !readings.isEmpty else { return nil }
        return WaterQualitySummary(year: latestYear, area: area, parameters: readings)
    }

    // MARK: - Capital works

    private func fetchCapitalWorks(address: NormalizedAddress, property _: PropertyAssessment?) async -> CapitalWorksSummary? {
        let core = escaped(streetCore(address.streetName))
        guard core.count >= 3 else { return nil }
        async let projectsRaw = fetchOptional(datasets.capitalProjects, [
            URLQueryItem(name: "$select", value: "project_description,project_status,project_year,adopted_budget,amended_budget,report_date"),
            URLQueryItem(name: "$where", value: "upper(project_description) like '%\(core)%' AND upper(project_status) not like '%CLOSED%'"),
            URLQueryItem(name: "$order", value: "report_date DESC"),
            URLQueryItem(name: "$limit", value: "8")
        ])
        async let fundingRaw = fetchOptional(datasets.infrastructureFunding, [
            URLQueryItem(name: "$select", value: "investment_name,project_details,capital_cost,funding_year,funded"),
            URLQueryItem(name: "$where", value: "upper(project_details) like '%\(core)%' OR upper(investment_name) like '%\(core)%'"),
            URLQueryItem(name: "$limit", value: "5")
        ])

        var projects: [CapitalProject] = (await projectsRaw).compactMap { row in
            guard let name = row.string("project_description") else { return nil }
            return CapitalProject(
                name: name,
                detail: row.string("project_status"),
                status: row.string("project_status"),
                budget: row.double("amended_budget") ?? row.double("adopted_budget"),
                year: row.string("project_year"),
                funded: nil
            )
        }
        for row in await fundingRaw {
            guard let name = row.string("investment_name") else { continue }
            let funded = (row.double("funded") ?? 0) > 0
            projects.append(CapitalProject(
                name: name,
                detail: plainText(row.string("project_details")),
                status: nil,
                budget: row.double("capital_cost"),
                year: row.string("funding_year"),
                funded: funded
            ))
        }
        guard !projects.isEmpty else { return nil }
        return CapitalWorksSummary(projects: Array(projects.prefix(8)))
    }

    // MARK: - Facility closures

    private func fetchFacilityClosures(address: NormalizedAddress, property: PropertyAssessment?) async -> FacilityClosureSummary? {
        guard let dataset = datasets.facilityClosures else { return nil }
        let core = escaped(streetCore(address.streetName))
        guard core.count >= 3 else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$where", value: "upper(name_and_address) like '%\(core)%'"),
            URLQueryItem(name: "$order", value: "closure_date DESC"),
            URLQueryItem(name: "$limit", value: "10")
        ])) ?? []
        let closures: [FacilityClosureRecord] = rows.compactMap { row in
            guard let name = row.string("name_and_address") else { return nil }
            return FacilityClosureRecord(
                name: plainText(name) ?? name,
                establishmentType: row.string("type_of_establishment"),
                reason: plainText(row.string("reasons_for_closure")),
                closureDate: parseDate(row.string("closure_date")),
                reopenDate: parseDate(row.string("re_open_date"))
            )
        }
        guard !closures.isEmpty else { return nil }
        return FacilityClosureSummary(closures: closures)
    }

    // MARK: - Heritage / historical resources

    private func fetchHeritage(address: NormalizedAddress, property: PropertyAssessment?) async -> HeritageSummary? {
        guard let dataset = datasets.heritage,
              let subject = property?.coordinate else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "historical_name,street_number,street_name,grade,sub_code,construction_date,point"),
            URLQueryItem(name: "$where", value: "within_circle(point,\(subject.latitude),\(subject.longitude),500)"),
            URLQueryItem(name: "$limit", value: "40")
        ])) ?? []
        guard !rows.isEmpty else { return nil }

        let subjectLocation = CLLocation(latitude: subject.latitude, longitude: subject.longitude)
        let subjectNumber = address.civicNumber.map(String.init)
        let subjectStreet = streetCore(address.streetName)

        var subjectDesignation: HeritageBuilding?
        var nearby: [(HeritageBuilding, Double)] = []

        for row in rows {
            guard let name = row.string("historical_name") else { continue }
            guard let coordinate = parseCoordinate(row) else { continue }
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude).distance(from: subjectLocation)
            let number = row.string("street_number")
            let streetName = row.string("street_name")
            let addressLabel = [number, streetName].compactMap { $0 }.joined(separator: " ")
            let grade = row.string("grade").flatMap { $0 == "N/A" ? nil : $0 }
            let building = HeritageBuilding(
                name: name,
                address: addressLabel.isEmpty ? nil : addressLabel,
                grade: grade,
                listType: row.string("sub_code"),
                constructionYear: row.string("construction_date"),
                distanceDescription: distanceDescription(meters: distance)
            )
            let isSubject = subjectNumber != nil
                && number == subjectNumber
                && !subjectStreet.isEmpty
                && streetCore(streetName ?? "") == subjectStreet
            if isSubject, subjectDesignation == nil {
                subjectDesignation = building
            } else {
                nearby.append((building, distance))
            }
        }

        let nearbySorted = nearby.sorted { $0.1 < $1.1 }.prefix(8).map(\.0)
        guard subjectDesignation != nil || !nearbySorted.isEmpty else { return nil }
        return HeritageSummary(subjectDesignation: subjectDesignation, nearby: Array(nearbySorted))
    }

    // MARK: - Mosquito control (Insect Control)

    private func fetchMosquito(property: PropertyAssessment?) async -> MosquitoSummary? {
        guard let dataset = datasets.mosquitoTraps,
              let subject = property?.coordinate else { return nil }
        let rows = (try? await fetch(dataset, queryItems: [
            URLQueryItem(name: "$select", value: "count_date,city_wide_daily_average,north_west_average,north_east_average,south_east_average,south_west_average"),
            URLQueryItem(name: "$order", value: "count_date DESC"),
            URLQueryItem(name: "$limit", value: "1")
        ])) ?? []
        guard let row = rows.first else { return nil }

        // Winnipeg's geographic quadrants split roughly at the city centre (Portage & Main).
        // The trap dataset reports one average per quadrant, so we pick the matching one.
        let centreLat = 49.8951
        let centreLon = -97.1384
        let northSouth = subject.latitude >= centreLat ? "north" : "south"
        let eastWest = subject.longitude >= centreLon ? "east" : "west"
        let quadrantKey = "\(northSouth)_\(eastWest)_average"
        let quadrantName = "\(northSouth.capitalized) \(eastWest.capitalized)"

        let quadrantCount = row.int(quadrantKey)
        let cityWide = row.int("city_wide_daily_average")
        guard quadrantCount != nil || cityWide != nil else { return nil }
        let peak = max(quadrantCount ?? 0, cityWide ?? 0)
        return MosquitoSummary(
            quadrant: quadrantName,
            quadrantCount: quadrantCount,
            cityWideAverage: cityWide,
            countDate: parseDate(row.string("count_date")),
            foggingThresholdReached: peak >= 100
        )
    }

    // MARK: - Static metro-wide reference figures

    /// Health Canada, 2012 Cross-Canada Survey of Radon Concentrations in Homes — 19% of
    /// Manitoba homes tested at or above the 200 Bq/m³ guideline. A regional reference, not
    /// an address-level reading; presented as information with a "test your home" prompt.
    private var winnipegRadon: RadonSummary {
        RadonSummary(
            region: "Manitoba",
            percentAboveGuideline: 19,
            surveyName: "Health Canada Cross-Canada Survey of Radon Concentrations in Homes"
        )
    }

    /// CMHC Rental Market Survey (Winnipeg CMA). Metro-wide averages updated annually each
    /// October; not specific to one address.
    private var winnipegRentalMarket: RentalMarketSummary {
        RentalMarketSummary(
            area: "Winnipeg CMA",
            year: 2025,
            vacancyRate: 2.8,
            brackets: [
                RentBracket(bedrooms: "Bachelor", averageRent: 1000),
                RentBracket(bedrooms: "1 bedroom", averageRent: 1230),
                RentBracket(bedrooms: "2 bedroom", averageRent: 1480),
                RentBracket(bedrooms: "3 bedroom+", averageRent: 1700)
            ]
        )
    }

    private func fetchOptional(_ dataset: String?, _ items: [URLQueryItem]) async -> [[String: Any]] {
        guard let dataset else { return [] }
        return (try? await fetch(dataset, queryItems: items)) ?? []
    }

    private func isoNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: .now).replacingOccurrences(of: "Z", with: "")
    }

    private func parseCoordinate(_ row: [String: Any]) -> CLLocationCoordinate2D? {
        for key in ["geometry", "the_geom", "location", "point", "location_point", "location_1", "location_1_geom"] {
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
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        if let date = ISO8601DateFormatter().date(from: value) { return date }

        let socrataTimestamp = DateFormatter()
        socrataTimestamp.locale = Locale(identifier: "en_US_POSIX")
        socrataTimestamp.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return socrataTimestamp.date(from: value)
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var htmlDecoded: String {
        self
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    /// The City of Winnipeg's School Zone Signage feed stores French civic names with their
    /// accented letters already destroyed into the Unicode replacement character (U+FFFD) at
    /// the source — e.g. "École Rivière-Rouge" arrives as "�cole Rivi�re-Rouge". The original
    /// letter is unrecoverable from the bytes, so repair the patterns that actually occur in
    /// these names and fall back to the most common French vowel for anything left over.
    var repairedFrenchCivicName: String {
        guard contains("\u{FFFD}") else { return self }
        var result = self
        // A word-initial replacement is, for Winnipeg schools, always "École".
        if result.hasPrefix("\u{FFFD}cole") {
            result = "É" + result.dropFirst()
        }
        // "Rivière"/"Frontière" etc. — the destroyed letter before "re" is "è".
        result = result.replacingOccurrences(of: "\u{FFFD}re", with: "ère")
        // Any remaining replacement character is a lowercase "é" in these names.
        result = result.replacingOccurrences(of: "\u{FFFD}", with: "é")
        return result
    }
}
