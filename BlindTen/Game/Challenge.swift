import Foundation

/// Solo challenges for leaderboards (SPEC.md "Version 2"). Pure rules, no UI.

/// Which streak is played. Each has its own leaderboard per difficulty.
enum ChallengeKind: String, CaseIterable, Codable, Sendable {
    /// Always 10 s.
    case classic
    /// A new target from 4 to 20 s every turn.
    case randomTarget
}

/// How tight a hit has to be.
enum ChallengeDifficulty: String, CaseIterable, Codable, Sendable {
    /// Classic ≤ 0.25 s, Random Target ≤ 2.5 % of the target.
    case pro
    /// Classic ≤ 0.50 s, Random Target ≤ 5 % of the target.
    case close
}

enum StreakRules {
    /// The largest deviation that still counts as a hit, in seconds.
    ///
    /// Random Target is relative to the target because timing error grows
    /// with the length of the interval.
    static func tolerance(kind: ChallengeKind, difficulty: ChallengeDifficulty, target: TimeInterval) -> TimeInterval {
        switch (kind, difficulty) {
        case (.classic, .pro): 0.25
        case (.classic, .close): 0.50
        case (.randomTarget, .pro): target * 0.025
        case (.randomTarget, .close): target * 0.05
        }
    }

    /// A hit is judged on the displayed deviation (two decimals), like the
    /// score tiers, so what the player sees always matches the verdict.
    /// Misfires and timeouts are always misses.
    static func isHit(stopped: TimeInterval, target: TimeInterval, kind: ChallengeKind, difficulty: ChallengeDifficulty) -> Bool {
        guard case .scored = Scoring.outcome(elapsed: stopped, target: target),
              let deviation = Scoring.hundredths(stopped - target),
              let limit = Scoring.hundredths(tolerance(kind: kind, difficulty: difficulty, target: target))
        else { return false }
        return deviation <= limit
    }
}

/// One endless streak run: new turn after each hit, the first miss ends it.
struct StreakRun: Sendable {
    struct Turn: Equatable, Sendable {
        let target: TimeInterval
        let stopped: TimeInterval
        let isHit: Bool

        var deviation: TimeInterval { stopped - target }
    }

    let kind: ChallengeKind
    let difficulty: ChallengeDifficulty
    private(set) var turns: [Turn] = []
    /// Target of the turn being played.
    private(set) var target: TimeInterval
    private var generator: SplitMix64

    init(kind: ChallengeKind, difficulty: ChallengeDifficulty, seed: UInt64? = nil) {
        self.kind = kind
        self.difficulty = difficulty
        generator = seed.map { SplitMix64(seed: $0) } ?? SplitMix64()
        target = GameEngine.classicTarget
        target = nextTarget()
    }

    var isOver: Bool { turns.last?.isHit == false }

    /// Number of hits in a row.
    var length: Int { turns.filter(\.isHit).count }

    /// Average absolute deviation of the hits, the tiebreaker.
    var averageDeviation: TimeInterval {
        let hits = turns.filter(\.isHit)
        guard !hits.isEmpty else { return 0 }
        return hits.reduce(0) { $0 + abs($1.deviation) } / Double(hits.count)
    }

    /// Records a stop. Returns whether it was a hit; ignored once the run is over.
    @discardableResult
    mutating func record(stopped: TimeInterval) -> Bool {
        guard !isOver else { return false }
        let hit = StreakRules.isHit(stopped: stopped, target: target, kind: kind, difficulty: difficulty)
        turns.append(Turn(target: target, stopped: stopped, isHit: hit))
        if hit {
            target = nextTarget()
        }
        return hit
    }

    private mutating func nextTarget() -> TimeInterval {
        switch kind {
        case .classic: GameEngine.classicTarget
        case .randomTarget: RandomTargetMode().makeTarget(using: &generator)
        }
    }
}

/// Leaderboard scores are integers where higher is better.
enum ChallengeScore {
    /// Streak length first; within the same length a lower average
    /// deviation ranks higher (in milliseconds, capped at 999).
    static func streak(length: Int, averageDeviation: TimeInterval) -> Int {
        let millis = min(999, max(0, Int((averageDeviation * 1000).rounded())))
        return length * 1000 + (999 - millis)
    }

    static func streakLength(fromScore score: Int) -> Int {
        score / 1000
    }

    /// Daily Challenge: lower deviation is better, so the score is the
    /// remaining hundredths below a 99.99 s ceiling.
    static func daily(deviation: TimeInterval) -> Int {
        let hundredths = Scoring.hundredths(deviation) ?? 9_999
        return max(0, 9_999 - min(9_999, hundredths))
    }
}

/// The anti-cheat start: the timer starts by itself after a random wait, so
/// a second stopwatch can only be started late, by the player's reaction time.
enum RandomStart {
    static let delayRange: ClosedRange<TimeInterval> = 1.5...4.5

    static func delay<G: RandomNumberGenerator>(using generator: inout G) -> TimeInterval {
        TimeInterval.random(in: delayRange, using: &generator)
    }

    static func delay() -> TimeInterval {
        var generator = SystemRandomNumberGenerator()
        return delay(using: &generator)
    }
}

/// The Daily Challenge: the same target and blind effect for everyone on a
/// given UTC day.
struct DailyChallenge: Equatable, Sendable {
    static let attempts = 3

    /// "2026-10-16", the leaderboard period and the seed.
    let day: String
    let target: TimeInterval
    let effect: BlindEffect

    init(date: Date) {
        day = Self.dayString(for: date)
        var generator = SplitMix64(seed: Self.seed(for: day))
        target = RandomTargetMode().makeTarget(using: &generator)
        let modes: [any GameMode] = [ClassicMode(), DistractionMode(), LiarsClockMode(), HeartbeatMode()]
        let mode = modes[Int(generator.next() % UInt64(modes.count))]
        effect = mode.makeBlindEffect(target: target, using: &generator)
    }

    static func dayString(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// FNV-1a: stable across launches and platforms, unlike `hashValue`.
    static func seed(for day: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in day.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
