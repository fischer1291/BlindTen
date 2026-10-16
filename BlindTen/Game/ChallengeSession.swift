import Foundation
import Observation

/// What is being played: an endless streak or today's Daily Challenge.
enum ChallengeMode: Equatable, Sendable {
    case streak(ChallengeKind, ChallengeDifficulty)
    case daily(DailyChallenge)
}

/// One finished challenge turn.
struct ChallengeTurnResult: Equatable, Sendable {
    let target: TimeInterval
    let stopped: TimeInterval
    /// Streak: within the tolerance. Daily: scored (not a misfire or timeout).
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

    init(
        mode: ChallengeMode,
        records: ChallengeRecords,
        seed: UInt64? = nil,
        delay: @escaping () -> TimeInterval = { RandomStart.delay() },
        persist: @escaping (ChallengeRecords) -> Void = { _ in }
    ) {
        self.mode = mode
        self.records = records
        self.delay = delay
        self.persist = persist
        if case .streak(let kind, let difficulty) = mode {
            run = StreakRun(kind: kind, difficulty: difficulty, seed: seed)
        }
    }

    var target: TimeInterval {
        switch mode {
        case .streak: run?.target ?? GameEngine.classicTarget
        case .daily(let challenge): challenge.target
        }
    }

    var effect: BlindEffect {
        switch mode {
        case .streak: .dark
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
        if case .daily = mode, dailyAttemptsLeft == 0 { return }
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
        if case .daily(let challenge) = mode {
            guard records.beginDailyAttempt(day: challenge.day) else { return }
            persist(records)
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
    /// played still count.
    func quit() {
        switch phase {
        case .finished:
            return
        case .running:
            appDidLeaveForeground()
        case .intro, .getReady, .result:
            break
        }
        let hasPlayed = switch mode {
        case .streak: !(run?.turns.isEmpty ?? true)
        case .daily: !dailyTurns.isEmpty
        }
        if hasPlayed {
            finish()
        } else {
            phase = .intro
        }
    }

    // MARK: - Summary

    /// What goes to the leaderboard, if anything.
    var leaderboardSubmission: (score: Int, leaderboardID: String)? {
        guard case .finished = phase else { return nil }
        switch mode {
        case .streak(let kind, let difficulty):
            guard let run, run.length > 0 else { return nil }
            return (ChallengeScore.streak(length: run.length, averageDeviation: run.averageDeviation),
                    LeaderboardID.streak(kind, difficulty))
        case .daily(let challenge):
            guard let best = records.dailyResult(for: challenge.day).best else { return nil }
            return (ChallengeScore.daily(deviation: best), LeaderboardID.daily)
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
        }
        phase = .result(result)
        return result
    }

    private func finish() {
        if case .streak = mode, let run {
            isNewBest = records.record(run)
            persist(records)
        }
        phase = .finished
    }
}

private extension TurnOutcome {
    var isScored: Bool {
        if case .scored = self { true } else { false }
    }
}
