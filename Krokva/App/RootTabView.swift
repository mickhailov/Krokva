import SwiftUI

struct RootTabView: View {
    @State private var selection = 0
    @State private var router = ReportRouter()

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            NavigationStack {
                SavedReportsView()
            }
                .tabItem { Label("Report", systemImage: "doc.text.magnifyingglass") }
                .tag(1)

            PropertyCompareView(selectedTab: $selection)
                .tabItem { Label("Compare", systemImage: "arrow.left.arrow.right") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(Color.cleanSky)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environment(router)
        .onChange(of: router.pendingReport?.id) { _, newValue in
            if newValue != nil { selection = 1 }
        }
    }
}
