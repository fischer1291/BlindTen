import Foundation

/// Local multiplayer: one host phone (the main screen, often on the TV) and
/// players who join with their own iPhones over the local network.
///
/// The host runs the `GameEngine` and sends every player a complete
/// `SessionSnapshot` after each change. Players send small events. A player's
/// phone measures START and STOP itself with `UITouch.timestamp` and only
/// sends the elapsed time, so network latency never affects a result.
enum SessionProtocol {
    /// Bonjour service type: 1–15 lowercase letters, digits or hyphens.
    /// Info.plist lists it under NSBonjourServices as _blindten._tcp/_udp.
    static let serviceType = "blindten"
    static let version = 1
    /// Discovery-info key for the session's display name.
    static let nameKey = "name"
}

/// Player → host.
enum ClientMessage: Codable, Equatable, Sendable {
    /// First message after connecting; also used to reconnect.
    case hello(player: Player, protocolVersion: Int)
    /// "Tap when ready" on the player's own handoff screen.
    case ready
    /// START was touched on the player's phone.
    case started
    /// STOP, with the elapsed seconds measured on the player's phone.
    case stopped(elapsed: TimeInterval)
    /// The player's app left the foreground mid-turn: replay the turn.
    case voided
}

/// Host → player.
enum HostMessage: Codable, Equatable, Sendable {
    case snapshot(SessionSnapshot)
    case rejected(SessionRejection)
}

enum SessionRejection: String, Codable, Sendable {
    case full
    case gameInProgress
    case incompatibleVersion
}

struct SessionPlayer: Codable, Equatable, Identifiable, Sendable {
    var player: Player
    var isConnected: Bool

    var id: Player.ID { player.id }
}

struct SessionResult: Codable, Equatable, Identifiable, Sendable {
    let playerID: Player.ID
    /// As displayed (two decimals).
    let stopped: TimeInterval
    let deviation: TimeInterval
    let outcome: TurnOutcome
    let points: Int
    let reaction: String?

    var id: Player.ID { playerID }
}

struct SessionStanding: Codable, Equatable, Identifiable, Sendable {
    let playerID: Player.ID
    let points: Int
    let totalDeviation: TimeInterval
    let isEliminated: Bool

    var id: Player.ID { playerID }
}

/// Everything a player's phone needs to render the game.
struct SessionSnapshot: Codable, Equatable, Sendable {
    enum Stage: String, Codable, Sendable {
        case lobby
        case handoff
        case ready
        case running
        case reveal
        case roundResults
        case finished
    }

    var revision: Int
    var hostName: String
    var mode: ModeKind
    var stage: Stage
    var round: Int
    var rounds: Int
    var players: [SessionPlayer]
    /// Identifies the current turn so phones can reset their local turn state.
    var turnID: UUID?
    /// Counts voided attempts, so phones also reset when a turn is replayed.
    var turnAttempt: Int
    var turnPlayerIDs: [Player.ID]
    var target: TimeInterval
    var effect: BlindEffect
    /// Players of the current turn who have tapped "ready".
    var readyPlayerIDs: [Player.ID]
    var startedPlayerIDs: [Player.ID]
    var finishedPlayerIDs: [Player.ID]
    /// False during the drumroll; results stay hidden until the reveal lands.
    var revealLanded: Bool
    var results: [SessionResult]
    /// Leaderboard order.
    var standings: [SessionStanding]
    var winnerID: Player.ID?
    var winningTeam: Int?

    func player(_ id: Player.ID) -> Player? {
        players.first { $0.id == id }?.player
    }
}

/// JSON coding for the wire.
enum SessionCoding {
    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}
