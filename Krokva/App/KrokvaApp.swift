import SwiftData
import SwiftUI

@main
struct KrokvaApp: App {
    var body: some Scene {
        WindowGroup {
            SplashGateView {
                RootTabView()
            }
            .modelContainer(for: [RecentSearch.self, CityVote.self, CachedDataset.self, SavedAddress.self, SavedReport.self])
            .preferredColorScheme(.light)
        }
    }
}

struct SplashGateView<Content: View>: View {
    @State private var isShowingSplash = true
    @State private var contentOffset: CGFloat = 18
    @State private var contentOpacity: Double = 0
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .opacity(contentOpacity)
                .offset(y: contentOffset)
            if isShowingSplash {
                KrokvaSplashView()
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 1.04))
                        )
                    )
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(1450))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                isShowingSplash = false
            }
            withAnimation(.easeOut(duration: 0.38).delay(0.08)) {
                contentOpacity = 1
                contentOffset = 0
            }
        }
    }
}
