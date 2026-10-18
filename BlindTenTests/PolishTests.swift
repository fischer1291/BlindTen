import Foundation
import Testing
@testable import BlindTen

struct PlausibilityTests {
    @Test func humanRunsPass() {
        let deviations = [0.12, -0.08, 0.21, -0.004, 0.15, -0.11, 0.09, 0.3, -0.18, 0.07, 0.13, -0.02]
        #expect(Plausibility.check(deviations: deviations) == .plausible)
        #expect(Plausibility.check(deviations: []) == .plausible)
    }

    @Test func tooManyNearPerfectStopsAreWithheld() {
        #expect(Plausibility.check(deviations: [0.001, 0.12, -0.003, 0.2, 0.004, -0.1, 0.3]) == .tooPerfect)
        // Short runs: two in a few turns is already too much.
        #expect(Plausibility.check(deviations: [0.002, -0.001, 0.3]) == .tooPerfect)
    }

    @Test func aScriptedRepeatIsWithheld() {
        #expect(Plausibility.check(deviations: [0.137, 0.137, 0.2, 0.137, -0.1, 0.137]) == .repeated)
    }

    @Test func aSuperhumanAverageIsWithheld() {
        let deviations = [0.011, -0.012, 0.015, -0.018, 0.013, -0.016, 0.019, -0.011, 0.014, -0.017]
        #expect(Plausibility.check(deviations: deviations) == .tooPerfect)
    }

    @MainActor
    @Test func implausibleStreaksAreNotSubmitted() {
        let session = ChallengeSession(mode: .streak(.classic, .close), records: ChallengeRecords(), seed: 1, delay: { 0 })
        var now: TimeInterval = 100
        for stop in [10.001, 10.002, 9.999, 11.0] {
            session.getReady(now: now)
            session.go(at: now)
            session.stop(at: now + stop)
            now += 20
            session.continueAfterResult(now: now)
        }
        #expect(session.phase == .finished)
        #expect(session.plausibility == .tooPerfect)
        #expect(session.leaderboardSubmission == nil)
        // The personal best still counts.
        #expect(session.records.stats(.classic, .close).best == 3)
    }
}

struct SeasonTests {
    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text) ?? .distantPast
    }

    @Test func seasonsRunFromMondayToMondayUTC() {
        let season = Season(date: date("2026-10-18T12:00:00Z"))
        #expect(season.year == 2026)
        #expect(season.week == 42)
        #expect(season.start == date("2026-10-12T00:00:00Z"))
        #expect(season.end == date("2026-10-19T00:00:00Z"))
        #expect(season.daysLeft(from: date("2026-10-18T12:00:00Z")) == 0)
        #expect(season.daysLeft(from: date("2026-10-13T00:00:00Z")) == 6)
    }

    @Test func aNewSeasonStartsOnMonday() {
        let sunday = Season(date: date("2026-10-18T23:59:00Z"))
        let monday = Season(date: date("2026-10-19T00:01:00Z"))
        #expect(monday.week == sunday.week + 1)
    }

    @Test func weeklyLeaderboardsAreRecurring() {
        let id = LeaderboardID.weeklyStreak(.classic, .pro)
        #expect(id == "com.leroyfischer.blindtengame.streak.classic.pro.weekly")
        #expect(LeaderboardID.isRecurring(id))
        #expect(LeaderboardID.isRecurring(LeaderboardID.daily))
        #expect(!LeaderboardID.isRecurring(LeaderboardID.streak(.classic, .pro)))
    }
}
