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
    @State private var hasAppeared = ScreenshotMode.isActive

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
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.bounce, value: hasAppeared)
                        .padding(.top, 12)
                        .entrance(0, isVisible: hasAppeared)
                    Text("The timer starts by itself")
                        .font(Theme.display(34))
                        .fixedSize(horizontal: false, vertical: true)
                        .entrance(1, isVisible: hasAppeared)
                    Text("We can't control whether you're cheating with a second stopwatch. That's why there is no START button here.")
                        .fixedSize(horizontal: false, vertical: true)
                        .entrance(2, isVisible: hasAppeared)
                    Text("Instead, the timer starts automatically at a random moment, a few seconds after you tap \"I'm ready\". Watch for the yellow flash and the buzz, then stop at exactly the target.")
                        .fixedSize(horizontal: false, vertical: true)
                        .entrance(3, isVisible: hasAppeared)
                    Text("Leaving the app while the timer runs counts as a miss.")
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .entrance(4, isVisible: hasAppeared)
                    targetLine
                        .entrance(5, isVisible: hasAppeared)
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("I'm ready") {
                session.getReady(now: ProcessInfo.processInfo.systemUptime)
            }
            .buttonStyle(.primary)
            .padding(.top, 12)
            .entrance(6, isVisible: hasAppeared)
        }
        .padding(24)
        .onAppear { hasAppeared = true }
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
        case .duel(let plan):
            VStack(alignment: .leading, spacing: 6) {
                Text("Round \((session.duelRound ?? 0) + 1) of \(DuelState.rounds)")
                    .foregroundStyle(Theme.secondaryText)
                Text("Stop at \(TimeFormat.seconds(session.target))")
                    .font(Theme.display(44))
                    .monospacedDigit()
                Text("Against \(plan.displayOpponent)")
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
    /// The number rolls up to the stopped time, then the verdict lands.
    @State private var shownTime: TimeInterval = 0
    @State private var isLanded = ScreenshotMode.isActive
    @State private var confettiStart: TimeInterval?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Spacer()
                verdict
                    .scaleEffect(isLanded ? 1 : 0.6)
                    .opacity(isLanded ? 1 : 0)
                Text(verbatim: TimeFormat.seconds(isLanded ? result.stopped : shownTime))
                    .font(Theme.display(96))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: isLanded ? result.stopped : shownTime))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Group {
                    deviationLine
                    details
                }
                .opacity(isLanded ? 1 : 0)
                .offset(y: isLanded ? 0 : 12)
                Spacer()
                Text("Tap to continue")
                    .font(.title3.weight(.bold))
                    .opacity(acceptsTap ? 1 : 0)
            }
            .padding(24)
            if let confettiStart {
                ConfettiView(startTime: confettiStart)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard acceptsTap else { return }
            session.continueAfterResult(now: ProcessInfo.processInfo.systemUptime)
        }
        .task {
            if !reduceMotion, !isLanded {
                withAnimation(.easeOut(duration: 0.45)) { shownTime = result.stopped }
                try? await Task.sleep(for: .milliseconds(450))
            }
            withAnimation(Motion.snappy) { isLanded = true }
            state.feel.land(cue)
            if cue == .deadOn {
                confettiStart = ProcessInfo.processInfo.systemUptime
            }
            // The STOP tap must not also skip the result.
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeIn(duration: 0.2)) { acceptsTap = true }
        }
    }

    /// The opponent's result of this round, once both have played it.
    @ViewBuilder
    private func duelRoundLine(_ plan: DuelPlan) -> some View {
        if let duel = session.duel, let round = session.duelRound,
           let theirs = duel.stopped(player: plan.opponent, round: round),
           duel.isVisible(player: plan.opponent, round: round, to: plan.me) {
            VStack(spacing: 6) {
                Text("\(plan.displayOpponent): \(TimeFormat.seconds(theirs)) s")
                switch duel.result(round: round) {
                case .won(let winner) where winner == plan.me:
                    Text("You win the round!")
                        .foregroundStyle(Theme.accent)
                case .won:
                    Text("\(plan.displayOpponent) wins the round.")
                        .foregroundStyle(Theme.late)
                case .tie, nil:
                    Text("Round tied.")
                }
            }
        } else {
            Text("\(plan.displayOpponent) plays this round next.")
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
        case .daily, .duel:
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
            case .duel(let plan):
                Text("Round \((session.duelRound ?? 0) + 1) of \(DuelState.rounds) · target \(TimeFormat.seconds(result.target)) s")
                duelRoundLine(plan)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
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
    @State private var hasAppeared = ScreenshotMode.isActive
    @State private var confettiStart: TimeInterval?

    /// A new personal best or a won duel gets confetti.
    private var celebrates: Bool {
        if session.isNewBest { return true }
        if case .duel(let plan) = session.mode, case .won(let winner) = session.duel?.outcome {
            return winner == plan.me
        }
        return false
    }

    var body: some View {
        ZStack {
            summary
            if let confettiStart {
                ConfettiView(startTime: confettiStart)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .task {
            withAnimation(Motion.spring) { hasAppeared = true }
            if celebrates {
                try? await Task.sleep(for: .milliseconds(250))
                confettiStart = ProcessInfo.processInfo.systemUptime
                state.feel.land(.deadOn)
            }
        }
    }

    /// Phrases for the end of a duel turn: the duel's result, or how the
    /// last round went.
    private var duelChatContext: QuickChat.Context {
        guard case .duel(let plan) = session.mode, let duel = session.duel else { return .waiting }
        switch duel.outcome {
        case .won(let winner)?: return winner == plan.me ? .won : .lost
        case .draw?: return .draw
        case nil:
            guard let round = session.duelRound else { return .waiting }
            switch duel.result(round: round) {
            case .won(let winner)?: return winner == plan.me ? .goodResult : .badResult
            case .tie?, nil: return .waiting
            }
        }
    }

    private var summary: some View {
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
                .scaleEffect(hasAppeared ? 1 : 0.85)
                .opacity(hasAppeared ? 1 : 0)
            if session.isNewBest {
                Label("New personal best!", systemImage: "star.fill")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .symbolEffect(.bounce, value: hasAppeared)
                    .scaleEffect(hasAppeared ? 1 : 0.4)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(Motion.snappy.delay(0.2), value: hasAppeared)
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
                if case .streak = session.mode {
                    Button("Play again", action: playAgain)
                        .buttonStyle(.primary)
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.secondary)
                    Button("Done", action: close)
                        .font(.headline)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if case .duel = session.mode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.duel?.outcome == nil ? LocalizedStringKey("Send a message with your turn") : LocalizedStringKey("Send a message"))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Theme.secondaryText)
                            .textCase(.uppercase)
                        QuickChatBar(context: duelChatContext, selected: session.duelMessage) { id in
                            withAnimation(Motion.snappy) {
                                session.duelMessage = session.duelMessage == id ? nil : id
                            }
                        }
                        .padding(.horizontal, -20)
                    }
                    Button {
                        session.sendDuelTurn()
                        close()
                    } label: {
                        Text(session.duel?.outcome == nil ? LocalizedStringKey("Send turn") : LocalizedStringKey("Done"))
                    }
                    .buttonStyle(.primary)
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.secondary)
                } else {
                    Button("Done", action: close)
                        .buttonStyle(.primary)
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.secondary)
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 24)
            .animation(Motion.spring.delay(0.15), value: hasAppeared)
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
        case .duel(let plan):
            DuelSummary(plan: plan, duel: session.duel)
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
        case .duel(let plan):
            if let duel = session.duel, case .won(let winner) = duel.outcome, winner == plan.me {
                line = String(localized: "I just won a Blind Ten duel \(duel.wins[plan.me])–\(duel.wins[plan.opponent]). Who's next?")
            } else {
                line = String(localized: "Duel me in Blind Ten: tap START, the timer vanishes, stop at the target. Closest wins.")
            }
        }
        return "\(line) \(WebLinks.home.absoluteString)"
    }
}

/// The end of a duel turn: the final score, or that the opponent plays next.
private struct DuelSummary: View {
    let plan: DuelPlan
    let duel: DuelState?

    var body: some View {
        VStack(spacing: 12) {
            if let duel, let outcome = duel.outcome {
                switch outcome {
                case .won(let winner) where winner == plan.me:
                    Text("You won the duel!")
                        .foregroundStyle(Theme.accent)
                case .won:
                    Text("\(plan.displayOpponent) won the duel.")
                case .draw:
                    Text("It's a draw!")
                }
                Text(verbatim: "\(duel.wins[plan.me]) – \(duel.wins[plan.opponent])")
                    .font(Theme.display(96))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
            } else {
                Text("Turn sent")
                    .foregroundStyle(Theme.accent)
                Text("\(plan.displayOpponent) plays next. You'll get a notification when it's your turn again.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .font(Theme.display(40))
        .multilineTextAlignment(.center)
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
