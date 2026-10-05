import Foundation
import SwiftData
import Testing
@testable import BlindTen

@MainActor
struct GameStoreTests {
    let container: ModelContainer
    let store: GameStore

    let mia = Player(name: "Mia", emoji: "🦊")
    let ben = Player(name: "Ben", emoji: "🐸")
    let zoe = Player(name: "Zoe", emoji: "🐙")

    init() throws {
        container = try GameStore.makeContainer(inMemory: true)
        store = GameStore(context: container.mainContext)
    }

    @Test func emptyStoreRemembersNobody() {
        #expect(store.lastGroupPlayers().isEmpty)
    }

    @Test func lastGroupComesBackInOrder() {
        store.rememberGroup([zoe, mia, ben])
        #expect(store.lastGroupPlayers() == [zoe, mia, ben])
    }

    @Test func theMostRecentGroupWins() {
        store.rememberGroup([mia, ben], at: Date(timeIntervalSince1970: 100))
        store.rememberGroup([zoe, ben], at: Date(timeIntervalSince1970: 200))
        #expect(store.lastGroupPlayers() == [zoe, ben])
    }

    @Test func theSamePlayersAreTheSameGroup() {
        let first = store.rememberGroup([mia, ben])
        let reordered = store.rememberGroup([ben, mia])
        let other = store.rememberGroup([mia, ben, zoe])
        #expect(first == reordered)
        #expect(first != other)
    }

    @Test func renamedPlayersKeepTheirIdentity() {
        store.rememberGroup([mia, ben])
        var renamed = mia
        renamed.name = "Mia K."
        store.rememberGroup([renamed, ben])
        #expect(store.lastGroupPlayers().first?.name == "Mia K.")
        let count = (try? container.mainContext.fetchCount(FetchDescriptor<StoredPlayer>())) ?? 0
        #expect(count == 2)
    }

    @Test func finishedGamesFeedTheGroupStats() throws {
        let groupID = store.rememberGroup([mia, ben])
        for _ in 0..<2 {
            var engine = try GameEngine(players: [mia, ben], rounds: 1)
            for elapsed in [10.0, 9.5] {
                engine.beginTurn()
                engine.start(at: 0)
                engine.stop(at: elapsed)
                engine.advance()
            }
            engine.advance()
            store.saveFinishedGame(engine, groupID: groupID, startedAt: .now)
        }
        let stats = store.turnStats(groupID: groupID)
        #expect(stats.count == 4)
        #expect(stats.filter { $0.outcome == .scored(.deadOn) }.count == 2)
        #expect(store.turnStats(groupID: UUID()).isEmpty)
    }

    @Test func quickPlayGamesBelongToNoGroup() throws {
        var engine = try GameEngine(players: [mia, ben], rounds: 1)
        engine.beginTurn()
        engine.start(at: 0)
        engine.stop(at: 10)
        store.saveFinishedGame(engine, groupID: nil, startedAt: .now)
        let games = try container.mainContext.fetch(FetchDescriptor<GameRecord>())
        #expect(games.count == 1)
        #expect(games.first?.groupID == nil)
        #expect(games.first?.mode == "classic")
        #expect(games.first?.targetSeconds == 10)
    }

    @Test func builtInHouseRulesAreSeededOnce() {
        store.seedDefaultHouseRules()
        store.seedDefaultHouseRules()
        let rules = store.houseRules()
        #expect(rules.count == HouseRuleCatalog.defaultCount)
        #expect(rules.map(\.text) == HouseRuleCatalog.defaultKeys)
        #expect(rules.allSatisfy { !$0.isCustom && $0.isEnabled })
    }

    @Test func customHouseRulesComeAfterBuiltInOnes() throws {
        store.seedDefaultHouseRules()
        let custom = try #require(store.addCustomHouseRule("  Moonwalk to the bar  "))
        #expect(custom.text == "Moonwalk to the bar")
        #expect(store.houseRules().last?.id == custom.id)
        #expect(store.addCustomHouseRule("   ") == nil)

        store.delete(custom)
        #expect(store.houseRules().count == HouseRuleCatalog.defaultCount)
    }

    @Test func disabledRulesAreNotDrawn() {
        store.seedDefaultHouseRules()
        store.houseRules().first?.isEnabled = false
        store.save()
        #expect(store.enabledHouseRules().count == HouseRuleCatalog.defaultCount - 1)
    }
}
