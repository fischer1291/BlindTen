import SwiftUI

/// What the TV shows. Big type for a 16:9 screen across the room. It only
/// observes the game; all input stays on the phone. Nothing here changes at
/// a regular rhythm during the blind phase.
struct TVView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let engine = state.engine {
                TVGameView(engine: engine)
            } else {
                TVIdleView()
            }
        }
        .foregroundStyle(Theme.primaryText)
    }
}

private struct TVIdleView: View {
    var body: some View {
        VStack(spacing: 32) {
            LogoMark()
                .frame(width: 260, height: 260)
            Text("BLIND TEN")
                .font(Theme.display(96))
                .tracking(8)
            Text("Pick a mode and the players on the phone.")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

private struct TVGameView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine

    var body: some View {
        switch engine.phase {
        case .handoff:
            HStack(spacing: 80) {
                VStack(spacing: 24) {
                    roundLine
                    Text("Pass the phone to")
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    playersLine(size: 120)
                }
                .frame(maxWidth: .infinity)
                if !engine.results.isEmpty {
                    TVLeaderboard(engine: engine, standings: engine.standings())
                        .frame(maxWidth: 700)
                }
            }
            .padding(80)
        case .ready:
            VStack(spacing: 32) {
                playersLine(size: 96)
                Text("Stop at \(TimeFormat.seconds(engine.target))")
                    .font(Theme.display(110))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
            }
        case .running:
            VStack(spacing: 32) {
                playersLine(size: 80)
                    .opacity(0.5)
                Text("Silence…")
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.4))
            }
        case .reveal:
            TVRevealView(engine: engine, results: engine.revealedResults, presentation: state.revealPresentation)
        case .roundResults:
            VStack(spacing: 32) {
                Text("Round \(engine.round) results")
                    .font(Theme.display(80))
                if let card = state.houseRuleCards[engine.round], let loser = engine.roundLoser(engine.round) {
                    VStack(spacing: 8) {
                        Text("\(loser.name) draws a card")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                        Text(verbatim: card)
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Theme.onAccent)
                    .padding(32)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 32))
                }
                TVLeaderboard(engine: engine, standings: engine.standings(), highlighted: engine.roundLoser(engine.round)?.id)
                    .frame(maxWidth: 1100)
            }
            .padding(60)
        case .finished:
            VStack(spacing: 32) {
                if engine.mode.hasTeams, let team = engine.winningTeam {
                    Text("Team \(team + 1) wins!")
                        .font(Theme.display(110))
                        .foregroundStyle(Theme.color(forTeam: team))
                } else if let winner = engine.winner {
                    Text(verbatim: "\(winner.emoji) \(winner.name)")
                        .font(Theme.display(120))
                        .foregroundStyle(Theme.accent)
                    Text("Winner")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                TVLeaderboard(engine: engine, standings: engine.standings())
                    .frame(maxWidth: 1100)
            }
            .padding(60)
        }
    }

    private var roundLine: some View {
        HStack(spacing: 16) {
            Text(engine.mode.kind.title)
                .foregroundStyle(Theme.accent)
            Text("Round \(engine.round) of \(engine.rounds)")
                .foregroundStyle(Theme.secondaryText)
        }
        .font(.system(size: 40, weight: .heavy, design: .rounded))
    }

    private func playersLine(size: CGFloat) -> some View {
        let names = engine.currentPlayers.map { "\($0.emoji) \($0.name)" }
        return Text(verbatim: names.joined(separator: "  vs  "))
            .font(Theme.display(size))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }
}

/// The big reveal, spinning in sync with the phone's drumroll.
private struct TVRevealView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine
    let results: [TurnResult]
    let presentation: RevealPresentation?

    /// The phone's timing for these results, if it is reporting one.
    private var timing: RevealPresentation? {
        guard let presentation, presentation.firstResultID == results.first?.id else { return nil }
        return presentation
    }

    private var landed: Bool { timing.map { $0.landedAt != nil } ?? true }

    var body: some View {
        ZStack {
            HStack(spacing: 80) {
                ForEach(results) { result in
                    column(for: result)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(80)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: landed)

            if landed, results.contains(where: { $0.outcome == .scored(.deadOn) }),
               let landedAt = timing?.landedAt {
                ConfettiView(startTime: landedAt)
            }
        }
    }

    private func column(for result: TurnResult) -> some View {
        let player = engine.player(withID: result.playerID)
        let isWinner = results.count == 2 && landed && GameEngine.duelWinner(of: results) == result.playerID
        return VStack(spacing: 24) {
            Text(verbatim: "\(player?.emoji ?? "") \(player?.name ?? "")")
                .font(Theme.display(results.count == 2 ? 64 : 80))
                .foregroundStyle(isWinner ? Theme.accent : Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            TimelineView(.animation(minimumInterval: nil, paused: landed)) { _ in
                Text("\(TimeFormat.seconds(shownValue(for: result))) s")
                    .font(Theme.display(results.count == 2 ? 140 : 200))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            if landed {
                VStack(spacing: 16) {
                    verdict(for: result)
                    if let line = state.reactionText(for: result) {
                        Text(verbatim: line)
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                    }
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func verdict(for result: TurnResult) -> some View {
        switch result.outcome {
        case .scored(let tier):
            HStack(spacing: 32) {
                Text(tier.label)
                    .foregroundStyle(Theme.color(for: tier))
                Text(verbatim: TimeFormat.signedDeviation(result.displayedDeviation))
                    .monospacedDigit()
                    .foregroundStyle(Theme.color(for: result.direction))
            }
            .font(Theme.display(72))
        case .misfire:
            Text("Too eager!")
                .font(Theme.display(80))
                .foregroundStyle(Theme.early)
        case .timeout:
            Text("Still waiting...")
                .font(Theme.display(80))
                .foregroundStyle(Theme.late)
        }
    }

    private func shownValue(for result: TurnResult) -> TimeInterval {
        let final: TimeInterval
        switch result.outcome {
        case .scored: final = result.displayedStopped
        case .misfire, .timeout: final = result.stopped
        }
        guard let timing, timing.landedAt == nil else { return final }
        let elapsed = ProcessInfo.processInfo.systemUptime - timing.drumrollStart
        return SlotRoll.value(progress: elapsed / timing.drumrollDuration, target: final)
    }
}

private struct TVLeaderboard: View {
    let engine: GameEngine
    let standings: [Standing]
    var highlighted: Player.ID?

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(standings.prefix(8).enumerated()), id: \.element.id) { index, standing in
                HStack(spacing: 24) {
                    Text(verbatim: "\(index + 1)")
                        .foregroundStyle(index == 0 ? Theme.accent : Theme.secondaryText)
                        .frame(width: 60, alignment: .leading)
                    Text(verbatim: "\(standing.player.emoji) \(standing.player.name)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer()
                    Text("\(standing.points) points")
                        .monospacedDigit()
                }
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    standing.id == highlighted ? Theme.late.opacity(0.3) : Theme.surface,
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .opacity(standing.eliminatedInRound == nil ? 1 : 0.5)
            }
        }
    }
}
