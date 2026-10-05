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
    /// Haptics and sound.
    let feel = GameFeel()

    /// Reaction line key chosen for each finished turn.
    private(set) var reactionKeys: [TurnResult.ID: String] = [:]
    @ObservationIgnored private var reactionDeck = ReactionDeck()

    func startGame(players: [Player], rounds: Int) throws {
        engine = try GameEngine(players: players, rounds: rounds)
        resetReactions()
    }

    /// Same players and settings, back to the first handoff.
    func rematch() {
        engine?.restart()
        resetReactions()
    }

    /// Leaves the game and returns to the Players screen.
    func newGame() {
        engine = nil
        resetReactions()
    }

    /// STOP. Ends the running turn and picks its reaction line.
    @discardableResult
    func stop(at timestamp: TimeInterval) -> TurnResult? {
        guard let result = engine?.stop(at: timestamp) else { return nil }
        assignReaction(to: result)
        return result
    }

    /// Auto-stop at target × 3.
    @discardableResult
    func autoStopIfOverdue(now: TimeInterval) -> TurnResult? {
        guard let result = engine?.autoStopIfOverdue(now: now) else { return nil }
        assignReaction(to: result)
        return result
    }

    /// The localized reaction line for a finished turn.
    func reactionText(for result: TurnResult) -> String? {
        reactionKeys[result.id].map { ReactionText.text(forKey: $0) }
    }

    private func assignReaction(to result: TurnResult) {
        reactionKeys[result.id] = reactionDeck.draw(for: ReactionCategory(result.outcome))
    }

    private func resetReactions() {
        reactionDeck.reset()
        reactionKeys = [:]
    }
}
