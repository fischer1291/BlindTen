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
            VStack(spacing: 20) {
                Text("Round \(engine.round) of \(engine.rounds)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("Pass the phone to")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                Text(engine.currentPlayer?.emoji ?? "")
                    .font(.system(size: 120))
                Text(engine.currentPlayer?.name ?? "")
                    .font(Theme.display(72))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.4)
                Spacer()
                Text("Tap anywhere when ready")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            Button("End game", role: .destructive) {
                confirmingEndGame = true
            }
            .font(.headline)
            .padding()
        }
        .confirmationDialog("End this game?", isPresented: $confirmingEndGame, titleVisibility: .visible) {
            Button("End game", role: .destructive) {
                state.newGame()
            }
        }
    }
}
