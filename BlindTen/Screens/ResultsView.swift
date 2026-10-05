import SwiftUI

/// Leaderboard after each round, with the round loser highlighted.
struct RoundResultsView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine

    var body: some View {
        let loser = engine.roundLoser(engine.round)
        VStack(spacing: 0) {
            Text("Round \(engine.round) results")
                .font(.largeTitle.bold())
                .padding()
            List {
                Section("This round") {
                    StandingsList(standings: engine.standings(round: engine.round), highlighted: loser?.id)
                }
                if engine.round > 1 {
                    Section("Total") {
                        StandingsList(standings: engine.standings())
                    }
                }
            }
            Group {
                if engine.isLastRound {
                    Button("Final results") { state.engine?.advance() }
                } else {
                    Button("Next round") { state.engine?.advance() }
                }
            }
            .font(.title2.bold())
            .frame(maxWidth: .infinity, minHeight: 64)
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}

/// Final leaderboard with Rematch and New game.
struct GameResultsView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine

    var body: some View {
        VStack(spacing: 0) {
            if let winner = engine.winner {
                VStack(spacing: 8) {
                    Text("Winner")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(winner.emoji)
                        .font(.system(size: 72))
                    Text(winner.name)
                        .font(.system(size: 48, weight: .bold))
                }
                .padding()
            }
            List {
                StandingsList(standings: engine.standings())
            }
            HStack(spacing: 16) {
                Button("Rematch") { state.rematch() }
                    .buttonStyle(.borderedProminent)
                Button("New game") { state.newGame() }
                    .buttonStyle(.bordered)
            }
            .font(.title3.bold())
            .controlSize(.large)
            .padding()
        }
    }
}

/// Ranked rows: rank, avatar, name, points and total deviation.
struct StandingsList: View {
    let standings: [Standing]
    var highlighted: Player.ID?

    var body: some View {
        ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
            let isHighlighted = standing.id == highlighted
            HStack(spacing: 12) {
                Text(verbatim: "\(index + 1).")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(standing.player.emoji)
                VStack(alignment: .leading) {
                    Text(standing.player.name)
                        .font(.title3.bold())
                    if isHighlighted {
                        Text("Round loser")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(standing.points) points")
                        .font(.title3.bold())
                    Text("\(TimeFormat.seconds(standing.totalDeviation)) s off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
            }
            .listRowBackground(isHighlighted ? Color.red.opacity(0.25) : nil)
        }
    }
}
