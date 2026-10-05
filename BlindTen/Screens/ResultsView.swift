import StoreKit
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
                if let card = state.houseRuleCards[engine.round], let loser {
                    Section {
                        HouseRuleCard(playerName: loser.name, text: card)
                    }
                    .listRowBackground(Theme.accent)
                }
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
                    Button("Final results") { state.advance() }
                } else {
                    Button("Next round") { state.advance() }
                }
            }
            .buttonStyle(.primary)
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

/// Final leaderboard with Rematch, New game and Share.
struct GameResultsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.requestReview) private var requestReview
    @State private var shareImage: Image?
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
                if !state.awards.isEmpty {
                    Section {
                        ForEach(state.awards, id: \.kind) { award in
                            AwardRow(award: award, player: engine.player(withID: award.playerID))
                        }
                    } header: {
                        SectionHeader(title: "Awards")
                    } footer: {
                        Text(state.awardsCoverGroupHistory
                             ? LocalizedStringKey("All-time awards for this group.")
                             : LocalizedStringKey("Awards for this game."))
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

            VStack(spacing: 12) {
                if let shareImage {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview("My Blind Ten results", image: shareImage)
                    ) {
                        Label("Share results", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.secondary)
                }
                HStack(spacing: 16) {
                    Button("Rematch") { state.rematch() }
                        .buttonStyle(.primary)
                    Button("New game") { state.newGame() }
                        .buttonStyle(.secondary)
                }
            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
        .task {
            if let image = ShareCardRenderer.image(for: ShareSummary(engine: engine)) {
                shareImage = Image(uiImage: image)
            }
        }
        .task(id: state.wantsReviewPrompt) {
            // SPEC.md: only after a DEAD ON or a close final; give the moment a beat first.
            guard state.wantsReviewPrompt else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            requestReview()
            state.didRequestReview()
        }
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

/// The card the round loser drew (house rules).
private struct HouseRuleCard: View {
    let playerName: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("\(playerName) draws a card")
            } icon: {
                Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill")
            }
            .font(.headline.weight(.heavy))
            Text(verbatim: text)
                .font(.title2.weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.onAccent)
        .padding(.vertical, 8)
    }
}

/// One funny award (SPEC.md "Streaks & stats").
private struct AwardRow: View {
    let award: Award
    let player: Player?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(Theme.accent)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.primaryText)
                Text(verbatim: "\(player?.emoji ?? "") \(player?.name ?? "")")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                detail
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Theme.surface)
    }

    private var symbol: String {
        switch award.kind {
        case .bestEver: "trophy.fill"
        case .deadEye: "scope"
        case .impatient: "hare.fill"
        case .dawdler: "tortoise.fill"
        case .hairTrigger: "bolt.fill"
        }
    }

    private var title: Text {
        switch award.kind {
        case .bestEver: Text("Best Ever")
        case .deadEye: Text("Dead Eye")
        case .impatient: Text("The Impatient One")
        case .dawdler: Text("The Dawdler")
        case .hairTrigger: Text("Hair Trigger")
        }
    }

    private var detail: Text {
        let percent = Int((award.value * 100).rounded())
        let count = Int(award.value.rounded())
        switch award.kind {
        case .bestEver: return Text("Closest ever: \(TimeFormat.seconds(award.value)) s off")
        case .deadEye: return Text("\(count) DEAD ONs")
        case .impatient: return Text("Too early \(percent)% of the time")
        case .dawdler: return Text("Too late \(percent)% of the time")
        case .hairTrigger: return Text("\(count) misfires")
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
