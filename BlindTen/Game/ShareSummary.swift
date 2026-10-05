import Foundation

/// What the share card shows at game end (SPEC.md "Share card").
struct ShareSummary: Equatable, Sendable {
    struct Row: Equatable, Sendable {
        let player: Player
        /// The player's closest timed turn, nil if they only misfired or timed out.
        let best: TurnResult?
        let points: Int
    }

    let mode: ModeKind
    let winner: Player?
    /// Teams mode only.
    let winningTeam: Int?
    let isTeamGame: Bool
    /// In leaderboard order.
    let rows: [Row]

    init(engine: GameEngine) {
        mode = engine.mode.kind
        winner = engine.winner
        winningTeam = engine.winningTeam
        isTeamGame = engine.mode.hasTeams
        rows = engine.standings().map { standing in
            Row(player: standing.player, best: engine.bestResult(for: standing.player.id), points: standing.points)
        }
    }
}

extension GameEngine {
    /// A player's closest timed turn (misfires and timeouts don't count).
    func bestResult(for playerID: Player.ID) -> TurnResult? {
        results
            .filter { result in
                guard result.playerID == playerID, case .scored = result.outcome else { return false }
                return true
            }
            .min { abs($0.deviation) < abs($1.deviation) }
    }
}
