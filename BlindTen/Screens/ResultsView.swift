import SwiftUI

/// Leaderboard after each round, with the round loser highlighted.
struct RoundResultsView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine

    /// Elimination: the player knocked out this round.
    private var knockedOut: Player? {
        guard engine.mode.eliminatesRoundLoser, engine.eliminated.count == engine.round,
              let id = engine.eliminated.last
        else { return nil }
        return engine.player(withID: id)
    }

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
            if let knockedOut {
                Text("\(knockedOut.name) is out!")
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.late)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal)
            }
            List {
                if engine.mode.hasTeams {
                    Section {
                        TeamList(teams: engine.teamStandings())
                    } header: {
                        SectionHeader(title: "Teams")
                    }
                }
                Section {
                    StandingsList(engine: engine, standings: engine.standings(round: engine.round), highlighted: loser?.id)
                } header: {
                    SectionHeader(title: "This round")
                }
                if engine.round > 1 {
                    Section {
                        StandingsList(engine: engine, standings: engine.standings())
                    } header: {
                        SectionHeader(title: "Total")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            Group {
                if engine.isFinalRound {
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
            winnerHeader
                .padding(.top, 24)
                .padding(.horizontal)
            List {
                if engine.mode.hasTeams {
                    Section {
                        TeamList(teams: engine.teamStandings())
                    } header: {
                        SectionHeader(title: "Teams")
                    }
                }
                Section {
                    StandingsList(engine: engine, standings: engine.standings())
                } header: {
                    SectionHeader(title: "Players")
                }
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

    @ViewBuilder
    private var winnerHeader: some View {
        if engine.mode.hasTeams {
            if let team = engine.winningTeam {
                Text("Team \(team + 1) wins!")
                    .font(Theme.display(52))
                    .foregroundStyle(Theme.color(forTeam: team))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                Text("It's a tie!")
                    .font(Theme.display(52))
                    .foregroundStyle(Theme.accent)
            }
        } else if let winner = engine.winner {
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
        }
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

/// Teams ranked by deviation per turn.
private struct TeamList: View {
    let teams: [TeamStanding]

    var body: some View {
        ForEach(teams) { team in
            HStack(spacing: 14) {
                Circle()
                    .fill(Theme.color(forTeam: team.team))
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    TeamName(team: team.team)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.primaryText)
                    Text(verbatim: team.members.map(\.emoji).joined(separator: " "))
                        .font(.title3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(TimeFormat.seconds(team.totalDeviation)) s off")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Theme.primaryText)
                    Text("\(TimeFormat.seconds(team.averageDeviation)) s per turn")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                .monospacedDigit()
            }
            .padding(.vertical, 6)
            .listRowBackground(Theme.surface)
        }
    }
}

/// Ranked rows: rank, avatar, name, points and total deviation, plus the
/// mode's extra column (duel wins, knock-out round, team).
struct StandingsList: View {
    let engine: GameEngine
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
                    detail(for: standing, isHighlighted: isHighlighted)
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
            .opacity(standing.eliminatedInRound == nil ? 1 : 0.6)
            .listRowBackground(isHighlighted ? Theme.late.opacity(0.25) : Theme.surface)
        }
    }

    @ViewBuilder
    private func detail(for standing: Standing, isHighlighted: Bool) -> some View {
        if isHighlighted {
            Text(engine.mode.eliminatesRoundLoser ? LocalizedStringKey("Knocked out") : LocalizedStringKey("Round loser"))
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.late)
        } else if let round = standing.eliminatedInRound {
            Text("Out in round \(round)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.late)
        }
        if engine.mode.playersPerTurn == 2 {
            Text("\(standing.duelWins) duel wins")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.accent)
        }
        if let team = standing.team {
            TeamName(team: team)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.color(forTeam: team))
        }
    }
}
