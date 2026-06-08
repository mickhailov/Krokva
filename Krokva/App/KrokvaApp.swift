import SwiftData
import SwiftUI

@main
struct KrokvaApp: App {
    var body: some Scene {
        WindowGroup {
            SplashGateView {
                RootTabView()
            }
            .modelContainer(for: [RecentSearch.self, CityVote.self, CachedDataset.self])
            .preferredColorScheme(.light)
        }
    }
}

struct SplashGateView<Content: View>: View {
    @State private var isShowingSplash = true
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content.opacity(isShowingSplash ? 0 : 1)
            if isShowingSplash {
                KrokvaSplashView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(1450))
            withAnimation(.easeInOut(duration: 0.25)) {
                isShowingSplash = false
            }
        }
    }
}
