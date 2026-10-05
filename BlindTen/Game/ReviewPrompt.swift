import Foundation

/// SPEC.md: ask for a rating only after a fun game, i.e. after a DEAD ON
/// or a close final. Never more than once per app version, and not before
/// the group has finished a couple of games.
enum ReviewPrompt {
    static let minimumFinishedGames = 2
    /// A final is close when first and second place are this many points apart or fewer.
    static let closeFinalPoints = 2

    static func isCloseFinal(_ standings: [Standing]) -> Bool {
        guard standings.count >= 2 else { return false }
        return abs(standings[0].points - standings[1].points) <= closeFinalPoints
    }

    static func hadDeadOn(_ results: [TurnResult]) -> Bool {
        results.contains { $0.outcome == .scored(.deadOn) }
    }

    static func shouldAsk(
        hadDeadOn: Bool,
        isCloseFinal: Bool,
        finishedGames: Int,
        lastPromptedVersion: String?,
        currentVersion: String
    ) -> Bool {
        (hadDeadOn || isCloseFinal)
            && finishedGames >= minimumFinishedGames
            && lastPromptedVersion != currentVersion
    }
}

/// Persistent counters for the review prompt.
enum ReviewPromptStorage {
    static let finishedGamesKey = "finishedGameCount"
    static let lastPromptedVersionKey = "reviewPromptVersion"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
