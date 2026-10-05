import Foundation

/// The game modes from SPEC.md.
enum ModeKind: String, CaseIterable, Identifiable, Sendable {
    case classic
    case randomTarget
    case showdown
    case distraction
    case liarsClock
    case heartbeat
    case elimination
    case teams

    var id: String { rawValue }

    /// SPEC.md: the MVP ships three free modes; the rest is the Party Pack.
    var isFree: Bool {
        switch self {
        case .classic, .randomTarget, .showdown: true
        case .distraction, .liarsClock, .heartbeat, .elimination, .teams: false
        }
    }

    var mode: any GameMode {
        switch self {
        case .classic: ClassicMode()
        case .randomTarget: RandomTargetMode()
        case .showdown: ShowdownMode()
        case .distraction: DistractionMode()
        case .liarsClock: LiarsClockMode()
        case .heartbeat: HeartbeatMode()
        case .elimination: EliminationMode()
        case .teams: TeamsMode()
        }
    }
}

/// What the blind phase shows, plays or vibrates. Generated per turn.
enum BlindEffect: Equatable, Sendable {
    /// Classic dark screen.
    case dark
    /// Beeps at these offsets after START (seconds), at irregular intervals.
    case distraction(beepTimes: [TimeInterval])
    /// A countdown that runs `rate` times real time (never 1).
    case liarsClock(rate: Double)
    /// A haptic pulse every `interval` seconds (never 1).
    case heartbeat(interval: TimeInterval)
}

/// Rules that vary between modes. `GameEngine` owns the shared flow.
protocol GameMode: Sendable {
    var kind: ModeKind { get }
    /// 1 = pass the phone; 2 = Showdown split screen.
    var playersPerTurn: Int { get }
    /// Players knocked out each round (Elimination).
    var eliminatesRoundLoser: Bool { get }
    /// Two teams by alternating roster order (Teams).
    var hasTeams: Bool { get }

    func roundCount(requested: Int, playerCount: Int) -> Int
    func makeTarget<G: RandomNumberGenerator>(using generator: inout G) -> TimeInterval
    func makeBlindEffect<G: RandomNumberGenerator>(target: TimeInterval, using generator: inout G) -> BlindEffect
    /// The turns of one round. Players in the same inner array play at once.
    func turns(round: Int, players: [Player.ID]) -> [[Player.ID]]
}

extension GameMode {
    var playersPerTurn: Int { 1 }
    var eliminatesRoundLoser: Bool { false }
    var hasTeams: Bool { false }

    func roundCount(requested: Int, playerCount: Int) -> Int {
        requested
    }

    func makeTarget<G: RandomNumberGenerator>(using generator: inout G) -> TimeInterval {
        GameEngine.classicTarget
    }

    func makeBlindEffect<G: RandomNumberGenerator>(target: TimeInterval, using generator: inout G) -> BlindEffect {
        .dark
    }

    func turns(round: Int, players: [Player.ID]) -> [[Player.ID]] {
        players.map { [$0] }
    }
}
