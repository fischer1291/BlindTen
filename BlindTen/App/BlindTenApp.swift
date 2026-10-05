import SwiftUI

@main
@MainActor
struct BlindTenApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task { state.feel.prepare() }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let engine = state.engine {
                GameView(engine: engine)
            } else {
                NavigationStack {
                    PlayersView()
                }
            }
        }
    }
}
