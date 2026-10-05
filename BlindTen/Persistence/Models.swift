import Foundation
import SwiftData

// SPEC.md data model, stored locally with SwiftData. Names carry a suffix
// where the spec's would clash with SwiftUI (`Group`) or the engine (`Player`).

/// SPEC.md `Player`: id, name, emoji, colorIndex, createdAt.
@Model
final class StoredPlayer {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var colorIndex: Int
    var createdAt: Date

    init(id: UUID, name: String, emoji: String, colorIndex: Int, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }
}

/// SPEC.md `Group`: id, name, players[], lastPlayedAt.
@Model
final class PlayerGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Members in play order. Stored as IDs because SwiftData relationships
    /// do not keep their order.
    var memberIDs: [UUID]
    var lastPlayedAt: Date

    init(id: UUID, name: String, memberIDs: [UUID], lastPlayedAt: Date) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
        self.lastPlayedAt = lastPlayedAt
    }
}

/// SPEC.md `Game`: id, mode, rounds, targetSeconds?, startedAt, groupId.
@Model
final class GameRecord {
    @Attribute(.unique) var id: UUID
    /// `ModeKind` raw value.
    var mode: String
    var rounds: Int
    /// Fixed target, or nil when it changes per turn (Random Target).
    var targetSeconds: Double?
    var startedAt: Date
    /// Nil for quick-play games.
    var groupID: UUID?

    init(id: UUID, mode: String, rounds: Int, targetSeconds: Double?, startedAt: Date, groupID: UUID?) {
        self.id = id
        self.mode = mode
        self.rounds = rounds
        self.targetSeconds = targetSeconds
        self.startedAt = startedAt
        self.groupID = groupID
    }
}

/// SPEC.md `Turn`: id, gameId, playerId, round, target, stopped, deviation,
/// points, misfire. `outcomeCode` keeps the exact outcome for stats.
@Model
final class TurnRecord {
    @Attribute(.unique) var id: UUID
    var gameID: UUID
    var playerID: UUID
    var round: Int
    var target: Double
    var stopped: Double
    var deviation: Double
    var points: Int
    var misfire: Bool
    var outcomeCode: String

    init(result: TurnResult, gameID: UUID) {
        id = result.id
        self.gameID = gameID
        playerID = result.playerID
        round = result.round
        target = result.target
        stopped = result.stopped
        deviation = result.deviation
        points = result.points
        misfire = result.outcome == .misfire
        outcomeCode = result.outcome.code
    }
}

/// SPEC.md `HouseRule`: id, text, isCustom, isEnabled.
@Model
final class HouseRule {
    @Attribute(.unique) var id: UUID
    /// Custom cards: the text. Built-in cards: a String Catalog key.
    var text: String
    var isCustom: Bool
    var isEnabled: Bool
    var createdAt: Date

    init(id: UUID = UUID(), text: String, isCustom: Bool, isEnabled: Bool = true, createdAt: Date = .now) {
        self.id = id
        self.text = text
        self.isCustom = isCustom
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var displayText: String {
        HouseRuleCatalog.text(stored: text, isCustom: isCustom)
    }
}
