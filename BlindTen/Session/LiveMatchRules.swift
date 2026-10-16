import Foundation

/// Live Match rules that need no network: who hosts, and how many may play.
enum LiveMatchRules {
    static let minPlayers = 2
    static let maxPlayers = 8

    /// Every phone picks the same host without talking: the player with the
    /// smallest Game Center ID. The host runs the game and plays too.
    static func host(among playerIDs: [String]) -> String? {
        playerIDs.min()
    }
}
