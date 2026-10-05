import SwiftUI

/// Drumroll with a slot-machine count-up, then the result lands: tier,
/// deviation arrow, reaction line, haptics and sound. DEAD ON adds a flash,
/// confetti and the player's name in huge type. Showdown shows both players
/// and the duel winner. Advances 3 s after landing or on tap; a tap during
/// the drumroll skips straight to the result.
struct RevealView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let engine: GameEngine
    let results: [TurnResult]

    @State private var drumrollDuration = RevealTiming.randomDrumrollDuration()
    @State private var drumrollStart = ProcessInfo.processInfo.systemUptime
    @State private var landed = false
    @State private var skipRequested = false
    @State private var flashOpacity = 0.0
    @State private var confettiStart: TimeInterval?

    private var isDuel: Bool { results.count == 2 }

    /// DEAD ON wins over everything; fail only when nobody did better.
    private var cue: LandingCue {
        let cues = results.map { LandingCue($0.outcome) }
        if cues.contains(.deadOn) { return .deadOn }
        if !cues.isEmpty, cues.allSatisfy({ $0 == .fail }) { return .fail }
        return .neutral
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Button {
                handleTap()
            } label: {
                Group {
                    if isDuel {
                        duelContent
                    } else if let result = results.first {
                        singleContent(result)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let confettiStart {
                ConfettiView(startTime: confettiStart)
            }

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if landed {
                Button(isDuel ? LocalizedStringKey("Wrong players? Replay duel") : LocalizedStringKey("Wrong player? Replay turn")) {
                    state.engine?.replayTurn()
                }
                .font(.headline)
                .foregroundStyle(Theme.secondaryText)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(Theme.surface, in: Capsule())
                .padding(.bottom, 24)
            }
        }
        .task(id: RevealTaskID(resultID: results.first?.id, skipped: skipRequested)) {
            await runReveal()
        }
        .onDisappear {
            state.feel.endDrumroll()
        }
    }

    // MARK: - Single

    private func singleContent(_ result: TurnResult) -> some View {
        let isDeadOnMoment = landed && LandingCue(result.outcome) == .deadOn
        return VStack(spacing: 16) {
            Text(engine.player(withID: result.playerID)?.name ?? "")
                .font(isDeadOnMoment ? Theme.display(76) : .title.weight(.bold))
                .foregroundStyle(isDeadOnMoment ? Theme.accent : Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.4)

            CountUpNumber(value: shownValue(for: result), size: 96, isLanded: landed)

            if landed {
                VStack(spacing: 16) {
                    verdict(for: result, compact: false)
                    reaction(for: result)
                    Text("+\(result.points) points")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.secondaryText)
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: landed)
    }

    // MARK: - Duel

    private var duelContent: some View {
        let winner = GameEngine.duelWinner(of: results)
        return VStack(spacing: 20) {
            Text("Showdown")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.accent)
            ForEach(results) { result in
                duelRow(result, isWinner: landed && result.playerID == winner)
            }
            if landed {
                Group {
                    if let winner, let name = engine.player(withID: winner)?.name {
                        Text("\(name) wins the duel!")
                    } else {
                        Text("It's a tie!")
                    }
                }
                .font(Theme.display(40))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: landed)
    }

    private func duelRow(_ result: TurnResult, isWinner: Bool) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(verbatim: "\(engine.player(withID: result.playerID)?.emoji ?? "") \(engine.player(withID: result.playerID)?.name ?? "")")
                    .font(.title2.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer()
                CountUpNumber(value: shownValue(for: result), size: 48, isLanded: landed)
            }
            if landed {
                HStack {
                    verdict(for: result, compact: true)
                    Spacer()
                    Text("+\(result.points) points")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.secondaryText)
                }
                reaction(for: result)
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Theme.accent, lineWidth: isWinner ? 4 : 0)
        }
    }

    // MARK: - Shared pieces

    @ViewBuilder
    private func verdict(for result: TurnResult, compact: Bool) -> some View {
        switch result.outcome {
        case .scored(let tier):
            if compact {
                HStack(spacing: 10) {
                    Text(tier.label)
                        .foregroundStyle(Theme.color(for: tier))
                    DeviationLabel(result: result, compact: true)
                }
                .font(.title3.weight(.heavy))
            } else {
                DeviationLabel(result: result, compact: false)
                Text(tier.label)
                    .font(Theme.display(60))
                    .foregroundStyle(Theme.color(for: tier))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        case .misfire:
            Text("Too eager!")
                .font(compact ? .title3.weight(.heavy) : Theme.display(56))
                .foregroundStyle(Theme.early)
        case .timeout:
            Text("Still waiting...")
                .font(compact ? .title3.weight(.heavy) : Theme.display(56))
                .foregroundStyle(Theme.late)
        }
    }

    @ViewBuilder
    private func reaction(for result: TurnResult) -> some View {
        if let line = state.reactionText(for: result) {
            Text(verbatim: line)
                .font(isDuel ? .body.weight(.semibold) : .title2.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Sequence

    /// The value shown right now: counting up during the drumroll, final once landed.
    private func shownValue(for result: TurnResult) -> () -> TimeInterval? {
        let final: TimeInterval
        switch result.outcome {
        case .scored: final = result.displayedStopped
        case .misfire, .timeout: final = result.stopped
        }
        let isLanded = landed
        let hidden = reduceMotion
        let start = drumrollStart
        let duration = drumrollDuration
        return {
            if isLanded { return final }
            if hidden { return nil }
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            return SlotRoll.value(progress: elapsed / duration, target: final)
        }
    }

    private func runReveal() async {
        if !landed && !skipRequested {
            drumrollStart = ProcessInfo.processInfo.systemUptime
            state.feel.beginDrumroll(duration: drumrollDuration)
            try? await Task.sleep(for: .seconds(drumrollDuration))
            guard !Task.isCancelled else { return }
        }
        if !landed {
            await land()
        }
        try? await Task.sleep(for: RevealTiming.autoAdvanceDelay)
        guard !Task.isCancelled else { return }
        advance()
    }

    private func land() async {
        landed = true
        state.feel.land(cue)
        guard cue == .deadOn, !reduceMotion else { return }
        confettiStart = ProcessInfo.processInfo.systemUptime
        flashOpacity = 0.85
        try? await Task.sleep(for: .milliseconds(50))
        withAnimation(.easeOut(duration: 0.5)) {
            flashOpacity = 0
        }
    }

    private func handleTap() {
        if landed {
            advance()
        } else {
            skipRequested = true
        }
    }

    /// Advances only if this reveal is still on screen.
    private func advance() {
        guard state.engine?.phase == .reveal,
              state.engine?.revealedResults.first?.id == results.first?.id
        else { return }
        state.advance()
    }
}

/// The slot-machine number. Re-evaluates `value` every frame until landed.
private struct CountUpNumber: View {
    let value: () -> TimeInterval?
    let size: CGFloat
    let isLanded: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: isLanded)) { _ in
            Group {
                if let current = value() {
                    Text("\(TimeFormat.seconds(current)) s")
                } else {
                    Text(verbatim: "?")
                }
            }
            .font(Theme.display(size))
            .monospacedDigit()
            .foregroundStyle(Theme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
        }
    }
}

/// "+0.27" with a colored arrow: blue = too early, red = too late.
private struct DeviationLabel: View {
    let result: TurnResult
    let compact: Bool

    var body: some View {
        let direction = result.direction
        VStack(spacing: 4) {
            HStack(spacing: compact ? 4 : 10) {
                switch direction {
                case .early:
                    Image(systemName: "arrow.down.circle.fill")
                case .late:
                    Image(systemName: "arrow.up.circle.fill")
                case .exact:
                    EmptyView()
                }
                Text(TimeFormat.signedDeviation(result.displayedDeviation))
                    .monospacedDigit()
            }
            .font(compact ? .title3.weight(.heavy) : Theme.display(40))
            if !compact {
                switch direction {
                case .early:
                    Text("Too early").font(.headline)
                case .late:
                    Text("Too late").font(.headline)
                case .exact:
                    EmptyView()
                }
            }
        }
        .foregroundStyle(Theme.color(for: direction))
        .accessibilityElement(children: .combine)
    }
}

private struct RevealTaskID: Hashable {
    let resultID: TurnResult.ID?
    let skipped: Bool
}
