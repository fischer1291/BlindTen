import SwiftUI
import UIKit

/// Routes the game phases to their screens and owns game-wide side effects.
struct GameView: View {
    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    let engine: GameEngine

    var body: some View {
        content
            .foregroundStyle(Theme.primaryText)
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                state.feel.stopAll()
                ScreenBrightness.restore()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // SPEC.md: app leaves the foreground mid-turn → turn is voided and replayed.
                if newPhase != .active {
                    state.voidTurn()
                    state.feel.stopAll()
                    ScreenBrightness.restore()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .handoff:
            HandoffView(engine: engine)
        case .ready, .running:
            if engine.lanes.count == 2 {
                ShowdownTurnView(engine: engine)
            } else {
                TurnView(engine: engine)
            }
        case .reveal:
            RevealView(engine: engine, results: engine.revealedResults)
        case .roundResults:
            RoundResultsView(engine: engine)
        case .finished:
            GameResultsView(engine: engine)
        }
    }
}
