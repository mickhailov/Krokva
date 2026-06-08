import Charts
import MapKit
import SwiftUI

struct DossierView: View {
    let dossier: AddressDossier
    @State private var permitHistoryRefreshToken = UUID()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if dossier.providerState == .comingSoon {
                    ComingSoonDossierCard(dossier: dossier)
                }
                HeroPropertyCard(dossier: dossier)
                PropertyFactsCard(property: dossier.property)
                PropertyPermitHistoryCard(dossier: dossier, refreshToken: permitHistoryRefreshToken)
                NeighbourhoodValueCard(dossier: dossier)
                ComparablesCard(dossier: dossier)
                PermitsCard(permits: dossier.permits)
                PermitActivityCard(activity: dossier.permitActivity)
                VacantOrdersCard(orders: dossier.vacantOrders)
                InfrastructureCard(summary: dossier.infrastructure)
                ParksAmenitiesCard(summary: dossier.parks)
                TransitAccessCard(summary: dossier.transit)
                DevelopmentContextCard(summary: dossier.development)
                BylawInvestigationsCard(summary: dossier.bylaw)
                RiverAndLibraryCard(river: dossier.river, library: dossier.library)
                ServiceRequestsCard(summary: dossier.serviceRequests)
                PlanningContextCard(summary: dossier.planning)
                StreetAccessCard(summary: dossier.streetAccess)
                EmergencyActivityCard(summary: dossier.emergency)
                PoliceCrimeCard(summary: dossier.policeCrime)
                PublicHealthCard(summary: dossier.publicHealth)
                DossierMapCard(dossier: dossier)
                SourcesCard(dossier: dossier)
            }
            .padding(20)
        }
        .refreshable {
            permitHistoryRefreshToken = UUID()
        }
        .background(Color.krokvaPaper)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.krokvaSurface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("Address dossier")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.krokvaInk)
            }
        }
    }
}

struct ComingSoonDossierCard: View {
    let dossier: AddressDossier

    var body: some View {
        DossierCard(title: "Coming soon", systemImage: "hourglass") {
            Text("We do not have live data for \(dossier.cityName) yet. Vote for this city in Settings to prioritize coverage.")
                .foregroundStyle(Color.krokvaInk2)
        }
    }
}
