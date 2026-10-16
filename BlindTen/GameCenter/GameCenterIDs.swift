import Foundation

/// Leaderboard IDs, as set up in App Store Connect.
enum LeaderboardID {
    static let prefix = "com.leroyfischer.blindtengame"

    /// One all-time leaderboard per streak kind and difficulty.
    static func streak(_ kind: ChallengeKind, _ difficulty: ChallengeDifficulty) -> String {
        "\(prefix).streak.\(kind.rawValue).\(difficulty.rawValue)"
    }

    /// Recurring leaderboard that resets every day at 00:00 UTC.
    static let daily = "\(prefix).daily"

    static var all: [String] {
        ChallengeKind.allCases.flatMap { kind in
            ChallengeDifficulty.allCases.map { streak(kind, $0) }
        } + [daily]
    }
}

/// Achievement IDs, as set up in App Store Connect.
enum AchievementID: String, CaseIterable, Sendable {
    /// A challenge turn within 0.05 s.
    case firstDeadOn = "deadon"
    case streak5 = "streak5"
    case streak10 = "streak10"
    case streak25 = "streak25"
    /// Finished a Daily Challenge.
    case dailyPlayer = "daily"

    var identifier: String { "\(LeaderboardID.prefix).achievement.\(rawValue)" }

    /// Streak achievements reached by a run of this length.
    static func forStreak(length: Int) -> [AchievementID] {
        [(5, streak5), (10, streak10), (25, streak25)]
            .filter { length >= $0.0 }
            .map(\.1)
    }
}
