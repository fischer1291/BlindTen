import Foundation

/// An asynchronous online duel: best of 3 between two players, each round
/// with the same target for both (SPEC.md "Version 2", M8). Pure rules, no
/// networking; the state travels as the turn-based match data.
///
/// Turn order keeps handoffs few: A plays round 1; B plays rounds 1 and 2;
/// A plays rounds 2 and 3; B plays round 3. A player may play a round once
/// the opponent has played the round before it. A player sees the
/// opponent's result of a round only after playing that round too.
struct DuelState: Codable, Equatable, Sendable {
    struct Turn: Codable, Equatable, Sendable {
        let stopped: TimeInterval
        /// False while the timer runs. A turn left unfinished (app killed)
        /// keeps its placeholder, which counts as a timeout.
        let isFinal: Bool
    }

    enum RoundResult: Equatable, Sendable {
        case won(by: Int)
        case tie
    }

    enum Outcome: Equatable, Sendable {
        case won(by: Int)
        case draw
    }

    enum DuelError: Error, Equatable {
        case notYourRound
    }

    static let rounds = 3
    static let winsNeeded = 2
    /// Bumped when the format changes; older apps refuse newer duels.
    static let currentVersion = 1

    let version: Int
    let kind: ChallengeKind
    let seed: UInt64
    /// turns[player][round], player 0 = the duel's creator.
    private(set) var turns: [[Turn?]]

    init(kind: ChallengeKind, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        version = Self.currentVersion
        self.kind = kind
        self.seed = seed
        turns = Array(repeating: Array(repeating: nil, count: Self.rounds), count: 2)
    }

    /// Same for both players, derived from the seed.
    func target(round: Int) -> TimeInterval {
        switch kind {
        case .classic:
            return GameEngine.classicTarget
        case .randomTarget:
            var generator = SplitMix64(seed: seed)
            var target = GameEngine.classicTarget
            for _ in 0...round {
                target = RandomTargetMode().makeTarget(using: &generator)
            }
            return target
        }
    }

    func turn(player: Int, round: Int) -> Turn? {
        turns[player][round]
    }

    func stopped(player: Int, round: Int) -> TimeInterval? {
        turns[player][round]?.stopped
    }

    // MARK: - Whose turn

    /// The next round this player may play, or nil if they have to wait.
    /// Whoever holds the turn plays rounds while this returns one, then
    /// passes the turn on.
    func nextRound(for player: Int) -> Int? {
        guard outcome == nil else { return nil }
        guard let round = turns[player].firstIndex(where: { $0 == nil }) else { return nil }
        if round > 0, turns[1 - player][round - 1] == nil { return nil }
        return round
    }

    // MARK: - Playing

    /// The timer started: a placeholder timeout is stored first, so quitting
    /// mid-turn cannot be used to retry a round.
    mutating func begin(round: Int, player: Int) throws {
        guard nextRound(for: player) == round else { throw DuelError.notYourRound }
        turns[player][round] = Turn(stopped: Scoring.timeoutDuration(for: target(round: round)), isFinal: false)
    }

    /// Records a stop for a round that was begun.
    mutating func record(stopped: TimeInterval, round: Int, player: Int) throws {
        guard let current = turns[player][round], !current.isFinal else { throw DuelError.notYourRound }
        turns[player][round] = Turn(stopped: stopped, isFinal: true)
    }

    // MARK: - Results

    /// The round's winner, once both have played it.
    func result(round: Int) -> RoundResult? {
        guard let first = turns[0][round], let second = turns[1][round] else { return nil }
        let target = target(round: round)
        switch (Self.hundredthsOff(first.stopped, target), Self.hundredthsOff(second.stopped, target)) {
        case (nil, nil): return .tie
        case (.some, nil): return .won(by: 0)
        case (nil, .some): return .won(by: 1)
        case let (.some(a), .some(b)): return a == b ? .tie : .won(by: a < b ? 0 : 1)
        }
    }

    /// Round wins per player.
    var wins: [Int] {
        (0..<Self.rounds).reduce(into: [0, 0]) { wins, round in
            if case .won(let player) = result(round: round) {
                wins[player] += 1
            }
        }
    }

    /// Set once someone has 2 round wins or all rounds are played.
    var outcome: Outcome? {
        let wins = wins
        if let leader = wins.firstIndex(where: { $0 >= Self.winsNeeded }) {
            return .won(by: leader)
        }
        let allPlayed = turns.allSatisfy { $0.allSatisfy { $0 != nil } }
        guard allPlayed else { return nil }
        if wins[0] == wins[1] { return .draw }
        return .won(by: wins[0] > wins[1] ? 0 : 1)
    }

    /// Whether `viewer` may see `player`'s result of `round` yet.
    func isVisible(player: Int, round: Int, to viewer: Int) -> Bool {
        player == viewer || outcome != nil || turns[viewer][round] != nil
    }

    /// Absolute deviation in hundredths for a scored turn; nil for a misfire or timeout.
    private static func hundredthsOff(_ stopped: TimeInterval, _ target: TimeInterval) -> Int? {
        guard case .scored = Scoring.outcome(elapsed: stopped, target: target) else { return nil }
        return Scoring.hundredths(stopped - target)
    }

    // MARK: - Match data

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Nil for empty data (a new match) or a format this app does not know.
    static func decode(_ data: Data?) -> DuelState? {
        guard let data, !data.isEmpty,
              let state = try? JSONDecoder().decode(DuelState.self, from: data),
              state.version <= currentVersion
        else { return nil }
        return state
    }
}
