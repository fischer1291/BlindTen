import Foundation

/// The result of one player's turn.
struct TurnResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let playerID: Player.ID
    let round: Int
    let target: TimeInterval
    /// Measured time in seconds, stored raw. On a timeout it is the auto-stop time.
    let stopped: TimeInterval
    let outcome: TurnOutcome

    var deviation: TimeInterval { stopped - target }
    var points: Int { outcome.points }

    /// Deviation as displayed (two decimals). The tier is derived from this value.
    var displayedDeviation: TimeInterval { Scoring.roundedToHundredths(deviation) }
    /// Stopped time as displayed, kept consistent with `displayedDeviation`.
    var displayedStopped: TimeInterval { target + displayedDeviation }
}

/// Whether a turn stopped before or after the target (SPEC.md: blue = too early, red = too late).
enum TimingDirection: Sendable {
    case early
    case late
    case exact
}

extension TurnResult {
    /// Based on the displayed two-decimal deviation, so "+0.00" counts as exact.
    var direction: TimingDirection {
        if displayedDeviation < 0 { return .early }
        if displayedDeviation > 0 { return .late }
        return .exact
    }
}

/// One row of a leaderboard.
struct Standing: Identifiable, Hashable, Sendable {
    let player: Player
    let points: Int
    /// Sum of absolute deviations in seconds. Lower is better; breaks ties on points.
    let totalDeviation: TimeInterval

    var id: Player.ID { player.id }
}

/// Classic-mode game rules as a pure state machine.
///
/// Flow per round: for every player `handoff → ready → running → reveal`,
/// then `roundResults`, then the next round or `finished`.
/// All times are seconds on the system-uptime clock (`UITouch.timestamp`,
/// `ProcessInfo.systemUptime`), passed in by the caller.
struct GameEngine: Sendable {
    static let defaultRounds = 3
    static let classicTarget: TimeInterval = 10
    static let minPlayers = 2

    enum SetupError: Error, Equatable {
        case notEnoughPlayers
        case invalidRoundCount
        case invalidTarget
    }

    enum Phase: Equatable, Sendable {
        /// "Pass the phone to …", waiting for the player to tap.
        case handoff
        /// Target shown, waiting for START.
        case ready
        /// Blind phase. `startedAt` is the START touch timestamp.
        case running(startedAt: TimeInterval)
        /// Showing the result of the turn that just ended.
        case reveal(TurnResult)
        /// Every player has played the current round.
        case roundResults
        /// All rounds are done.
        case finished
    }

    let players: [Player]
    let rounds: Int
    let target: TimeInterval

    private(set) var phase: Phase = .handoff
    /// 1-based.
    private(set) var round = 1
    private(set) var playerIndex = 0
    private(set) var results: [TurnResult] = []

    init(
        players: [Player],
        rounds: Int = GameEngine.defaultRounds,
        target: TimeInterval = GameEngine.classicTarget
    ) throws {
        guard players.count >= Self.minPlayers else { throw SetupError.notEnoughPlayers }
        guard rounds >= 1 else { throw SetupError.invalidRoundCount }
        guard target.isFinite, target > Scoring.misfireThreshold else { throw SetupError.invalidTarget }
        self.players = players
        self.rounds = rounds
        self.target = target
    }

    // MARK: - Derived state

    /// The player whose turn it is (or whose result is being revealed).
    var currentPlayer: Player? {
        switch phase {
        case .handoff, .ready, .running, .reveal: players[playerIndex]
        case .roundResults, .finished: nil
        }
    }

    var isLastRound: Bool { round == rounds }

    /// System-uptime moment at which the running turn auto-stops.
    var timeoutDeadline: TimeInterval? {
        guard case .running(let startedAt) = phase else { return nil }
        return startedAt + Scoring.timeoutDuration(for: target)
    }

    func player(withID id: Player.ID) -> Player? {
        players.first { $0.id == id }
    }

    // MARK: - Turn flow

    /// Handoff → ready.
    mutating func beginTurn() {
        guard phase == .handoff else { return }
        phase = .ready
    }

    /// Ready → running. `timestamp` is the START touch timestamp.
    mutating func start(at timestamp: TimeInterval) {
        guard phase == .ready else { return }
        phase = .running(startedAt: timestamp)
    }

    /// Running → reveal. `timestamp` is the STOP touch timestamp.
    @discardableResult
    mutating func stop(at timestamp: TimeInterval) -> TurnResult? {
        guard case .running(let startedAt) = phase else { return nil }
        return record(elapsed: max(0, timestamp - startedAt))
    }

    /// Auto-stops the running turn once `now` has reached the timeout deadline.
    @discardableResult
    mutating func autoStopIfOverdue(now: TimeInterval) -> TurnResult? {
        guard let deadline = timeoutDeadline, now >= deadline else { return nil }
        return record(elapsed: Scoring.timeoutDuration(for: target))
    }

    /// Voids an unfinished turn (e.g. the app went to the background).
    /// The same player replays it, starting from the handoff.
    mutating func voidTurn() {
        switch phase {
        case .ready, .running: phase = .handoff
        case .handoff, .reveal, .roundResults, .finished: break
        }
    }

    /// Discards the revealed result so the turn is replayed ("wrong player tapped").
    mutating func replayTurn() {
        guard case .reveal(let result) = phase else { return }
        results.removeAll { $0.id == result.id }
        phase = .handoff
    }

    /// Reveal → next player's handoff, or round results after the last player.
    /// Round results → next round, or finished after the last round.
    mutating func advance() {
        switch phase {
        case .reveal:
            if playerIndex + 1 < players.count {
                playerIndex += 1
                phase = .handoff
            } else {
                phase = .roundResults
            }
        case .roundResults:
            if round < rounds {
                round += 1
                playerIndex = 0
                phase = .handoff
            } else {
                phase = .finished
            }
        case .handoff, .ready, .running, .finished:
            break
        }
    }

    /// Starts over with the same players and settings ("Rematch").
    mutating func restart() {
        phase = .handoff
        round = 1
        playerIndex = 0
        results = []
    }

    private mutating func record(elapsed: TimeInterval) -> TurnResult {
        let outcome = Scoring.outcome(elapsed: elapsed, target: target)
        let stopped = outcome == .timeout ? Scoring.timeoutDuration(for: target) : elapsed
        let result = TurnResult(
            id: UUID(),
            playerID: players[playerIndex].id,
            round: round,
            target: target,
            stopped: stopped,
            outcome: outcome
        )
        results.append(result)
        phase = .reveal(result)
        return result
    }

    // MARK: - Leaderboards

    /// Leaderboard for one round, or for the whole game when `round` is nil.
    /// Sorted by points (high first), then total deviation (low first),
    /// then player order.
    func standings(round: Int? = nil) -> [Standing] {
        let relevant = results.filter { round == nil || $0.round == round }
        var rows: [(index: Int, standing: Standing)] = []
        for (index, player) in players.enumerated() {
            let mine = relevant.filter { $0.playerID == player.id }
            let points = mine.reduce(0) { $0 + $1.points }
            let deviation = mine.reduce(0.0) { $0 + abs($1.deviation) }
            rows.append((index, Standing(player: player, points: points, totalDeviation: deviation)))
        }
        rows.sort { lhs, rhs in
            if lhs.standing.points != rhs.standing.points {
                return lhs.standing.points > rhs.standing.points
            }
            if lhs.standing.totalDeviation != rhs.standing.totalDeviation {
                return lhs.standing.totalDeviation < rhs.standing.totalDeviation
            }
            return lhs.index < rhs.index
        }
        return rows.map(\.standing)
    }

    /// Worst player of a completed round.
    func roundLoser(_ round: Int) -> Player? {
        let played = Set(results.filter { $0.round == round }.map(\.playerID))
        guard played.count == players.count else { return nil }
        return standings(round: round).last?.player
    }

    /// Overall winner, once the game is finished.
    var winner: Player? {
        guard phase == .finished else { return nil }
        return standings().first?.player
    }
}
