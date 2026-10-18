import Foundation
import Observation

/// What is being played: an endless streak, today's Daily Challenge or the
/// local player's rounds of an online duel.
enum ChallengeMode: Equatable, Sendable {
    case streak(ChallengeKind, ChallengeDifficulty)
    case daily(DailyChallenge)
    case duel(DuelPlan)
}

/// The local player's side of an online duel turn.
struct DuelPlan: Equatable, Sendable {
    let matchID: String
    /// The local player's index in the duel.
    let me: Int
    let opponentName: String?
    let state: DuelState

    var opponent: Int { 1 - me }
}

/// One finished challenge turn.
struct ChallengeTurnResult: Equatable, Sendable {
    let target: TimeInterval
    let stopped: TimeInterval
    /// Streak: within the tolerance. Daily and duel: scored (not a misfire or timeout).
    let isHit: Bool

    var outcome: TurnOutcome { Scoring.outcome(elapsed: stopped, target: target) }
    var deviation: TimeInterval { stopped - target }
}

/// Drives one challenge run, from the anti-cheat explanation through the
/// random start to the summary. Times are system uptime; the STOP time comes
/// from `UITouch.timestamp`. No UI here.
@MainActor
@Observable
final class ChallengeSession {
    enum Phase: Equatable {
        /// Explains the random start; waits for "I'm ready".
        case intro
        /// Silent wait; the timer starts by itself at `goAt`.
        case getReady(goAt: TimeInterval)
        /// The blind phase.
        case running(startedAt: TimeInterval)
        /// The turn's result; waits for a tap.
        case result(ChallengeTurnResult)
        case finished
    }

    let mode: ChallengeMode
    private(set) var phase: Phase = .intro
    private(set) var run: StreakRun?
    /// Daily attempts played in this session.
    private(set) var dailyTurns: [ChallengeTurnResult] = []
    /// Duel: the live state and the round being played.
    private(set) var duel: DuelState?
    private(set) var duelRound: Int?
    /// Duel rounds played in this session.
    private(set) var duelTurns: [ChallengeTurnResult] = []
    /// Duel: the phrase picked on the summary, sent along with the turn.
    var duelMessage: String?
    /// Duel: the turn went to the opponent (or the duel ended).
    private(set) var isDuelTurnSent = false
    /// Taps during "Get ready", each of which restarted the wait.
    private(set) var falseStarts = 0
    /// Streak: the finished run beat the personal best. Daily: this session
    /// improved the day's best.
    private(set) var isNewBest = false
    private(set) var records: ChallengeRecords
    /// Set once the result went to Game Center.
    @ObservationIgnored var hasReported = false

    @ObservationIgnored private let delay: () -> TimeInterval
    @ObservationIgnored private let persist: (ChallengeRecords) -> Void
    @ObservationIgnored private let onDuelUpdate: (DuelState, _ isTurnComplete: Bool) -> Void

    init(
        mode: ChallengeMode,
        records: ChallengeRecords,
        seed: UInt64? = nil,
        delay: @escaping () -> TimeInterval = { RandomStart.delay() },
        persist: @escaping (ChallengeRecords) -> Void = { _ in },
        onDuelUpdate: @escaping (DuelState, _ isTurnComplete: Bool) -> Void = { _, _ in }
    ) {
        self.mode = mode
        self.records = records
        self.delay = delay
        self.persist = persist
        self.onDuelUpdate = onDuelUpdate
        switch mode {
        case .streak(let kind, let difficulty):
            run = StreakRun(kind: kind, difficulty: difficulty, seed: seed)
        case .daily:
            break
        case .duel(let plan):
            duel = plan.state
            duelRound = plan.state.nextRound(for: plan.me)
        }
    }

    var target: TimeInterval {
        switch mode {
        case .streak: run?.target ?? GameEngine.classicTarget
        case .daily(let challenge): challenge.target
        case .duel: duel?.target(round: duelRound ?? 0) ?? GameEngine.classicTarget
        }
    }

    var effect: BlindEffect {
        switch mode {
        case .streak, .duel: .dark
        case .daily(let challenge): challenge.effect
        }
    }

    /// Auto-stop at target × 3.
    var timeoutDeadline: TimeInterval? {
        guard case .running(let startedAt) = phase else { return nil }
        return startedAt + Scoring.timeoutDuration(for: target)
    }

    var dailyAttemptsLeft: Int {
        guard case .daily(let challenge) = mode else { return 0 }
        return records.attemptsLeft(for: challenge.day)
    }

    /// The run cannot go on after the current result.
    var isOverAfterResult: Bool {
        switch mode {
        case .streak: run?.isOver ?? true
        case .daily: dailyAttemptsLeft == 0
        case .duel(let plan): duel?.nextRound(for: plan.me) == nil
        }
    }

    // MARK: - Flow

    /// "I'm ready" or "Next": arms the random start.
    func getReady(now: TimeInterval) {
        switch phase {
        case .intro:
            break
        case .result:
            guard !isOverAfterResult else { return }
        case .getReady, .running, .finished:
            return
        }
        switch mode {
        case .streak:
            break
        case .daily:
            guard dailyAttemptsLeft > 0 else { return }
        case .duel(let plan):
            guard let round = duel?.nextRound(for: plan.me) else { return }
            duelRound = round
        }
        phase = .getReady(goAt: now + delay())
    }

    /// A tap before GO: no head start allowed, the wait begins again.
    func falseStart(now: TimeInterval) {
        guard case .getReady = phase else { return }
        falseStarts += 1
        phase = .getReady(goAt: now + delay())
    }

    /// The random wait is over: the timer starts now.
    func go(at uptime: TimeInterval) {
        guard case .getReady(let goAt) = phase, uptime >= goAt else { return }
        switch mode {
        case .streak:
            break
        case .daily(let challenge):
            guard records.beginDailyAttempt(day: challenge.day) else { return }
            persist(records)
        case .duel(let plan):
            guard var state = duel, let round = duelRound,
                  (try? state.begin(round: round, player: plan.me)) != nil
            else { return }
            duel = state
            onDuelUpdate(state, false)
        }
        phase = .running(startedAt: uptime)
    }

    /// STOP. Returns the result, or nil if no turn was running.
    @discardableResult
    func stop(at timestamp: TimeInterval) -> ChallengeTurnResult? {
        guard case .running(let startedAt) = phase else { return nil }
        return finishTurn(stopped: max(0, timestamp - startedAt))
    }

    /// Ends an overdue turn as a timeout.
    func autoStopIfOverdue(now: TimeInterval) {
        guard let deadline = timeoutDeadline, now >= deadline, case .running(let startedAt) = phase else { return }
        finishTurn(stopped: now - startedAt)
    }

    /// The app left the foreground. A running turn counts as a miss (no
    /// peeking at another app); a pending start just goes back to the intro.
    func appDidLeaveForeground() {
        switch phase {
        case .getReady:
            phase = .intro
        case .running:
            finishTurn(stopped: Scoring.timeoutDuration(for: target))
        case .intro, .result, .finished:
            break
        }
    }

    /// Tap on the result screen: next turn or the summary.
    func continueAfterResult(now: TimeInterval) {
        guard case .result = phase else { return }
        if isOverAfterResult {
            finish()
        } else {
            getReady(now: now)
        }
    }

    /// Leaves early. A turn in progress counts as a miss; turns already
    /// played still count. A duel turn is passed on only once all of the
    /// player's rounds are played; otherwise they can resume it later.
    func quit() {
        switch phase {
        case .finished:
            sendDuelTurn()
            return
        case .running:
            appDidLeaveForeground()
        case .intro, .getReady, .result:
            break
        }
        let shouldFinish = switch mode {
        case .streak: !(run?.turns.isEmpty ?? true)
        case .daily: !dailyTurns.isEmpty
        case .duel: !duelTurns.isEmpty && isOverAfterResult
        }
        if shouldFinish {
            finish()
            sendDuelTurn()
        } else {
            phase = .intro
        }
    }

    /// Duel: passes the turn on (or ends the duel) with the picked phrase.
    /// Runs once, from the summary or when the run is closed.
    func sendDuelTurn() {
        guard case .duel(let plan) = mode, case .finished = phase, !isDuelTurnSent, var state = duel else { return }
        if let duelMessage {
            state.say(duelMessage, player: plan.me)
        }
        duel = state
        isDuelTurnSent = true
        onDuelUpdate(state, true)
    }

    // MARK: - Summary

    /// Anti-cheat stage 2: the deviations of this session's turns.
    var plausibility: Plausibility.Verdict {
        let deviations: [TimeInterval] = switch mode {
        case .streak: run?.turns.map(\.deviation) ?? []
        case .daily: dailyTurns.map(\.deviation)
        case .duel: duelTurns.map(\.deviation)
        }
        return Plausibility.check(deviations: deviations)
    }

    /// What goes to the leaderboards, if anything. Implausible runs stay
    /// personal bests but are not submitted.
    var leaderboardSubmission: (score: Int, leaderboardIDs: [String])? {
        guard case .finished = phase, plausibility == .plausible else { return nil }
        switch mode {
        case .streak(let kind, let difficulty):
            guard let run, run.length > 0 else { return nil }
            return (
                ChallengeScore.streakLeaderboard(length: run.length),
                [LeaderboardID.streak(kind, difficulty), LeaderboardID.weeklyStreak(kind, difficulty)]
            )
        case .daily(let challenge):
            guard let best = records.dailyResult(for: challenge.day).best else { return nil }
            return (ChallengeScore.daily(deviation: best), [LeaderboardID.daily])
        case .duel:
            return nil
        }
    }

    /// Achievements earned in this session.
    var earnedAchievements: [AchievementID] {
        var earned: [AchievementID] = []
        let turns: [ChallengeTurnResult]
        switch mode {
        case .streak:
            turns = run?.turns.map { ChallengeTurnResult(target: $0.target, stopped: $0.stopped, isHit: $0.isHit) } ?? []
            if case .finished = phase {
                earned += AchievementID.forStreak(length: run?.length ?? 0)
            }
        case .daily:
            turns = dailyTurns
            if !dailyTurns.isEmpty {
                earned.append(.dailyPlayer)
            }
        case .duel:
            turns = duelTurns
        }
        if turns.contains(where: { ChallengeRecords.isDeadOn(stopped: $0.stopped, target: $0.target) }) {
            earned.insert(.firstDeadOn, at: 0)
        }
        return earned
    }

    // MARK: - Private

    @discardableResult
    private func finishTurn(stopped: TimeInterval) -> ChallengeTurnResult {
        let result: ChallengeTurnResult
        switch mode {
        case .streak:
            let turnTarget = target
            let hit = run?.record(stopped: stopped) ?? false
            result = ChallengeTurnResult(target: turnTarget, stopped: stopped, isHit: hit)
        case .daily(let challenge):
            result = ChallengeTurnResult(
                target: challenge.target,
                stopped: stopped,
                isHit: Scoring.outcome(elapsed: stopped, target: challenge.target).isScored
            )
            dailyTurns.append(result)
            if records.finishDailyAttempt(day: challenge.day, stopped: stopped, target: challenge.target) {
                isNewBest = true
            }
            persist(records)
        case .duel(let plan):
            let turnTarget = target
            result = ChallengeTurnResult(
                target: turnTarget,
                stopped: stopped,
                isHit: Scoring.outcome(elapsed: stopped, target: turnTarget).isScored
            )
            duelTurns.append(result)
            if var state = duel, let round = duelRound,
               (try? state.record(stopped: stopped, round: round, player: plan.me)) != nil {
                duel = state
                onDuelUpdate(state, false)
            }
        }
        phase = .result(result)
        return result
    }

    private func finish() {
        switch mode {
        case .streak:
            if let run {
                isNewBest = records.record(run)
                persist(records)
            }
        case .daily:
            break
        case .duel:
            // Sent from the summary, so a phrase can go along.
            break
        }
        phase = .finished
    }
}

private extension TurnOutcome {
    var isScored: Bool {
        if case .scored = self { true } else { false }
    }
}
