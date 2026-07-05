import SwiftUI

// MARK: - PDF-render environment flag

private struct ReportPDFRenderKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while report cards are rendered offscreen into the PDF export.
    /// Collapsible cards render expanded and appear-animations draw their
    /// final state (offscreen rendering never plays animations).
    var reportPDFRender: Bool {
        get { self[ReportPDFRenderKey.self] }
        set { self[ReportPDFRenderKey.self] = newValue }
    }
}

// MARK: - Card catalog

/// Everything a card builder needs; `ReportView` and the PDF exporter build
/// the same context so both render identical content.
struct ReportCardContext {
    let report: AddressReport
    let analytics: ReportAnalytics
    var permitHistoryRefreshToken = UUID()
    var isPDF = false
}

struct ReportCardDescriptor: Identifiable {
    let id: String
    /// User-facing name shown in the PDF export checkbox list.
    let title: String
    let systemImage: String
    /// Section label used to group checkboxes in the export sheet.
    let section: String
    /// Cards that can't render offscreen (live MapKit, async SwiftData loads)
    /// stay on screen only.
    var includeInPDF = true
    private let builder: (ReportCardContext) -> AnyView

    init(id: String,
         title: String,
         systemImage: String,
         section: String,
         includeInPDF: Bool = true,
         @ViewBuilder builder: @escaping (ReportCardContext) -> some View) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.section = section
        self.includeInPDF = includeInPDF
        self.builder = { AnyView(builder($0)) }
    }

    func makeView(_ context: ReportCardContext) -> AnyView {
        builder(context)
    }
}

/// Single source of truth for the report card stack. `ReportView` renders it
/// in order, and the PDF export sheet/exporter reuse the same entries — adding
/// or changing a card here updates both automatically.
enum ReportCardCatalog {
    enum Section {
        static let property = "Property & valuation"
        static let safety = "Safety & health"
        static let daily = "Daily living"
        static let mobility = "Getting around"
        static let amenities = "Amenities & lifestyle"
        static let development = "Development & property risk"
        static let reference = "Environment & reference"
    }

    static let all: [ReportCardDescriptor] = [
        // ── A. Property & valuation ──────────────────────────────
        // Identity first: what is this place, what does it cost, key facts.
        .init(id: "hero", title: "Property overview", systemImage: "house.and.flag", section: Section.property) { ctx in
            HeroPropertyCard(report: ctx.report, showsMap: !ctx.isPDF)
        },
        .init(id: "analyticsIndices", title: "Analytics indices", systemImage: "gauge.with.dots.needle.bottom.50percent", section: Section.property) { ctx in
            CompositeIndicesCard(analytics: ctx.analytics)
        },
        .init(id: "trends", title: "Trends", systemImage: "chart.line.uptrend.xyaxis", section: Section.property) { ctx in
            TrendsCard(analytics: ctx.analytics)
        },
        .init(id: "comparative", title: "Comparative percentiles", systemImage: "percent", section: Section.property) { ctx in
            ComparativeCard(analytics: ctx.analytics)
        },
        .init(id: "financial", title: "Financial details", systemImage: "dollarsign.circle", section: Section.property) { ctx in
            PropertyFinancialCard(property: ctx.report.property)
        },
        .init(id: "facts", title: "Property facts", systemImage: "list.bullet.rectangle", section: Section.property) { ctx in
            PropertyFactsCard(property: ctx.report.property, sourceFailed: ctx.report.moduleFailed(.property))
        },
        .init(id: "civicContext", title: "Civic context", systemImage: "building.columns", section: Section.property) { ctx in
            CivicContextCard(summary: ctx.report.civicContext, sourceFailed: ctx.report.moduleFailed(.civicContext))
        },
        .init(id: "rentalMarket", title: "Rental market", systemImage: "key", section: Section.property) { ctx in
            RentalMarketCard(summary: ctx.report.rentalMarket)
        },

        // ── B. Safety & health ───────────────────────────────────
        // The questions buyers/renters fear most, surfaced high.
        .init(id: "policeCrime", title: "Police crime", systemImage: "shield.lefthalf.filled", section: Section.safety) { ctx in
            PoliceCrimeCard(summary: ctx.report.policeCrime, sourceFailed: ctx.report.moduleFailed(.policeCrime))
        },
        .init(id: "emergency", title: "Emergency activity", systemImage: "cross.case", section: Section.safety) { ctx in
            EmergencyActivityCard(
                summary: ctx.report.emergency,
                substances: ctx.report.publicHealth?.substances ?? [],
                sourceFailed: ctx.report.moduleFailed(.emergency)
            )
        },
        .init(id: "publicHealth", title: "Public health", systemImage: "heart.text.square", section: Section.safety) { ctx in
            if let health = ctx.report.publicHealth {
                PublicHealthCard(
                    summary: health,
                    neighbourhood: ctx.report.property?.neighbourhood ?? ctx.report.cityName
                )
            } else if ctx.report.moduleFailed(.publicHealth) {
                ModuleErrorCard(title: "Public Health", systemImage: "heart.text.square", iconColor: .cleanSky,
                                message: "Database error loading public health data.")
            }
        },
        .init(id: "neighbourhoodRisk", title: "Neighbourhood risk", systemImage: "exclamationmark.shield", section: Section.safety) { ctx in
            NeighbourhoodRiskCard(summary: ctx.report.neighbourhoodRisk, sourceFailed: ctx.report.moduleFailed(.neighbourhoodRisk))
        },

        // ── C. Daily living ──────────────────────────────────────
        .init(id: "waste", title: "Waste & winter", systemImage: "trash", section: Section.daily) { ctx in
            WasteCollectionCard(summary: ctx.report.waste, sourceFailed: ctx.report.moduleFailed(.waste))
        },
        .init(id: "schools", title: "Nearby schools", systemImage: "graduationcap", section: Section.daily) { ctx in
            NearbySchoolsCard(
                schools: ctx.report.nearbySchools,
                property: ctx.report.property,
                schoolZone: ctx.report.streetAccess?.schoolSpeedLimit,
                civicContext: ctx.report.civicContext,
                sourceFailed: ctx.report.moduleFailed(.schools)
            )
        },
        .init(id: "demographics", title: "Who lives here", systemImage: "person.2", section: Section.daily) { ctx in
            DemographicsCard(
                summary: ctx.report.demographics,
                sourceFailed: ctx.report.moduleFailed(.demographics)
            )
        },
        .init(id: "localGovernment", title: "Local government", systemImage: "building.2", section: Section.daily) { ctx in
            LocalGovernmentCard(summary: ctx.report.localGovernment, sourceFailed: ctx.report.moduleFailed(.localGovernment))
        },
        .init(id: "service311", title: "311 activity", systemImage: "phone.badge.waveform", section: Section.daily) { ctx in
            if let sr = ctx.report.serviceRequests {
                Service311Card(summary: sr)
            } else if ctx.report.moduleFailed(.serviceRequests) {
                ModuleErrorCard(title: "311 Activity", systemImage: "phone.badge.waveform", iconColor: .cleanIndigo,
                                message: "Database error loading 311 activity.")
            }
        },

        // ── D. Getting around ────────────────────────────────────
        .init(id: "transit", title: "Transit access", systemImage: "bus", section: Section.mobility) { ctx in
            TransitAccessCard(summary: ctx.report.transit, sourceFailed: ctx.report.moduleFailed(.transit))
        },
        .init(id: "streetAccess", title: "Street access", systemImage: "road.lanes", section: Section.mobility) { ctx in
            StreetAccessCard(street: ctx.report.streetAccess, infrastructure: ctx.report.infrastructure,
                             sourceFailed: ctx.report.moduleFailed(.streetAccess) || ctx.report.moduleFailed(.infrastructure))
        },
        .init(id: "traffic", title: "Traffic", systemImage: "car.2", section: Section.mobility) { ctx in
            TrafficCard(summary: ctx.report.traffic, risk: ctx.report.neighbourhoodRisk,
                        sourceFailed: ctx.report.moduleFailed(.traffic) || ctx.report.moduleFailed(.neighbourhoodRisk))
        },

        // ── E. Amenities & lifestyle ─────────────────────────────
        .init(id: "civicAmenities", title: "Civic amenities", systemImage: "leaf", section: Section.amenities) { ctx in
            CivicAmenitiesCard(parks: ctx.report.parks, river: ctx.report.river, library: ctx.report.library, aquatics: ctx.report.aquatics,
                               sourceFailed: ctx.report.moduleFailed(.parks) || ctx.report.moduleFailed(.river) || ctx.report.moduleFailed(.library) || ctx.report.moduleFailed(.aquatics))
        },
        .init(id: "recreation", title: "Recreation", systemImage: "figure.run", section: Section.amenities) { ctx in
            RecreationCard(summary: ctx.report.recreation, sourceFailed: ctx.report.moduleFailed(.recreation))
        },
        .init(id: "localBusiness", title: "Local businesses", systemImage: "storefront", section: Section.amenities) { ctx in
            LocalBusinessCard(summary: ctx.report.localBusiness, sourceFailed: ctx.report.moduleFailed(.localBusiness))
        },

        // ── F. Development & property risk ───────────────────────
        // On-screen only: loads its permit history asynchronously via SwiftData,
        // which offscreen PDF rendering would capture mid-load.
        .init(id: "permitHistory", title: "Permit history", systemImage: "clock.arrow.circlepath", section: Section.development, includeInPDF: false) { ctx in
            PropertyPermitHistoryCard(report: ctx.report, refreshToken: ctx.permitHistoryRefreshToken)
        },
        .init(id: "permits", title: "Nearby permits", systemImage: "hammer", section: Section.development) { ctx in
            PermitsCard(permits: ctx.report.permits, sourceFailed: ctx.report.moduleFailed(.permits))
        },
        .init(id: "permitActivity", title: "Permit activity", systemImage: "chart.bar", section: Section.development) { ctx in
            PermitActivityCard(activity: ctx.report.permitActivity, sourceFailed: ctx.report.moduleFailed(.permitActivity))
        },
        .init(id: "vacantOrders", title: "Vacant-building orders", systemImage: "house.slash", section: Section.development) { ctx in
            VacantOrdersCard(orders: ctx.report.vacantOrders, sourceFailed: ctx.report.moduleFailed(.vacantOrders))
        },
        .init(id: "development", title: "Development context", systemImage: "building.2.crop.circle", section: Section.development) { ctx in
            DevelopmentContextCard(summary: ctx.report.development, sourceFailed: ctx.report.moduleFailed(.development))
        },
        .init(id: "planning", title: "Planning notices", systemImage: "doc.text.magnifyingglass", section: Section.development) { ctx in
            PlanningContextCard(summary: ctx.report.planning, sourceFailed: ctx.report.moduleFailed(.planning))
        },
        .init(id: "heritage", title: "Heritage", systemImage: "building.columns.circle", section: Section.development) { ctx in
            HeritageCard(summary: ctx.report.heritage, sourceFailed: ctx.report.moduleFailed(.heritage))
        },
        .init(id: "shortTermRentals", title: "Short-term rentals", systemImage: "suitcase", section: Section.development) { ctx in
            ShortTermRentalsCard(summary: ctx.report.shortTermRentals, sourceFailed: ctx.report.moduleFailed(.shortTermRentals))
        },
        .init(id: "bylaw", title: "Bylaw investigations", systemImage: "exclamationmark.bubble", section: Section.development) { ctx in
            BylawInvestigationsCard(summary: ctx.report.bylaw, sourceFailed: ctx.report.moduleFailed(.bylaw))
        },

        // ── G. Environment, city works & reference ───────────────
        .init(id: "mosquito", title: "Mosquito traps", systemImage: "ant", section: Section.reference) { ctx in
            MosquitoCard(summary: ctx.report.mosquito, sourceFailed: ctx.report.moduleFailed(.mosquito))
        },
        .init(id: "radon", title: "Radon", systemImage: "aqi.medium", section: Section.reference) { ctx in
            RadonCard(summary: ctx.report.radon)
        },
        .init(id: "waterQuality", title: "Drinking water quality", systemImage: "drop", section: Section.reference) { ctx in
            WaterQualityCard(summary: ctx.report.waterQuality, sourceFailed: ctx.report.moduleFailed(.waterQuality))
        },
        .init(id: "capitalWorks", title: "Capital projects", systemImage: "wrench.and.screwdriver", section: Section.reference) { ctx in
            CapitalWorksCard(summary: ctx.report.capitalWorks, sourceFailed: ctx.report.moduleFailed(.capitalWorks))
        },
        .init(id: "facilityClosures", title: "Facility closures", systemImage: "door.left.hand.closed", section: Section.reference) { ctx in
            FacilityClosuresCard(summary: ctx.report.facilityClosures, sourceFailed: ctx.report.moduleFailed(.facilityClosures))
        },
        // On-screen only: a live MapKit view renders blank in offscreen export.
        .init(id: "map", title: "Map", systemImage: "map", section: Section.reference, includeInPDF: false) { ctx in
            ReportMapCard(report: ctx.report)
        },
        .init(id: "sources", title: "Sources & licence", systemImage: "link", section: Section.reference) { ctx in
            SourcesCard(report: ctx.report)
        },
    ]

    /// Exportable cards grouped by section, preserving catalog order — drives
    /// the checkbox list in `ExportReportSheet`.
    static var pdfSections: [(title: String, cards: [ReportCardDescriptor])] {
        var out: [(title: String, cards: [ReportCardDescriptor])] = []
        for card in all where card.includeInPDF {
            if out.last?.title == card.section {
                out[out.count - 1].cards.append(card)
            } else {
                out.append((card.section, [card]))
            }
        }
        return out
    }
}
