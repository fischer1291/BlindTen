import SwiftUI

/// Stopped time, deviation and tier. Advances after 3 s or on tap.
struct RevealView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine
    let result: TurnResult

    private static let autoAdvanceDelay: Duration = .seconds(3)

    var body: some View {
        Button {
            advance()
        } label: {
            VStack(spacing: 16) {
                Text(engine.player(withID: result.playerID)?.name ?? "")
                    .font(.title2)
                outcome
                Text("+\(result.points) points")
                    .font(.title2.bold())
                Text("Tap to continue")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Button("Wrong player? Replay turn") {
                state.engine?.replayTurn()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
        .task(id: result.id) {
            try? await Task.sleep(for: Self.autoAdvanceDelay)
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    @ViewBuilder
    private var outcome: some View {
        switch result.outcome {
        case .misfire:
            Text("Too eager!")
                .font(.system(size: 48, weight: .bold))
            Text("\(TimeFormat.seconds(result.stopped)) s")
                .font(.title)
                .monospacedDigit()
        case .timeout:
            Text("Still waiting...")
                .font(.system(size: 48, weight: .bold))
        case .scored(let tier):
            Text("\(TimeFormat.seconds(result.displayedStopped)) s")
                .font(.system(size: 80, weight: .bold))
                .monospacedDigit()
            Text(TimeFormat.signedDeviation(result.displayedDeviation))
                .font(.title)
                .monospacedDigit()
            Text(tier.label)
                .font(.system(size: 48, weight: .heavy))
        }
    }

    /// Advances only if this reveal is still on screen.
    private func advance() {
        guard case .some(.reveal(let current)) = state.engine?.phase, current.id == result.id else { return }
        state.engine?.advance()
    }
}
