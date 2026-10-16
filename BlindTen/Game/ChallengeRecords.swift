import Foundation

/// Personal bests and statistics for the solo challenges. Local only, free
/// for everyone (SPEC.md "Version 2").
struct ChallengeRecords: Codable, Equatable, Sendable {
    struct StreakStats: Codable, Equatable, Sendable {
        /// Longest streak.
        var best = 0
        /// Average deviation of the best streak, the tiebreaker.
        var bestAverage: TimeInterval?
        var runs = 0
        var turns = 0
        var hits = 0
        /// Sum of the absolute deviations of all hits.
        var totalDeviation: TimeInterval = 0

        var bestScore: Int? {
            bestAverage.map { ChallengeScore.streak(length: best, averageDeviation: $0) }
        }
    }

    struct DailyResult: Codable, Equatable, Sendable {
        var attemptsUsed = 0
        /// Signed deviation of the closest attempt; nil if none scored.
        var best: TimeInterval?
    }

    /// How many days of Daily results are kept.
    static let keptDays = 60

    private(set) var streaks: [String: StreakStats] = [:]
    private(set) var daily: [String: DailyResult] = [:]
    /// Challenge turns within 0.05 s.
    private(set) var deadOns = 0

    static func key(_ kind: ChallengeKind, _ difficulty: ChallengeDifficulty) -> String {
        "\(kind.rawValue).\(difficulty.rawValue)"
    }

    func stats(_ kind: ChallengeKind, _ difficulty: ChallengeDifficulty) -> StreakStats {
        streaks[Self.key(kind, difficulty)] ?? StreakStats()
    }

    // MARK: - Streaks

    /// Adds a finished run. Returns true if it is a new personal best.
    @discardableResult
    mutating func record(_ run: StreakRun) -> Bool {
        let key = Self.key(run.kind, run.difficulty)
        var stats = streaks[key] ?? StreakStats()
        let hits = run.turns.filter(\.isHit)
        stats.runs += 1
        stats.turns += run.turns.count
        stats.hits += hits.count
        stats.totalDeviation += hits.reduce(0) { $0 + abs($1.deviation) }
        deadOns += run.turns.filter { Self.isDeadOn(stopped: $0.stopped, target: $0.target) }.count

        let score = ChallengeScore.streak(length: run.length, averageDeviation: run.averageDeviation)
        let isNewBest = run.length > 0 && score > (stats.bestScore ?? 0)
        if isNewBest {
            stats.best = run.length
            stats.bestAverage = run.averageDeviation
        }
        streaks[key] = stats
        return isNewBest
    }

    // MARK: - Daily Challenge

    func dailyResult(for day: String) -> DailyResult {
        daily[day] ?? DailyResult()
    }

    func attemptsLeft(for day: String) -> Int {
        max(0, DailyChallenge.attempts - dailyResult(for: day).attemptsUsed)
    }

    /// Uses up an attempt. Called when the timer starts, so quitting
    /// mid-turn does not give the attempt back. Returns false if none are left.
    @discardableResult
    mutating func beginDailyAttempt(day: String) -> Bool {
        guard attemptsLeft(for: day) > 0 else { return false }
        var result = dailyResult(for: day)
        result.attemptsUsed += 1
        daily[day] = result
        prune(keeping: day)
        return true
    }

    /// Adds a finished attempt. Returns true if it is the day's new best.
    @discardableResult
    mutating func finishDailyAttempt(day: String, stopped: TimeInterval, target: TimeInterval) -> Bool {
        guard case .scored = Scoring.outcome(elapsed: stopped, target: target) else { return false }
        if Self.isDeadOn(stopped: stopped, target: target) {
            deadOns += 1
        }
        var result = dailyResult(for: day)
        let deviation = stopped - target
        let isNewBest = result.best.map { abs(deviation) < abs($0) } ?? true
        if isNewBest {
            result.best = deviation
        }
        daily[day] = result
        return isNewBest
    }

    /// Days with at least one Daily attempt among the kept days.
    var dailyDaysPlayed: Int {
        daily.values.filter { $0.attemptsUsed > 0 }.count
    }

    // MARK: - Statistics

    var totalRuns: Int { streaks.values.reduce(0) { $0 + $1.runs } }
    var totalTurns: Int { streaks.values.reduce(0) { $0 + $1.turns } }
    var totalHits: Int { streaks.values.reduce(0) { $0 + $1.hits } }

    /// Share of streak turns that were hits, 0...1; nil before the first turn.
    var hitRate: Double? {
        totalTurns > 0 ? Double(totalHits) / Double(totalTurns) : nil
    }

    /// Average absolute deviation of all streak hits.
    var averageHitDeviation: TimeInterval? {
        guard totalHits > 0 else { return nil }
        return streaks.values.reduce(0) { $0 + $1.totalDeviation } / Double(totalHits)
    }

    static func isDeadOn(stopped: TimeInterval, target: TimeInterval) -> Bool {
        Scoring.outcome(elapsed: stopped, target: target) == .scored(.deadOn)
    }

    private mutating func prune(keeping today: String) {
        guard daily.count > Self.keptDays else { return }
        // "yyyy-MM-dd" sorts by date.
        let keep = Set(daily.keys.sorted().suffix(Self.keptDays)).union([today])
        daily = daily.filter { keep.contains($0.key) }
    }
}

/// Saves the records as JSON in UserDefaults.
enum ChallengeRecordsStorage {
    static let key = "challengeRecords"

    static func load(from defaults: UserDefaults = .standard) -> ChallengeRecords {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode(ChallengeRecords.self, from: data)
        else { return ChallengeRecords() }
        return records
    }

    static func save(_ records: ChallengeRecords, to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
        }
    }
}
