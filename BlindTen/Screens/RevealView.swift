import SwiftUI

/// Drumroll with a slot-machine count-up, then the result lands: tier,
/// deviation arrow, reaction line, haptics and sound. DEAD ON adds a flash,
/// confetti and the player's name in huge type. Advances 3 s after landing
/// or on tap; a tap during the drumroll skips straight to the result.
struct RevealView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let engine: GameEngine
    let result: TurnResult

    @State private var drumrollDuration = RevealTiming.randomDrumrollDuration()
    @State private var drumrollStart = ProcessInfo.processInfo.systemUptime
    @State private var landed = false
    @State private var skipRequested = false
    @State private var flashOpacity = 0.0
    @State private var confettiStart: TimeInterval?

    private var player: Player? { engine.player(withID: result.playerID) }
    private var cue: LandingCue { LandingCue(result.outcome) }
    private var isDeadOnMoment: Bool { landed && cue == .deadOn }

    /// The number the count-up lands on.
    private var finalValue: TimeInterval {
        switch result.outcome {
        case .scored: result.displayedStopped
        case .misfire, .timeout: result.stopped
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Button {
                handleTap()
            } label: {
                content
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
                Button("Wrong player? Replay turn") {
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
        .task(id: RevealTaskID(resultID: result.id, skipped: skipRequested)) {
            await runReveal()
        }
        .onDisappear {
            state.feel.endDrumroll()
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 16) {
            Text(player?.name ?? "")
                .font(isDeadOnMoment ? Theme.display(76) : .title.weight(.bold))
                .foregroundStyle(isDeadOnMoment ? Theme.accent : Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.4)

            number

            if landed {
                verdict
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: landed)
    }

    private var number: some View {
        TimelineView(.animation(minimumInterval: nil, paused: landed)) { _ in
            Group {
                if let value = shownValue() {
                    Text("\(TimeFormat.seconds(value)) s")
                } else {
                    Text(verbatim: "?")
                }
            }
            .font(Theme.display(96))
            .monospacedDigit()
            .foregroundStyle(Theme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .scaleEffect(landed ? 1.0 : 0.9)
        }
    }

    @ViewBuilder
    private var verdict: some View {
        switch result.outcome {
        case .scored(let tier):
            deviationRow
            Text(tier.label)
                .font(Theme.display(60))
                .foregroundStyle(Theme.color(for: tier))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        case .misfire:
            Text("Too eager!")
                .font(Theme.display(56))
                .foregroundStyle(Theme.early)
        case .timeout:
            Text("Still waiting...")
                .font(Theme.display(56))
                .foregroundStyle(Theme.late)
        }

        if let line = state.reactionText(for: result) {
            Text(verbatim: line)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }

        Text("+\(result.points) points")
            .font(.title2.weight(.heavy))
            .foregroundStyle(Theme.secondaryText)
    }

    /// "+0.27" with a colored arrow: blue = too early, red = too late.
    private var deviationRow: some View {
        let direction = result.direction
        return VStack(spacing: 4) {
            HStack(spacing: 10) {
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
            .font(Theme.display(40))
            switch direction {
            case .early:
                Text("Too early").font(.headline)
            case .late:
                Text("Too late").font(.headline)
            case .exact:
                EmptyView()
            }
        }
        .foregroundStyle(Theme.color(for: direction))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sequence

    /// The value shown right now: counting up during the drumroll, final once landed.
    private func shownValue() -> TimeInterval? {
        if landed { return finalValue }
        if reduceMotion { return nil }
        let elapsed = ProcessInfo.processInfo.systemUptime - drumrollStart
        return SlotRoll.value(progress: elapsed / drumrollDuration, target: finalValue)
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
        guard case .some(.reveal(let current)) = state.engine?.phase, current.id == result.id else { return }
        state.engine?.advance()
    }
}

private struct RevealTaskID: Hashable {
    let resultID: TurnResult.ID
    let skipped: Bool
}
