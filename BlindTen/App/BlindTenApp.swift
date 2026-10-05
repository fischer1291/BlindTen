import SwiftData
import SwiftUI

@main
@MainActor
struct BlindTenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @State private var state: AppState

    init() {
        let container: ModelContainer
        if let onDisk = try? GameStore.makeContainer() {
            container = onDisk
        } else {
            // Storage failed to open: still let people play, without history.
            do {
                container = try GameStore.makeContainer(inMemory: true)
            } catch {
                fatalError("Could not create even an in-memory store: \(error)")
            }
        }
        self.container = container
        let appState = AppState(store: GameStore(context: container.mainContext))
        _state = State(initialValue: appState)
        ExternalDisplay.state = appState
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    state.feel.prepare()
                    state.purchases.start()
                    state.store?.seedDefaultHouseRules()
                }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var showsSplash = true

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let engine = state.engine {
                GameView(engine: engine)
            } else {
                NavigationStack {
                    HomeView()
                }
            }
            if showsSplash {
                SplashView { showsSplash = false }
                    .zIndex(1)
            }
        }
    }
}
