import SwiftUI

struct RootTabView: View {
    @State private var selection = 0
    @State private var selectedDossier: AddressDossier?

    var body: some View {
        TabView(selection: $selection) {
            SearchView(selectedDossier: $selectedDossier, selectedTab: $selection)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(0)

            CityMapView(dossier: selectedDossier)
                .tabItem { Label("Map", systemImage: "map") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
        .tint(Color.krokvaGold)
        .toolbarBackground(Color.krokvaSurface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
