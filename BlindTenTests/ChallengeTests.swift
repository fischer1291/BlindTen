import Foundation
import Testing
@testable import BlindTen

struct StreakRulesTests {
    @Test func classicTolerances() {
        #expect(StreakRules.tolerance(kind: .classic, difficulty: .pro, target: 10) == 0.25)
        #expect(StreakRules.tolerance(kind: .classic, difficulty: .close, target: 10) == 0.50)
    }

    @Test func randomTargetToleranceScalesWithTheTarget() {
        #expect(abs(StreakRules.tolerance(kind: .randomTarget, difficulty: .pro, target: 4) - 0.10) < 1e-9)
        #expect(abs(StreakRules.tolerance(kind: .randomTarget, difficulty: .pro, target: 20) - 0.50) < 1e-9)
        #expect(abs(StreakRules.tolerance(kind: .randomTarget, difficulty: .close, target: 20) - 1.00) < 1e-9)
    }

    @Test func classicProBoundaryIsInclusiveOnTheDisplayedValue() {
        #expect(StreakRules.isHit(stopped: 10.25, target: 10, kind: .classic, difficulty: .pro))
        #expect(StreakRules.isHit(stopped: 9.75, target: 10, kind: .classic, difficulty: .pro))
        // 10.2549 shows as +0.25: still a hit.
        #expect(StreakRules.isHit(stopped: 10.2549, target: 10, kind: .classic, difficulty: .pro))
        #expect(!StreakRules.isHit(stopped: 10.26, target: 10, kind: .classic, difficulty: .pro))
        #expect(StreakRules.isHit(stopped: 10.26, target: 10, kind: .classic, difficulty: .close))
        #expect(!StreakRules.isHit(stopped: 10.51, target: 10, kind: .classic, difficulty: .close))
    }

    @Test func randomTargetUsesTheRelativeTolerance() {
        #expect(StreakRules.isHit(stopped: 4.10, target: 4, kind: .randomTarget, difficulty: .pro))
        #expect(!StreakRules.isHit(stopped: 4.11, target: 4, kind: .randomTarget, difficulty: .pro))
        #expect(StreakRules.isHit(stopped: 19.50, target: 20, kind: .randomTarget, difficulty: .pro))
        #expect(!StreakRules.isHit(stopped: 19.49, target: 20, kind: .randomTarget, difficulty: .pro))
    }

    @Test func misfiresAndTimeoutsAreMisses() {
        // A 4 s target with Close allows 0.20 s, but a stop under 1 s is a misfire either way.
        #expect(!StreakRules.isHit(stopped: 0.5, target: 4, kind: .randomTarget, difficulty: .close))
        #expect(!StreakRules.isHit(stopped: 30, target: 10, kind: .classic, difficulty: .close))
    }
}

struct StreakRunTests {
    @Test func runContinuesOnHitsAndEndsOnTheFirstMiss() {
        var run = StreakRun(kind: .classic, difficulty: .pro, seed: 1)
        let first = run.record(stopped: 10.10)
        let second = run.record(stopped: 9.95)
        let third = run.record(stopped: 10.40)
        let afterEnd = run.record(stopped: 10.00)
        #expect(first)
        #expect(second)
        #expect(!third)
        #expect(!afterEnd)
        #expect(run.isOver)
        #expect(run.length == 2)
        #expect(run.turns.count == 3)
        #expect(abs(run.averageDeviation - 0.075) < 1e-9)
    }

    @Test func classicAlwaysTargetsTenSeconds() {
        var run = StreakRun(kind: .classic, difficulty: .close, seed: 2)
        #expect(run.target == 10)
        run.record(stopped: 10.1)
        #expect(run.target == 10)
    }

    @Test func randomTargetPicksANewTargetAfterEachHit() {
        var run = StreakRun(kind: .randomTarget, difficulty: .close, seed: 3)
        var targets: [TimeInterval] = []
        for _ in 0..<5 {
            targets.append(run.target)
            run.record(stopped: run.target)
        }
        #expect(targets.allSatisfy { RandomTargetMode.targetRange.contains($0) })
        #expect(Set(targets).count > 1)
        #expect(run.length == 5)
        #expect(!run.isOver)
    }

    @Test func sameSeedSameTargets() {
        let a = StreakRun(kind: .randomTarget, difficulty: .pro, seed: 42)
        let b = StreakRun(kind: .randomTarget, difficulty: .pro, seed: 42)
        #expect(a.target == b.target)
    }
}

struct ChallengeScoreTests {
    @Test func longerStreakAlwaysWins() {
        let short = ChallengeScore.streak(length: 5, averageDeviation: 0.0)
        let long = ChallengeScore.streak(length: 6, averageDeviation: 0.5)
        #expect(long > short)
    }

    @Test func sameLengthLowerDeviationWins() {
        let precise = ChallengeScore.streak(length: 5, averageDeviation: 0.05)
        let sloppy = ChallengeScore.streak(length: 5, averageDeviation: 0.20)
        #expect(precise > sloppy)
        #expect(ChallengeScore.streakLength(fromScore: precise) == 5)
    }

    @Test func dailyScoreRewardsSmallDeviation() {
        #expect(ChallengeScore.daily(deviation: 0) == 9_999)
        #expect(ChallengeScore.daily(deviation: -0.27) == 9_972)
        #expect(ChallengeScore.daily(deviation: 0.27) > ChallengeScore.daily(deviation: 1.5))
    }
}

struct RandomStartTests {
    @Test func delayStaysInRange() {
        var generator = SplitMix64(seed: 9)
        for _ in 0..<200 {
            let delay = RandomStart.delay(using: &generator)
            #expect(RandomStart.delayRange.contains(delay))
        }
    }
}

struct DailyChallengeTests {
    private func date(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: text) ?? .distantPast
    }

    @Test func sameUTCDaySameChallenge() {
        let morning = DailyChallenge(date: date("2026-10-16T00:05:00Z"))
        let night = DailyChallenge(date: date("2026-10-16T23:55:00Z"))
        #expect(morning == night)
        #expect(morning.day == "2026-10-16")
        #expect(RandomTargetMode.targetRange.contains(morning.target))
    }

    @Test func nextDayDifferentSeed() {
        #expect(DailyChallenge.seed(for: "2026-10-16") != DailyChallenge.seed(for: "2026-10-17"))
        let today = DailyChallenge(date: date("2026-10-16T12:00:00Z"))
        let tomorrow = DailyChallenge(date: date("2026-10-17T12:00:00Z"))
        #expect(today.day != tomorrow.day)
    }

    @Test func seedIsStable() {
        // FNV-1a must not change between releases, or old days would get new targets.
        #expect(DailyChallenge.seed(for: "") == 0xcbf2_9ce4_8422_2325)
    }
}
