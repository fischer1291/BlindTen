import SwiftUI

/// "Pass the phone to Mia". Tap anywhere to continue.
struct HandoffView: View {
    @Environment(AppState.self) private var state
    @State private var confirmingEndGame = false
    let engine: GameEngine

    var body: some View {
        Button {
            state.engine?.beginTurn()
        } label: {
            VStack(spacing: 24) {
                Text("Round \(engine.round) of \(engine.rounds)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Pass the phone to")
                    .font(.title2)
                Text(engine.currentPlayer?.emoji ?? "")
                    .font(.system(size: 96))
                Text(engine.currentPlayer?.name ?? "")
                    .font(.system(size: 56, weight: .bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                Text("Tap anywhere when ready")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            Button("End game", role: .destructive) {
                confirmingEndGame = true
            }
            .padding()
        }
        .confirmationDialog("End this game?", isPresented: $confirmingEndGame, titleVisibility: .visible) {
            Button("End game", role: .destructive) {
                state.newGame()
            }
        }
    }
}
