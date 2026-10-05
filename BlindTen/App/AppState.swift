import Foundation
import Observation

/// App-wide state: the roster being edited and the game in progress.
@MainActor
@Observable
final class AppState {
    /// Free tier limit (SPEC.md: max 10 free, unlimited with the Party Pack).
    static let maxFreePlayers = 10

    var roster: [Player] = []
    /// The running game, or nil while on the Players screen.
    var engine: GameEngine?

    func startGame(players: [Player], rounds: Int) throws {
        engine = try GameEngine(players: players, rounds: rounds)
    }

    /// Same players and settings, back to the first handoff.
    func rematch() {
        engine?.restart()
    }

    /// Leaves the game and returns to the Players screen.
    func newGame() {
        engine = nil
    }
}
