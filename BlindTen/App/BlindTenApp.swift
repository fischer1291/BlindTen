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
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if let engine = state.engine {
            GameView(engine: engine)
        } else {
            NavigationStack {
                PlayersView()
            }
        }
    }
}
