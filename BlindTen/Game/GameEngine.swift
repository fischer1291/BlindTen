import Foundation

/// The result of one player's turn.
struct TurnResult: Identifiable, Hashable, Sendable {
    let id: UUID
    /// Shared by both players of a Showdown duel.
    let turnID: UUID
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
    /// Showdown duels won.
    let duelWins: Int
    /// Elimination: the round this player was knocked out in, nil while still in.
    let eliminatedInRound: Int?
    /// Teams: 0 or 1.
    let team: Int?

    var id: Player.ID { player.id }
}

/// One team's combined result (Teams mode).
struct TeamStanding: Identifiable, Hashable, Sendable {
    let team: Int
    let members: [Player]
    let points: Int
    let totalDeviation: TimeInterval
    let turns: Int

    var id: Int { team }

    /// Equals the summed deviation ranking when both teams have the same
    /// number of players, and stays fair when one team has a player more.
    var averageDeviation: TimeInterval {
        turns == 0 ? 0 : totalDeviation / Double(turns)
    }
}

/// Game rules as a pure state machine. Mode-specific rules come from `GameMode`.
///
/// Flow per round: for every turn `handoff → ready → running → reveal`,
/// then `roundResults`, then the next round or `finished`. A turn has one
/// lane per player playing it (two in Showdown). All times are seconds on
/// the system-uptime clock (`UITouch.timestamp`, `ProcessInfo.systemUptime`).
struct GameEngine: Sendable {
    static let defaultRounds = 3
    static let classicTarget: TimeInterval = 10
    static let minPlayers = 2

    enum SetupError: Error, Equatable {
        case notEnoughPlayers
        case invalidRoundCount
    }

    enum Phase: Equatable, Sendable {
        /// "Pass the phone to …", waiting for a tap.
        case handoff
        /// Target shown, waiting for START.
        case ready
        /// At least one lane started, not all finished.
        case running
        /// Every lane of the turn has a result.
        case reveal
        /// Every turn of the round has been played.
        case roundResults
        /// The game is over.
        case finished
    }

    /// One player's timer within the current turn.
    struct Lane: Equatable, Sendable {
        let playerID: Player.ID
        /// START touch timestamp.
        var startedAt: TimeInterval?
        var result: TurnResult?

        var isRunning: Bool { startedAt != nil && result == nil }
        var isDone: Bool { result != nil }
    }

    let players: [Player]
    let mode: any GameMode
    /// Number of rounds actually played (Elimination: players − 1).
    let rounds: Int

    private(set) var phase: Phase = .handoff
    /// 1-based.
    private(set) var round = 1
    /// Index of the current turn within `schedule`.
    private(set) var turnIndex = 0
    /// Turns of the current round.
    private(set) var schedule: [[Player.ID]] = []
    /// Target of the current turn.
    private(set) var target: TimeInterval = GameEngine.classicTarget
    /// Blind-phase effect of the current turn.
    private(set) var blindEffect: BlindEffect = .dark
    private(set) var lanes: [Lane] = []
    private(set) var results: [TurnResult] = []
    /// Elimination: knocked-out players, in order.
    private(set) var eliminated: [Player.ID] = []

    private var turnID = UUID()
    private var participants: [Int: Set<Player.ID>] = [:]
    private var generator: SplitMix64

    init(
        players: [Player],
        mode: any GameMode = ClassicMode(),
        rounds: Int = GameEngine.defaultRounds,
        seed: UInt64? = nil
    ) throws {
        guard players.count >= Self.minPlayers else { throw SetupError.notEnoughPlayers }
        guard rounds >= 1 else { throw SetupError.invalidRoundCount }
        self.players = players
        self.mode = mode
        self.rounds = mode.roundCount(requested: rounds, playerCount: players.count)
        generator = seed.map { SplitMix64(seed: $0) } ?? SplitMix64()
        startRound(1)
    }

    // MARK: - Derived state

    var activePlayers: [Player] {
        players.filter { !eliminated.contains($0.id) }
    }

    /// Players of the current turn (two in Showdown).
    var currentPlayers: [Player] {
        switch phase {
        case .handoff, .ready, .running, .reveal: lanes.compactMap { player(withID: $0.playerID) }
        case .roundResults, .finished: []
        }
    }

    /// The single player of a pass-the-phone turn.
    var currentPlayer: Player? { currentPlayers.first }

    /// Results of the turn being revealed.
    var revealedResults: [TurnResult] {
        phase == .reveal ? lanes.compactMap(\.result) : []
    }

    /// True once the last round's results are on screen.
    var isFinalRound: Bool {
        round >= rounds || (mode.eliminatesRoundLoser && activePlayers.count <= 1)
    }

    /// Earliest auto-stop moment among running lanes.
    var timeoutDeadline: TimeInterval? {
        lanes.compactMap { lane in
            lane.isRunning ? lane.startedAt.map { $0 + Scoring.timeoutDuration(for: target) } : nil
        }.min()
    }

    func player(withID id: Player.ID) -> Player? {
        players.first { $0.id == id }
    }

    func team(of playerID: Player.ID) -> Int? {
        guard mode.hasTeams, let index = players.firstIndex(where: { $0.id == playerID }) else { return nil }
        return Teams.team(forPlayerAt: index)
    }

    // MARK: - Turn flow

    /// Handoff → ready.
    mutating func beginTurn() {
        guard phase == .handoff else { return }
        phase = .ready
    }

    /// START for one lane. `timestamp` is the touch timestamp.
    mutating func start(lane: Int = 0, at timestamp: TimeInterval) {
        guard phase == .ready || phase == .running,
              lanes.indices.contains(lane),
              lanes[lane].startedAt == nil
        else { return }
        lanes[lane].startedAt = timestamp
        phase = .running
    }

    /// STOP for one lane. `timestamp` is the touch timestamp.
    @discardableResult
    mutating func stop(lane: Int = 0, at timestamp: TimeInterval) -> TurnResult? {
        guard phase == .running,
              lanes.indices.contains(lane),
              lanes[lane].isRunning,
              let startedAt = lanes[lane].startedAt
        else { return nil }
        return record(lane: lane, elapsed: max(0, timestamp - startedAt))
    }

    /// Auto-stops every running lane whose timeout (target × 3) has passed.
    @discardableResult
    mutating func autoStopIfOverdue(now: TimeInterval) -> [TurnResult] {
        let timeout = Scoring.timeoutDuration(for: target)
        var stopped: [TurnResult] = []
        for index in lanes.indices {
            guard lanes[index].isRunning, let startedAt = lanes[index].startedAt, now >= startedAt + timeout else { continue }
            stopped.append(record(lane: index, elapsed: timeout))
        }
        return stopped
    }

    /// Voids an unfinished turn (e.g. the app went to the background).
    /// The same players replay it, starting from the handoff.
    mutating func voidTurn() {
        guard phase == .ready || phase == .running else { return }
        resetLanes()
    }

    /// Discards the revealed results so the turn is replayed ("wrong player tapped").
    mutating func replayTurn() {
        guard phase == .reveal else { return }
        resetLanes()
    }

    /// Reveal → next turn, or round results after the last turn.
    /// Round results → next round, or finished after the last round.
    mutating func advance() {
        switch phase {
        case .reveal:
            if turnIndex + 1 < schedule.count {
                turnIndex += 1
                prepareTurn()
            } else {
                finishRound()
            }
        case .roundResults:
            if isFinalRound {
                phase = .finished
            } else {
                startRound(round + 1)
            }
        case .handoff, .ready, .running, .finished:
            break
        }
    }

    /// Starts over with the same players and mode ("Rematch").
    mutating func restart() {
        results = []
        eliminated = []
        participants = [:]
        startRound(1)
    }

    private mutating func startRound(_ number: Int) {
        round = number
        let ids = activePlayers.map(\.id)
        schedule = mode.turns(round: number, players: ids).filter { !$0.isEmpty }
        participants[number] = Set(schedule.flatMap { $0 })
        turnIndex = 0
        if schedule.isEmpty {
            lanes = []
            phase = .finished
        } else {
            prepareTurn()
        }
    }

    private mutating func prepareTurn() {
        turnID = UUID()
        target = mode.makeTarget(using: &generator)
        blindEffect = mode.makeBlindEffect(target: target, using: &generator)
        lanes = schedule[turnIndex].map { Lane(playerID: $0) }
        phase = .handoff
    }

    private mutating func resetLanes() {
        let ids = Set(lanes.compactMap { $0.result?.id })
        results.removeAll { ids.contains($0.id) }
        lanes = lanes.map { Lane(playerID: $0.playerID) }
        phase = .handoff
    }

    private mutating func finishRound() {
        if mode.eliminatesRoundLoser, let loser = roundLoser(round) {
            eliminated.append(loser.id)
        }
        phase = .roundResults
    }

    private mutating func record(lane: Int, elapsed: TimeInterval) -> TurnResult {
        let outcome = Scoring.outcome(elapsed: elapsed, target: target)
        let stopped = outcome == .timeout ? Scoring.timeoutDuration(for: target) : elapsed
        let result = TurnResult(
            id: UUID(),
            turnID: turnID,
            playerID: lanes[lane].playerID,
            round: round,
            target: target,
            stopped: stopped,
            outcome: outcome
        )
        results.append(result)
        lanes[lane].result = result
        if lanes.allSatisfy(\.isDone) {
            phase = .reveal
        }
        return result
    }

    // MARK: - Leaderboards

    /// Leaderboard for one round (only players who played it) or the whole game.
    ///
    /// Default order: points, then total deviation, then player order.
    /// Showdown ranks by duels won first; Elimination ranks by how long
    /// a player survived first.
    func standings(round: Int? = nil) -> [Standing] {
        let relevant = results.filter { round == nil || $0.round == round }
        let wins = duelWins(in: relevant)
        var rows: [(index: Int, standing: Standing)] = []
        for (index, player) in players.enumerated() {
            if let round, !(participants[round]?.contains(player.id) ?? false) { continue }
            let mine = relevant.filter { $0.playerID == player.id }
            let points = mine.reduce(0) { $0 + $1.points }
            let deviation = mine.reduce(0.0) { $0 + abs($1.deviation) }
            let eliminatedIn = eliminated.firstIndex(of: player.id).map { $0 + 1 }
            let standing = Standing(
                player: player,
                points: points,
                totalDeviation: deviation,
                duelWins: wins[player.id, default: 0],
                eliminatedInRound: eliminatedIn,
                team: team(of: player.id)
            )
            rows.append((index, standing))
        }
        let ranksSurvival = mode.eliminatesRoundLoser && round == nil
        let ranksDuels = mode.playersPerTurn == 2
        rows.sort { lhs, rhs in
            let a = lhs.standing
            let b = rhs.standing
            if ranksSurvival, a.eliminatedInRound != b.eliminatedInRound {
                // Still in (nil) beats knocked out; later knock-out beats earlier.
                return (a.eliminatedInRound ?? Int.max) > (b.eliminatedInRound ?? Int.max)
            }
            if ranksDuels, a.duelWins != b.duelWins {
                return a.duelWins > b.duelWins
            }
            if a.points != b.points {
                return a.points > b.points
            }
            if a.totalDeviation != b.totalDeviation {
                return a.totalDeviation < b.totalDeviation
            }
            return lhs.index < rhs.index
        }
        return rows.map(\.standing)
    }

    /// Worst player of a completed round, or nil if it is not complete.
    func roundLoser(_ round: Int) -> Player? {
        guard let expected = participants[round], expected.count >= 2 else { return nil }
        let played = Set(results.filter { $0.round == round }.map(\.playerID))
        guard played == expected else { return nil }
        return standings(round: round).last?.player
    }

    /// Teams ranked by average deviation per turn (lower first).
    func teamStandings(round: Int? = nil) -> [TeamStanding] {
        guard mode.hasTeams else { return [] }
        let relevant = results.filter { round == nil || $0.round == round }
        return (0..<Teams.count).map { team in
            let members = players.enumerated()
                .filter { Teams.team(forPlayerAt: $0.offset) == team }
                .map(\.element)
            let ids = Set(members.map(\.id))
            let teamResults = relevant.filter { ids.contains($0.playerID) }
            return TeamStanding(
                team: team,
                members: members,
                points: teamResults.reduce(0) { $0 + $1.points },
                totalDeviation: teamResults.reduce(0.0) { $0 + abs($1.deviation) },
                turns: teamResults.count
            )
        }
        .sorted { lhs, rhs in
            lhs.averageDeviation != rhs.averageDeviation
                ? lhs.averageDeviation < rhs.averageDeviation
                : lhs.team < rhs.team
        }
    }

    /// Overall winner, once the game is finished.
    var winner: Player? {
        guard phase == .finished else { return nil }
        return standings().first?.player
    }

    /// Winning team, once a Teams game is finished. Nil on a tie.
    var winningTeam: Int? {
        guard phase == .finished, mode.hasTeams else { return nil }
        let teams = teamStandings()
        guard teams.count == 2, teams[0].averageDeviation != teams[1].averageDeviation else { return nil }
        return teams[0].team
    }

    /// The winner of a Showdown duel: the lower absolute deviation. Nil on a tie.
    static func duelWinner(of results: [TurnResult]) -> Player.ID? {
        guard results.count == 2 else { return nil }
        let first = abs(results[0].deviation)
        let second = abs(results[1].deviation)
        if first == second { return nil }
        return first < second ? results[0].playerID : results[1].playerID
    }

    private func duelWins(in results: [TurnResult]) -> [Player.ID: Int] {
        guard mode.playersPerTurn == 2 else { return [:] }
        var wins: [Player.ID: Int] = [:]
        for duel in Dictionary(grouping: results, by: \.turnID).values {
            if let winner = Self.duelWinner(of: duel) {
                wins[winner, default: 0] += 1
            }
        }
        return wins
    }
}
