import Foundation
import Testing
@testable import BlindTen

struct ChallengeRecordsTests {
    private func run(_ stops: [TimeInterval], difficulty: ChallengeDifficulty = .close) -> StreakRun {
        var run = StreakRun(kind: .classic, difficulty: difficulty, seed: 1)
        for stop in stops {
            run.record(stopped: stop)
        }
        return run
    }

    @Test func firstRunWithHitsIsANewBest() {
        var records = ChallengeRecords()
        let isNewBest = records.record(run([10.1, 9.8, 11.0]))
        let stats = records.stats(.classic, .close)
        #expect(isNewBest)
        #expect(stats.best == 2)
        #expect(stats.runs == 1)
        #expect(stats.turns == 3)
        #expect(stats.hits == 2)
        #expect(abs((stats.bestAverage ?? 0) - 0.15) < 1e-9)
    }

    @Test func runWithoutHitsIsNeverABest() {
        var records = ChallengeRecords()
        let isNewBest = records.record(run([12.0]))
        #expect(!isNewBest)
        #expect(records.stats(.classic, .close).best == 0)
        #expect(records.stats(.classic, .close).runs == 1)
    }

    @Test func sameLengthNeedsALowerAverageToBeatTheBest() {
        var records = ChallengeRecords()
        records.record(run([10.3, 11.0]))
        let worse = records.record(run([10.4, 11.0]))
        let better = records.record(run([10.1, 11.0]))
        #expect(!worse)
        #expect(better)
        #expect(abs((records.stats(.classic, .close).bestAverage ?? 0) - 0.1) < 1e-9)
    }

    @Test func difficultiesAreKeptApart() {
        var records = ChallengeRecords()
        records.record(run([10.1, 10.1, 11.0], difficulty: .pro))
        #expect(records.stats(.classic, .pro).best == 2)
        #expect(records.stats(.classic, .close).best == 0)
    }

    @Test func statisticsAddUpAcrossRuns() {
        var records = ChallengeRecords()
        records.record(run([10.1, 11.0]))
        records.record(run([10.0, 9.7, 12.0], difficulty: .pro))
        #expect(records.totalRuns == 2)
        // The pro run ends at 9.7, so 12.0 is never recorded.
        #expect(records.totalTurns == 4)
        #expect(records.totalHits == 2)
        #expect(abs((records.hitRate ?? 0) - 0.5) < 1e-9)
        #expect(abs((records.averageHitDeviation ?? 0) - 0.05) < 1e-9)
        #expect(records.deadOns == 1)
    }

    @Test func dailyAttemptsAreLimited() {
        var records = ChallengeRecords()
        let day = "2026-10-16"
        for _ in 0..<DailyChallenge.attempts {
            let began = records.beginDailyAttempt(day: day)
            #expect(began)
        }
        let extra = records.beginDailyAttempt(day: day)
        #expect(!extra)
        #expect(records.attemptsLeft(for: day) == 0)
        #expect(records.attemptsLeft(for: "2026-10-17") == DailyChallenge.attempts)
    }

    @Test func dailyKeepsTheClosestScoredAttempt() {
        var records = ChallengeRecords()
        let day = "2026-10-16"
        let first = records.finishDailyAttempt(day: day, stopped: 7.5, target: 7)
        let closer = records.finishDailyAttempt(day: day, stopped: 6.8, target: 7)
        let worse = records.finishDailyAttempt(day: day, stopped: 7.3, target: 7)
        let misfire = records.finishDailyAttempt(day: day, stopped: 0.3, target: 7)
        #expect(first)
        #expect(closer)
        #expect(!worse)
        #expect(!misfire)
        #expect(abs((records.dailyResult(for: day).best ?? 0) + 0.2) < 1e-9)
    }

    @Test func oldDailyResultsArePruned() {
        var records = ChallengeRecords()
        let start = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z") ?? .distantPast
        for offset in 0..<(ChallengeRecords.keptDays + 5) {
            let day = DailyChallenge.dayString(for: start.addingTimeInterval(Double(offset) * 86_400))
            records.beginDailyAttempt(day: day)
        }
        #expect(records.dailyDaysPlayed == ChallengeRecords.keptDays)
        #expect(records.dailyResult(for: "2026-01-01").attemptsUsed == 0)
    }

    @Test func duelsAreCountedOnce() {
        var records = ChallengeRecords()
        let first = records.recordDuel(id: "m1", result: .win)
        let again = records.recordDuel(id: "m1", result: .win)
        records.recordDuel(id: "m2", result: .loss)
        records.recordDuel(id: "m3", result: .draw)
        #expect(first)
        #expect(!again)
        #expect(records.duelWins == 1)
        #expect(records.duelLosses == 1)
        #expect(records.duelDraws == 1)
    }

    @Test func recordsSavedBeforeDuelsStillLoad() throws {
        let old = Data(#"{"streaks":{},"daily":{},"deadOns":3}"#.utf8)
        let records = try JSONDecoder().decode(ChallengeRecords.self, from: old)
        #expect(records.deadOns == 3)
        #expect(records.duelWins == 0)
    }

    @Test func roundTripsThroughUserDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "ChallengeRecordsTests"))
        defaults.removePersistentDomain(forName: "ChallengeRecordsTests")
        var records = ChallengeRecords()
        records.record(run([10.1, 11.0]))
        records.beginDailyAttempt(day: "2026-10-16")
        ChallengeRecordsStorage.save(records, to: defaults)
        let loaded = ChallengeRecordsStorage.load(from: defaults)
        #expect(loaded == records)
    }
}

@MainActor
struct ChallengeSessionTests {
    private let daily = DailyChallenge(date: ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z") ?? .distantPast)

    private func streakSession(_ difficulty: ChallengeDifficulty = .close) -> ChallengeSession {
        ChallengeSession(mode: .streak(.classic, difficulty), records: ChallengeRecords(), seed: 1, delay: { 2 })
    }

    @Test func randomStartFlow() {
        let session = streakSession()
        #expect(session.phase == .intro)
        session.getReady(now: 100)
        #expect(session.phase == .getReady(goAt: 102))
        // GO cannot come early.
        session.go(at: 101)
        #expect(session.phase == .getReady(goAt: 102))
        session.go(at: 102)
        #expect(session.phase == .running(startedAt: 102))
        #expect(session.timeoutDeadline == 132)
    }

    @Test func tapDuringGetReadyRestartsTheWait() {
        let session = streakSession()
        session.getReady(now: 100)
        session.falseStart(now: 101)
        #expect(session.falseStarts == 1)
        #expect(session.phase == .getReady(goAt: 103))
    }

    @Test func streakContinuesUntilTheFirstMiss() {
        let session = streakSession()
        session.getReady(now: 0)
        session.go(at: 2)
        let hit = session.stop(at: 12.1)
        #expect(hit?.isHit == true)
        #expect(!session.isOverAfterResult)
        session.continueAfterResult(now: 20)
        #expect(session.phase == .getReady(goAt: 22))
        session.go(at: 22)
        let miss = session.stop(at: 33)
        #expect(miss?.isHit == false)
        #expect(session.isOverAfterResult)
        session.continueAfterResult(now: 40)
        #expect(session.phase == .finished)
        #expect(session.isNewBest)
        #expect(session.records.stats(.classic, .close).best == 1)
        #expect(session.leaderboardSubmission?.leaderboardID == LeaderboardID.streak(.classic, .close))
        #expect(session.leaderboardSubmission?.score == 1)
    }

    @Test func leavingTheAppMidTurnIsAMiss() {
        let session = streakSession()
        session.getReady(now: 0)
        session.go(at: 2)
        session.appDidLeaveForeground()
        guard case .result(let result) = session.phase else {
            Issue.record("expected a result")
            return
        }
        #expect(!result.isHit)
        #expect(result.outcome == .timeout)
    }

    @Test func leavingTheAppBeforeGoReturnsToTheIntro() {
        let session = streakSession()
        session.getReady(now: 0)
        session.appDidLeaveForeground()
        #expect(session.phase == .intro)
    }

    @Test func overdueTurnTimesOut() {
        let session = streakSession()
        session.getReady(now: 0)
        session.go(at: 2)
        session.autoStopIfOverdue(now: 20)
        #expect(session.phase == .running(startedAt: 2))
        session.autoStopIfOverdue(now: 32)
        #expect(session.isOverAfterResult)
    }

    @Test func dailyUsesAttemptsAtGoAndPersists() {
        var saved: [ChallengeRecords] = []
        let session = ChallengeSession(mode: .daily(daily), records: ChallengeRecords(), delay: { 2 }) { saved.append($0) }
        #expect(session.effect == daily.effect)
        for attempt in 0..<DailyChallenge.attempts {
            let now = Double(attempt) * 100
            if attempt == 0 {
                session.getReady(now: now)
            } else {
                session.continueAfterResult(now: now)
            }
            session.go(at: now + 2)
            session.stop(at: now + 2 + daily.target + 0.1)
        }
        #expect(session.dailyAttemptsLeft == 0)
        #expect(session.isOverAfterResult)
        #expect(session.isNewBest)
        #expect(saved.last?.dailyResult(for: daily.day).attemptsUsed == DailyChallenge.attempts)
        session.continueAfterResult(now: 1_000)
        #expect(session.phase == .finished)
        #expect(session.leaderboardSubmission?.leaderboardID == LeaderboardID.daily)
        #expect(session.leaderboardSubmission?.score == 10)
        let earned = session.earnedAchievements
        #expect(earned.contains(.dailyPlayer))
    }

    @Test func dailyWithoutAttemptsLeftCannotStart() {
        var records = ChallengeRecords()
        for _ in 0..<DailyChallenge.attempts {
            records.beginDailyAttempt(day: daily.day)
        }
        let session = ChallengeSession(mode: .daily(daily), records: records, delay: { 2 })
        session.getReady(now: 0)
        #expect(session.phase == .intro)
    }

    @Test func quittingAfterAHitStillCountsTheStreak() {
        let session = streakSession()
        session.getReady(now: 0)
        session.go(at: 2)
        session.stop(at: 12.0)
        session.quit()
        #expect(session.phase == .finished)
        #expect(session.records.stats(.classic, .close).best == 1)
        let earned = session.earnedAchievements
        #expect(earned.contains(.firstDeadOn))
    }

    @Test func duelTurnPlaysEveryOpenRoundThenPassesTheTurn() throws {
        var state = DuelState(kind: .classic, seed: 1)
        try state.begin(round: 0, player: 0)
        try state.record(stopped: 10.2, round: 0, player: 0)
        var updates: [(DuelState, Bool)] = []
        let plan = DuelPlan(matchID: "m", me: 1, opponentName: "A", state: state)
        let session = ChallengeSession(mode: .duel(plan), records: ChallengeRecords(), delay: { 2 }, onDuelUpdate: { updates.append(($0, $1)) })
        #expect(session.duelRound == 0)
        session.getReady(now: 0)
        session.go(at: 2)
        // The placeholder is saved before the stop.
        #expect(updates.count == 1)
        session.stop(at: 12.1)
        #expect(!session.isOverAfterResult)
        session.continueAfterResult(now: 20)
        #expect(session.duelRound == 1)
        session.go(at: 22)
        session.stop(at: 32.3)
        #expect(session.isOverAfterResult)
        session.continueAfterResult(now: 40)
        #expect(session.phase == .finished)
        let last = try #require(updates.last)
        #expect(last.1)
        #expect(last.0.result(round: 0) == .won(by: 1))
        #expect(last.0.nextRound(for: 0) == 1)
    }

    @Test func quittingADuelMidTurnKeepsTheTurn() throws {
        var state = DuelState(kind: .classic, seed: 1)
        try state.begin(round: 0, player: 0)
        try state.record(stopped: 10.2, round: 0, player: 0)
        var completed = false
        let plan = DuelPlan(matchID: "m", me: 1, opponentName: nil, state: state)
        let session = ChallengeSession(mode: .duel(plan), records: ChallengeRecords(), delay: { 2 }, onDuelUpdate: { _, done in
            if done { completed = true }
        })
        session.getReady(now: 0)
        session.go(at: 2)
        session.stop(at: 12.1)
        session.quit()
        #expect(!completed)
        #expect(session.phase == .intro)
        #expect(session.duel?.nextRound(for: 1) == 1)
    }

    @Test func streakAchievements() {
        #expect(AchievementID.forStreak(length: 4).isEmpty)
        #expect(AchievementID.forStreak(length: 10) == [.streak5, .streak10])
        #expect(LeaderboardID.all.count == 5)
    }
}
