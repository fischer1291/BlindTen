import SwiftUI

/// Leaderboard after each round, with the round loser highlighted.
struct RoundResultsView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine

    var body: some View {
        let loser = engine.roundLoser(engine.round)
        VStack(spacing: 0) {
            Text("Round \(engine.round) results")
                .font(Theme.display(40))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 24)
                .padding(.horizontal)
            List {
                Section {
                    StandingsList(standings: engine.standings(round: engine.round), highlighted: loser?.id)
                } header: {
                    SectionHeader(title: "This round")
                }
                if engine.round > 1 {
                    Section {
                        StandingsList(standings: engine.standings())
                    } header: {
                        SectionHeader(title: "Total")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            Group {
                if engine.isLastRound {
                    Button("Final results") { state.engine?.advance() }
                } else {
                    Button("Next round") { state.engine?.advance() }
                }
            }
            .buttonStyle(.primary)
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

/// Final leaderboard with Rematch and New game.
struct GameResultsView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine

    var body: some View {
        VStack(spacing: 0) {
            if let winner = engine.winner {
                VStack(spacing: 4) {
                    Text("Winner")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                    Text(winner.emoji)
                        .font(.system(size: 88))
                    Text(winner.name)
                        .font(Theme.display(60))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
                .padding(.top, 24)
                .padding(.horizontal)
            }
            List {
                StandingsList(standings: engine.standings())
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            HStack(spacing: 16) {
                Button("Rematch") { state.rematch() }
                    .buttonStyle(.primary)
                Button("New game") { state.newGame() }
                    .buttonStyle(.secondary)
            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Theme.secondaryText)
    }
}

/// Ranked rows: rank, avatar, name, points and total deviation.
struct StandingsList: View {
    let standings: [Standing]
    var highlighted: Player.ID?

    var body: some View {
        ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
            let isHighlighted = standing.id == highlighted
            HStack(spacing: 14) {
                Text(verbatim: "\(index + 1)")
                    .font(Theme.display(28))
                    .monospacedDigit()
                    .foregroundStyle(index == 0 ? Theme.accent : Theme.secondaryText)
                    .frame(minWidth: 32)
                Text(standing.player.emoji)
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(standing.player.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if isHighlighted {
                        Text("Round loser")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(Theme.late)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(standing.points) points")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.primaryText)
                    Text("\(TimeFormat.seconds(standing.totalDeviation)) s off")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                .monospacedDigit()
            }
            .padding(.vertical, 6)
            .listRowBackground(isHighlighted ? Theme.late.opacity(0.25) : Theme.surface)
        }
    }
}
