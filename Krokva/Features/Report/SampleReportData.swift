import CoreLocation
import Foundation

/// A fully-populated, entirely fictional `AddressReport` used to generate a
/// representative "sample report" PDF for marketing (krokva.com). No field
/// here is drawn from a real address — every number is a plausible Winnipeg
/// city-wide average so the sample can't be mistaken for a real dossier.
enum SampleReportData {
    static var report: AddressReport {
        let coordinate = CLLocationCoordinate2D(latitude: 49.8754, longitude: -97.1686)
        let calendar = Calendar(identifier: .gregorian)
        func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
        }

        let address = NormalizedAddress(
            raw: "123 Maplewood Crescent",
            civicNumber: 123,
            streetName: "Maplewood Crescent",
            cityName: "Winnipeg",
            provinceCode: "MB"
        )

        var report = AddressReport(
            address: address,
            providerID: "winnipeg",
            cityName: "Winnipeg, MB",
            providerState: .live
        )

        report.property = PropertyAssessment(
            fullAddress: "123 Maplewood Crescent",
            neighbourhood: "River Park South",
            postalCode: "R2M 0A1",
            useCode: "Single Family Detached",
            totalAssessedValue: 358_200,
            propertyTax: 3_412,
            propertyTaxIsEstimated: false,
            livingArea: 1_340,
            landArea: 4_800,
            yearBuilt: 1978,
            rooms: "7",
            basement: "Full",
            garage: "Attached, 1 car",
            airConditioning: "Central",
            fireplace: "Yes",
            swimmingPool: "None",
            zoning: "R1",
            rollNumber: "12345678",
            houseStyle: "Bungalow",
            storeys: "1",
            coordinate: coordinate,
            assessmentYear: 2026,
            propertyTaxYear: 2026
        )

        report.neighbourhoodValues = [
            AssessmentValueBin(bucket: "<$250k", count: 42, midpoint: 225_000),
            AssessmentValueBin(bucket: "$250k–$350k", count: 118, midpoint: 300_000),
            AssessmentValueBin(bucket: "$350k–$450k", count: 96, midpoint: 400_000),
            AssessmentValueBin(bucket: "$450k–$550k", count: 34, midpoint: 500_000),
            AssessmentValueBin(bucket: "$550k+", count: 11, midpoint: 600_000)
        ]

        report.comparables = [
            ComparableProperty(address: "108 Maplewood Crescent", value: 349_600, livingArea: 1_290, yearBuilt: 1976),
            ComparableProperty(address: "140 Maplewood Crescent", value: 372_800, livingArea: 1_410, yearBuilt: 1980),
            ComparableProperty(address: "22 Fernwood Bay", value: 361_500, livingArea: 1_360, yearBuilt: 1979)
        ]

        report.permits = [
            BuildingPermit(issuedDate: date(2025, 6), type: "Building Permit", subType: "Alteration", workType: "Roof replacement", address: "123 Maplewood Crescent", status: "Closed", isAdjacentStructural: false, coordinate: coordinate),
            BuildingPermit(issuedDate: date(2023, 9), type: "Electrical Permit", subType: nil, workType: "Panel upgrade", address: "123 Maplewood Crescent", status: "Closed", isAdjacentStructural: false, coordinate: coordinate)
        ]
        report.permitActivity = [
            YearCount(year: 2023, count: 2, citywideAverage: 3.1),
            YearCount(year: 2024, count: 1, citywideAverage: 3.4),
            YearCount(year: 2025, count: 3, citywideAverage: 3.2)
        ]

        report.vacantOrders = []

        report.infrastructure = InfrastructureSummary(
            speedLimit: "50 km/h",
            potholes: 4,
            publicTrees: 62,
            taggedTrees: 3,
            topTreeSpecies: "Green Ash"
        )

        report.parks = ParksSummary(
            nearestPark: ParkAmenity(parkID: "p1", name: "Maplewood Park", distanceDescription: "220 m", coordinate: coordinate, playgrounds: 1, fields: 1, courts: 1, washrooms: 0, benches: 4),
            nearbyParks: [
                ParkAmenity(parkID: "p1", name: "Maplewood Park", distanceDescription: "220 m", coordinate: coordinate, playgrounds: 1, fields: 1, courts: 1, washrooms: 0, benches: 4),
                ParkAmenity(parkID: "p2", name: "Fernwood Green", distanceDescription: "540 m", coordinate: coordinate, playgrounds: 1, fields: 0, courts: 0, washrooms: 0, benches: 2)
            ],
            neighbourhoodParkCount: 6,
            neighbourhoodHectares: 18.4,
            nearestDogPark: DogParkAmenity(parkID: "d1", name: "River Park South Off-Leash Area", distanceDescription: "1.1 km", classification: "Fenced", coordinate: coordinate)
        )

        report.transit = TransitAccessSummary(
            nearestStop: TransitStop(stopNumber: "10432", distanceDescription: "180 m"),
            routes: [
                TransitRouteSummary(routeNumber: "16", routeName: "Silver"),
                TransitRouteSummary(routeNumber: "72", routeName: "River Park South")
            ],
            averageDeviationSeconds: 95,
            onTimePercentage: 84.5,
            passUpsLastYear: 2,
            averageDailyBoardings: 38
        )

        report.bylaw = BylawInvestigationSummary(
            neighbourhood: "River Park South",
            yearly: [YearCount(year: 2024, count: 21, citywideAverage: 24.5), YearCount(year: 2025, count: 18, citywideAverage: 23.1)],
            complaintTypes: [
                IncidentBreakdown(incidentType: "Yard maintenance", count: 9, citywideAverage: 8.2),
                IncidentBreakdown(incidentType: "Noise", count: 5, citywideAverage: 6.4),
                IncidentBreakdown(incidentType: "Snow clearing", count: 4, citywideAverage: 5.0)
            ]
        )

        report.development = DevelopmentContextSummary(
            recentPermits: [
                DevelopmentPermit(issuedDate: date(2025, 3), permitNumber: "DP-25-0142", type: "Development Permit", subType: "Residential", workType: "Rear addition", address: "9 Fernwood Bay", status: "Approved", coordinate: coordinate)
            ],
            reviewProcessing: [
                PermitProcessingMetric(description: "Residential development permits", month: date(2025, 12), averageBusinessDays: 12.4, serviceStandardDays: 15, percentMetTarget: 88)
            ],
            intake: [
                PermitIntakeMetric(description: "Residential development permits", month: date(2025, 12), approved: 46, notApproved: 3)
            ]
        )

        report.river = RiverGaugeSummary(
            riverName: "Red River",
            location: "St. Vital",
            distanceDescription: "1.6 km",
            jamesFeet: 12.8,
            geodeticFeet: 738.2,
            geodeticMetric: 225.0,
            readingDate: date(2026, 6, 28),
            notes: "Normal summer level",
            coordinate: coordinate
        )

        report.library = LibraryAmenity(
            name: "St. Vital Library",
            address: "6 St. Vital Road",
            distanceDescription: "1.9 km",
            wifi: true,
            accessibility: true,
            parkingLot: true,
            parkingStalls: 40,
            roomRentals: true,
            notes: nil,
            coordinate: coordinate
        )

        report.serviceRequests = ServiceRequestSummary(
            neighbourhood: "River Park South",
            totalLastYear: 64,
            openLastYear: 6,
            closedLastYear: 58,
            statusBreakdown: [
                IncidentBreakdown(incidentType: "Closed", count: 58, citywideAverage: 55),
                IncidentBreakdown(incidentType: "Open", count: 6, citywideAverage: 8)
            ],
            channelBreakdown: [
                IncidentBreakdown(incidentType: "311 App", count: 28, citywideAverage: 24),
                IncidentBreakdown(incidentType: "Phone", count: 36, citywideAverage: 40)
            ],
            topSubjects: [IncidentBreakdown(incidentType: "Streets", count: 22, citywideAverage: 20)],
            topReasons: [IncidentBreakdown(incidentType: "Pothole", count: 12, citywideAverage: 10)],
            topTypes: [IncidentBreakdown(incidentType: "Road Maintenance", count: 18, citywideAverage: 16)],
            monthlyTrend: (1...12).map { ServiceRequestMonth(year: 2025, month: $0, count: Int.random(in: 3...8)) },
            recentRequests: [
                ServiceRequestRecord(caseID: "SR-2026-00142", channel: "311 App", subject: "Streets", reason: "Pothole", type: "Road Maintenance", openDate: date(2026, 5, 3), closedDate: date(2026, 5, 12), status: "Closed", ward: "St. Vital", coordinate: coordinate)
            ]
        )

        report.planning = PlanningContextSummary(
            zoningCode: "R1",
            zoningDescription: "Residential Single Family",
            zoningIntent: "To maintain and enhance areas characterized predominantly by single-family detached housing.",
            publicNotices: []
        )

        report.streetAccess = StreetAccessSummary(
            pavementCondition: "Good",
            pavementSurface: "Asphalt",
            roadType: "Local Street",
            schoolSpeedLimit: SchoolSpeedLimit(school: "Général Vanier School", speedLimit: "30 km/h", effectiveDays: "Mon–Fri", effectiveTime: "8:00–9:00, 15:00–16:00"),
            cyclingRoutesNearby: 2,
            activeDisruptions: [],
            activeLaneClosures: []
        )

        report.emergency = EmergencySummary(
            neighbourhood: "River Park South",
            totalLastYear: 112,
            motorVehicleLastYear: 9,
            averageDurationMinutes: 22,
            yearlyCalls: [YearCount(year: 2024, count: 104, citywideAverage: 118), YearCount(year: 2025, count: 112, citywideAverage: 121)],
            monthlyTrend: (1...12).map { EmergencyMonth(year: 2025, month: $0, count: Int.random(in: 6...14)) },
            last12Months: [IncidentBreakdown(incidentType: "Medical Response", count: 78, citywideAverage: 82)],
            citywideMedian: 118,
            neighbourhoodRank: 62,
            neighbourhoodCount: 236
        )

        report.publicHealth = PublicHealthSummary(
            yearlyEvents: [PublicHealthYear(year: 2024, neighbourhood: 3, citywideAverage: 5.2), PublicHealthYear(year: 2025, neighbourhood: 2, citywideAverage: 4.8)],
            ageGroups: [IncidentBreakdown(incidentType: "30-39", count: 4, citywideAverage: 5)],
            substances: [IncidentBreakdown(incidentType: "Opioids", count: 3, citywideAverage: 4)],
            nearestER: HealthFacilityAccess(name: "St. Boniface Hospital", address: "409 Tache Ave", city: "Winnipeg", province: "MB", driveMinutes: 11, avgWaitMinutes: nil, currentWaitMinutes: 96, waitingPatients: 14, treatingPatients: 22, waitTimeUpdatedAt: "10 minutes ago", waitTimeAttribution: "WRHA"),
            nearestWalkIn: HealthFacilityAccess(name: "St. Vital Medical Clinic", address: "3 St. Vital Road", driveMinutes: 6),
            walkInClinicsNearby: 3,
            nearestAED: DefibrillatorAccess(name: "St. Vital Community Centre", locationDescription: "Front lobby", access: "Public", indoor: true, distanceDescription: "1.2 km", coordinate: coordinate),
            aedsNearby: 4
        )

        report.policeCrime = PoliceCrimeSummary(
            neighbourhood: "River Park South",
            latestMonth: PoliceCrimeMonth(year: 2026, month: 5),
            yearlyCounts: [PoliceCrimeYear(year: 2024, neighbourhood: 38, citywideAverage: 52), PoliceCrimeYear(year: 2025, neighbourhood: 41, citywideAverage: 54)],
            crimeTypes: [IncidentBreakdown(incidentType: "Theft", count: 14, citywideAverage: 18), IncidentBreakdown(incidentType: "Mischief", count: 9, citywideAverage: 11)],
            offenceTypes: [IncidentBreakdown(incidentType: "Property Crime", count: 26, citywideAverage: 33)]
        )

        report.shortTermRentals = ShortTermRentalSummary(total: 1, primaryCount: 1, nonPrimaryCount: 0, recent: [
            ShortTermRentalRecord(address: "31 Fernwood Bay", primaryStatus: "Primary Residence", issuedDate: date(2025, 4), ward: "St. Vital")
        ])

        report.civicContext = AddressCivicContext(
            addressID: "SAMPLE-000001",
            ward: "St. Vital",
            neighbourhood: "River Park South",
            postalCode: "R2M 0A1",
            plowZone: "Zone 7",
            schoolDivision: "Louis Riel School Division",
            schoolDivisionBoundaryName: "Louis Riel",
            schoolDivisionCode: "LRSD",
            schoolDivisionWard: "Ward 3",
            schoolDivisionWebsite: "https://www.lrsd.net"
        )

        report.recreation = RecreationSummary(
            nearestComplex: RecreationComplex(name: "St. Vital Centennial Arena", address: "6 St. Vital Road", distanceDescription: "1.8 km", amenities: ["Arena", "Fitness Centre"], coordinate: coordinate),
            complexes: [RecreationComplex(name: "St. Vital Centennial Arena", address: "6 St. Vital Road", distanceDescription: "1.8 km", amenities: ["Arena", "Fitness Centre"], coordinate: coordinate)],
            activities: [RecreationActivity(name: "Adult Drop-in Volleyball", placeName: "St. Vital Centennial Arena", category: "Sports", activityType: "Drop-in", status: "Open", startDate: date(2026, 9, 8), endDate: date(2026, 12, 12))],
            communityCentres: [CommunityCentre(name: "River Park South Community Centre", address: "20 Doncrest Bay", distanceDescription: "900 m", coordinate: coordinate)]
        )

        report.nearbySchools = [
            SchoolAmenity(name: "Général Vanier School", address: "757 Vanier Place", distanceDescription: "450 m", distanceMeters: 450, walkingTimeDescription: "6 min walk", grades: "K-6", schoolType: "Public — French Immersion", programs: ["French Immersion"], isAssigned: true, source: "Louis Riel School Division", coordinate: coordinate),
            SchoolAmenity(name: "Collège Béliveau", address: "1250 Beliveau Road", distanceDescription: "2.4 km", distanceMeters: 2400, walkingTimeDescription: "30 min walk", grades: "7-12", schoolType: "Public", programs: [], isAssigned: true, source: "Louis Riel School Division", coordinate: coordinate)
        ]

        report.waste = WasteCollectionSummary(
            garbageDay: "Wednesday",
            recycleDay: "Wednesday",
            yardWasteDay: "Friday",
            matchedAddress: "123 Maplewood Crescent",
            plowZone: "Zone 7",
            nextPlowWindow: "Not currently in effect",
            activeSnowBan: nil
        )

        report.demographics = DemographicsSummary(
            boundaryName: "River Park South",
            totalPopulation: 8_450,
            childrenPercent: 17.2,
            seniorsPercent: 16.8,
            medianHouseholdIncome: 92_400,
            averageHouseholdSize: 2.6,
            immigrantPercent: 14.5,
            topNonOfficialLanguage: "Tagalog",
            commuteModes: [
                IncidentBreakdown(incidentType: "Car", count: 78, citywideAverage: 74),
                IncidentBreakdown(incidentType: "Public transit", count: 12, citywideAverage: 14),
                IncidentBreakdown(incidentType: "Walk", count: 6, citywideAverage: 7),
                IncidentBreakdown(incidentType: "Bicycle", count: 4, citywideAverage: 5)
            ],
            isHighPovertyArea: false,
            giniIndex: 0.34
        )

        report.localGovernment = LocalGovernmentSummary(
            wardName: "St. Vital",
            councillor: "Sample Councillor",
            councillorPhone: "311",
            councillorWebsite: "https://winnipeg.ca/council/stvital",
            communityCommittee: "St. Vital"
        )

        report.localBusiness = LocalBusinessSummary(
            totalNearby: 22,
            topCategories: [IncidentBreakdown(incidentType: "Restaurant", count: 8, citywideAverage: 6), IncidentBreakdown(incidentType: "Retail", count: 6, citywideAverage: 5)],
            recent: [LocalBusinessRecord(name: "Maplewood Diner", category: "Restaurant", distanceDescription: "310 m", coordinate: coordinate)],
            patios: [LocalBusinessRecord(name: "Maplewood Diner", category: "Restaurant", distanceDescription: "310 m", coordinate: coordinate)]
        )

        report.aquatics = AquaticsAmenitiesSummary(
            pools: [PoolAmenity(name: "St. Vital Pool", kind: "Outdoor", address: "10 St. Vital Road", isOpen: true, distanceDescription: "1.7 km", features: ["Waterslide", "Lane swim"], website: nil, coordinate: coordinate)],
            walkwaysNearby: 3,
            nearestWifi: NamedAmenity(name: "River Park South Community Centre", distanceDescription: "900 m", coordinate: coordinate)
        )

        report.traffic = TrafficSummary(
            streetStudy: TrafficStudy(locationDescription: "Maplewood Crescent near Fernwood Bay", vehiclesCounted: 640, countDate: date(2025, 8), direction: "Both", distanceDescription: "60 m", countMetricLabel: "Average Daily Traffic", countSummaryUnit: "vehicles/day", countNote: nil),
            nearestPermanentStation: nil
        )

        report.neighbourhoodRisk = NeighbourhoodRiskSummary(
            roomingHouse: RoomingHouseActivity(year: 2025, complaintDriven: 1, proactive: 0, inProgress: 0, completed: 1),
            vacantFireTrend: [YearCount(year: 2024, count: 0), YearCount(year: 2025, count: 0)],
            towingNearby: 2,
            paidParkingNearby: 0,
            nearestPaidParking: nil,
            graffitiReports: 1
        )

        report.waterQuality = WaterQualitySummary(
            year: 2025,
            area: "South District",
            parameters: [
                WaterQualityReading(parameter: "Chlorine residual", average: 0.82, minimum: 0.61, maximum: 1.05, units: "mg/L"),
                WaterQualityReading(parameter: "Turbidity", average: 0.09, minimum: 0.04, maximum: 0.18, units: "NTU")
            ]
        )

        report.capitalWorks = CapitalWorksSummary(projects: [
            CapitalProject(name: "St. Vital Road Rehabilitation", detail: "Curb-to-curb pavement renewal", status: "In design", budget: 4_200_000, year: "2027", funded: true)
        ])

        report.facilityClosures = FacilityClosureSummary(closures: [])

        report.heritage = HeritageSummary(subjectDesignation: nil, nearby: [])

        report.mosquito = MosquitoSummary(quadrant: "South East", quadrantCount: 18, cityWideAverage: 22, countDate: date(2026, 6, 24), foggingThresholdReached: false)

        report.radon = RadonSummary(region: "Manitoba – Southern", percentAboveGuideline: 7, surveyName: "Health Canada Cross-Canada Radon Survey")

        report.rentalMarket = RentalMarketSummary(area: "St. Vital", year: 2025, vacancyRate: 2.8, brackets: [
            RentBracket(bedrooms: "Bachelor", averageRent: 895),
            RentBracket(bedrooms: "1 Bedroom", averageRent: 1_140),
            RentBracket(bedrooms: "2 Bedroom", averageRent: 1_420),
            RentBracket(bedrooms: "3 Bedroom+", averageRent: 1_780)
        ])

        report.sources = []
        return report
    }
}
