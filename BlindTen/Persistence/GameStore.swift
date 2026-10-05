import Foundation
import SwiftData

/// Local persistence: remembered groups, finished games and house rules.
@MainActor
final class GameStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            StoredPlayer.self, PlayerGroup.self, GameRecord.self, TurnRecord.self, HouseRule.self,
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
    }

    func save() {
        try? context.save()
    }

    // MARK: - Groups

    /// SPEC.md: "Last group is remembered."
    func lastGroupPlayers() -> [Player] {
        var descriptor = FetchDescriptor<PlayerGroup>(sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let group = (try? context.fetch(descriptor))?.first else { return [] }
        let stored = storedPlayers(withIDs: group.memberIDs)
        return group.memberIDs.compactMap { id in
            stored[id].map { Player(id: $0.id, name: $0.name, emoji: $0.emoji) }
        }
    }

    /// Saves the players and the group they form; the same set of players
    /// is always the same group, so its stats keep adding up.
    @discardableResult
    func rememberGroup(_ players: [Player], at date: Date = .now) -> UUID {
        let ids = players.map(\.id)
        let stored = storedPlayers(withIDs: ids)
        for (index, player) in players.enumerated() {
            if let existing = stored[player.id] {
                existing.name = player.name
                existing.emoji = player.emoji
            } else {
                context.insert(StoredPlayer(id: player.id, name: player.name, emoji: player.emoji, colorIndex: index))
            }
        }

        let memberSet = Set(ids)
        let groups = (try? context.fetch(FetchDescriptor<PlayerGroup>())) ?? []
        let group: PlayerGroup
        if let match = groups.first(where: { Set($0.memberIDs) == memberSet }) {
            group = match
        } else {
            group = PlayerGroup(id: UUID(), name: "", memberIDs: ids, lastPlayedAt: date)
            context.insert(group)
        }
        group.memberIDs = ids
        group.name = players.map(\.name).joined(separator: ", ")
        group.lastPlayedAt = date
        save()
        return group.id
    }

    private func storedPlayers(withIDs ids: [UUID]) -> [UUID: StoredPlayer] {
        let descriptor = FetchDescriptor<StoredPlayer>(predicate: #Predicate { ids.contains($0.id) })
        let players = (try? context.fetch(descriptor)) ?? []
        return Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Games

    func saveFinishedGame(_ engine: GameEngine, groupID: UUID?, startedAt: Date) {
        let gameID = UUID()
        let fixedTarget: Double? = engine.mode.kind == .randomTarget ? nil : GameEngine.classicTarget
        context.insert(GameRecord(
            id: gameID,
            mode: engine.mode.kind.rawValue,
            rounds: engine.rounds,
            targetSeconds: fixedTarget,
            startedAt: startedAt,
            groupID: groupID
        ))
        for result in engine.results {
            context.insert(TurnRecord(result: result, gameID: gameID))
        }
        save()
    }

    /// Every stored turn of a group's games, for its all-time awards.
    func turnStats(groupID: UUID) -> [TurnStat] {
        let optionalID: UUID? = groupID
        let games = (try? context.fetch(FetchDescriptor<GameRecord>(predicate: #Predicate { $0.groupID == optionalID }))) ?? []
        let gameIDs = games.map(\.id)
        guard !gameIDs.isEmpty else { return [] }
        let turns = (try? context.fetch(FetchDescriptor<TurnRecord>(predicate: #Predicate { gameIDs.contains($0.gameID) }))) ?? []
        return turns.compactMap { turn in
            TurnOutcome(code: turn.outcomeCode).map {
                TurnStat(playerID: turn.playerID, deviation: turn.deviation, outcome: $0)
            }
        }
    }

    // MARK: - House rules

    /// Adds any built-in card that is not stored yet. Safe to call on every launch.
    func seedDefaultHouseRules() {
        let builtIn = (try? context.fetch(FetchDescriptor<HouseRule>(predicate: #Predicate { !$0.isCustom }))) ?? []
        let existing = Set(builtIn.map(\.text))
        for (index, key) in HouseRuleCatalog.defaultKeys.enumerated() where !existing.contains(key) {
            // Fixed early dates keep built-in cards first and in catalog order.
            context.insert(HouseRule(text: key, isCustom: false, createdAt: Date(timeIntervalSince1970: Double(index))))
        }
        save()
    }

    func houseRules() -> [HouseRule] {
        (try? context.fetch(FetchDescriptor<HouseRule>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    func enabledHouseRules() -> [HouseRule] {
        houseRules().filter(\.isEnabled)
    }

    @discardableResult
    func addCustomHouseRule(_ text: String) -> HouseRule? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let rule = HouseRule(text: String(trimmed.prefix(120)), isCustom: true)
        context.insert(rule)
        save()
        return rule
    }

    func delete(_ rule: HouseRule) {
        context.delete(rule)
        save()
    }
}
