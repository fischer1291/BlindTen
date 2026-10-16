import SwiftUI

/// One challenge run, full screen.
///
/// There is no START button: after the anti-cheat explanation the timer
/// starts by itself after a random, silent wait, so a second stopwatch can
/// only be started late. The GO flash and haptic mark the start.
struct ChallengeRunView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let session: ChallengeSession
    var playAgain: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch session.phase {
            case .intro:
                ChallengeIntroView(session: session, close: close)
            case .getReady(let goAt):
                GetReadyView(session: session, goAt: goAt)
            case .running(let startedAt):
                BlindPhaseView(effect: session.effect, target: session.target, startedAt: startedAt) { timestamp in
                    if session.stop(at: timestamp) != nil {
                        state.feel.touch()
                    }
                }
            case .result(let result):
                ChallengeResultView(session: session, result: result)
                    .id(session.run?.turns.count ?? session.dailyTurns.count)
            case .finished:
                ChallengeSummaryView(session: session, close: close, playAgain: playAgain)
            }
        }
        .foregroundStyle(Theme.primaryText)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onAppear {
            state.feel.warmUp()
            UIApplication.shared.isIdleTimerDisabled = true
            ScreenBrightness.maximize()
        }
        .onDisappear {
            session.quit()
            state.reportChallenge(session)
            state.feel.stopAll()
            UIApplication.shared.isIdleTimerDisabled = false
            ScreenBrightness.restore()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Control Center, another app or the lock screen show a clock.
            if newPhase != .active {
                session.appDidLeaveForeground()
                state.feel.stopAll()
            }
        }
        .onChange(of: session.phase) { _, phase in
            if case .finished = phase {
                state.reportChallenge(session)
            }
        }
        .task(id: session.timeoutDeadline) {
            // One-shot wait for the auto-stop at target × 3, not a ticking timer.
            guard let deadline = session.timeoutDeadline else { return }
            while !Task.isCancelled {
                let now = ProcessInfo.processInfo.systemUptime
                if now >= deadline {
                    session.autoStopIfOverdue(now: now)
                    return
                }
                try? await Task.sleep(for: .seconds(deadline - now))
            }
        }
    }

    private func close() {
        session.quit()
        dismiss()
    }
}

// MARK: - Intro

/// Explains the automatic random start before the first turn.
private struct ChallengeIntroView: View {
    @Environment(AppState.self) private var state
    let session: ChallengeSession
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                session.mode.title
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                Spacer()
                CloseButton(action: close)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 12)
                    Text("The timer starts by itself")
                        .font(Theme.display(40))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("We can't control whether you're cheating with a second stopwatch. That's why there is no START button here.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Instead, the timer starts automatically at a random moment, a few seconds after you tap \"I'm ready\". Watch for the yellow flash and the buzz, then stop at exactly the target.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Leaving the app while the timer runs counts as a miss.")
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    targetLine
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("I'm ready") {
                session.getReady(now: ProcessInfo.processInfo.systemUptime)
            }
            .buttonStyle(.primary)
            .padding(.top, 12)
        }
        .padding(24)
    }

    @ViewBuilder
    private var targetLine: some View {
        switch session.mode {
        case .streak(let kind, let difficulty):
            VStack(alignment: .leading, spacing: 6) {
                Text(kind == .classic ? LocalizedStringKey("Target: 10 seconds, every turn.") : LocalizedStringKey("A new target every turn."))
                Text("A hit: \(difficulty.toleranceText(for: kind))")
                    .foregroundStyle(Theme.secondaryText)
            }
        case .daily(let challenge):
            VStack(alignment: .leading, spacing: 6) {
                Text("Stop at \(TimeFormat.seconds(challenge.target))")
                    .font(Theme.display(44))
                    .monospacedDigit()
                Text("Attempts left: \(session.dailyAttemptsLeft)")
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

// MARK: - Get ready

/// The silent wait before the automatic start. Nothing on this screen moves,
/// so it gives away neither the start moment nor a rhythm.
private struct GetReadyView: View {
    @Environment(AppState.self) private var state
    let session: ChallengeSession
    let goAt: TimeInterval

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Get ready…")
                .font(Theme.display(56))
            Text("Prepare yourself now. The timer starts any moment.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Text("Stop at \(TimeFormat.seconds(session.target))")
                .font(Theme.display(44))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if session.falseStarts > 0 {
                Text("Too early! Wait for the flash.")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.late)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            session.falseStart(now: ProcessInfo.processInfo.systemUptime)
        }
        .task(id: goAt) {
            while !Task.isCancelled {
                let now = ProcessInfo.processInfo.systemUptime
                if now >= goAt {
                    session.go(at: now)
                    state.feel.touch()
                    return
                }
                try? await Task.sleep(for: .seconds(goAt - now))
            }
        }
    }
}

// MARK: - Result

/// One turn's result. Waits for a tap, like the party game's reveal.
private struct ChallengeResultView: View {
    @Environment(AppState.self) private var state
    let session: ChallengeSession
    let result: ChallengeTurnResult
    @State private var acceptsTap = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            verdict
            Text(verbatim: TimeFormat.seconds(result.stopped))
                .font(Theme.display(96))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            deviationLine
            details
            Spacer()
            if acceptsTap {
                Text("Tap to continue")
                    .font(.title3.weight(.bold))
                    .transition(.opacity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard acceptsTap else { return }
            session.continueAfterResult(now: ProcessInfo.processInfo.systemUptime)
        }
        .task {
            state.feel.land(cue)
            // The STOP tap must not also skip the result.
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation { acceptsTap = true }
        }
    }

    private var cue: LandingCue {
        if case .streak = session.mode {
            guard result.isHit else { return .fail }
            return ChallengeRecords.isDeadOn(stopped: result.stopped, target: result.target) ? .deadOn : .neutral
        }
        return LandingCue(result.outcome)
    }

    @ViewBuilder
    private var verdict: some View {
        switch session.mode {
        case .streak:
            Text(result.isHit ? LocalizedStringKey("HIT") : LocalizedStringKey("MISS"))
                .font(Theme.display(64))
                .foregroundStyle(result.isHit ? Theme.accent : Theme.late)
        case .daily:
            outcomeLabel
                .font(Theme.display(52))
                .foregroundStyle(tierColor)
        }
    }

    @ViewBuilder
    private var outcomeLabel: some View {
        switch result.outcome {
        case .scored(let tier): Text(tier.label)
        case .misfire: Text("Too eager!")
        case .timeout: Text("Time's up")
        }
    }

    private var tierColor: Color {
        if case .scored(let tier) = result.outcome {
            return Theme.color(for: tier)
        }
        return Theme.late
    }

    @ViewBuilder
    private var deviationLine: some View {
        if case .scored = result.outcome {
            Text("\(TimeFormat.signedDeviation(result.deviation)) s off")
                .font(.title.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(result.deviation < 0 ? Theme.early : Theme.late)
        } else {
            outcomeLabel
                .font(.title.weight(.heavy))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder
    private var details: some View {
        Group {
            switch session.mode {
            case .streak:
                Text("Target: \(TimeFormat.seconds(result.target)) s")
                Text("Streak: \(session.run?.length ?? 0)")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.primaryText)
            case .daily:
                Text("Target: \(TimeFormat.seconds(result.target)) s")
                Text("Attempts left: \(session.dailyAttemptsLeft)")
            }
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(Theme.secondaryText)
    }
}

// MARK: - Summary

private struct ChallengeSummaryView: View {
    @Environment(AppState.self) private var state
    let session: ChallengeSession
    let close: () -> Void
    let playAgain: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                session.mode.title
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                Spacer()
                CloseButton(action: close)
            }
            Spacer()
            content
            if session.isNewBest {
                Label("New personal best!", systemImage: "star.fill")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
            }
            if session.leaderboardSubmission != nil, state.gameCenter.isAuthenticated {
                Button {
                    state.gameCenter.showLeaderboard(session.leaderboardSubmission?.leaderboardID)
                } label: {
                    Label("Leaderboard", systemImage: "list.number")
                        .font(.headline)
                }
            }
            Spacer()
            VStack(spacing: 12) {
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.secondary)
                if case .streak = session.mode {
                    Button("Play again", action: playAgain)
                        .buttonStyle(.primary)
                }
                Button("Done", action: close)
                    .buttonStyle(.secondary)
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private var content: some View {
        switch session.mode {
        case .streak(let kind, let difficulty):
            let run = session.run
            VStack(spacing: 12) {
                Text("Streak over")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(Theme.secondaryText)
                Text(verbatim: "\(run?.length ?? 0)")
                    .font(Theme.display(120))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                Text("hits in a row")
                    .font(.title2.weight(.heavy))
                if let run, run.length > 0 {
                    Text("Average: ±\(TimeFormat.seconds(run.averageDeviation)) s")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                Text("Personal best: \(session.records.stats(kind, difficulty).best)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        case .daily(let challenge):
            VStack(spacing: 12) {
                Text("Daily Challenge done")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(Theme.secondaryText)
                if let best = session.records.dailyResult(for: challenge.day).best {
                    Text("Best today")
                        .font(.title2.weight(.heavy))
                    Text("\(TimeFormat.signedDeviation(best)) s")
                        .font(Theme.display(72))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                } else {
                    Text("No timed attempt today.")
                        .font(.title2.weight(.heavy))
                }
                Text("New challenge tomorrow.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var shareText: String {
        let line: String
        switch session.mode {
        case .streak:
            line = String(localized: "I hit \(session.run?.length ?? 0) in a row in Blind Ten, the game where the timer disappears. Can you beat it?")
        case .daily(let challenge):
            if let best = session.records.dailyResult(for: challenge.day).best {
                line = String(localized: "Today's Blind Ten Daily Challenge: I was \(TimeFormat.signedDeviation(best)) s off. Can you beat it?")
            } else {
                line = String(localized: "Try today's Blind Ten Daily Challenge: stop the hidden timer at exactly the target.")
            }
        }
        return "\(line) \(WebLinks.home.absoluteString)"
    }
}

private struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 48, height: 48)
                .background(Theme.surface, in: Circle())
        }
        .accessibilityLabel(Text("Close"))
    }
}
