import Foundation
import Testing
@testable import BlindTen

struct LiveMatchTests {
    let mia = Player(name: "Mia", emoji: "🦊")
    let ben = Player(name: "Ben", emoji: "🐸")
    let zoe = Player(name: "Zoe", emoji: "🐙")

    @Test func everyonePlaysEachTurnTogether() throws {
        var engine = try GameEngine(players: [mia, ben, zoe], mode: TogetherMode(base: ClassicMode()), rounds: 2)
        #expect(engine.lanes.map(\.playerID) == [mia.id, ben.id, zoe.id])
        #expect(engine.mode.kind == .classic)
        engine.beginTurn()
        for lane in engine.lanes.indices {
            engine.start(lane: lane, at: 100)
        }
        engine.stop(lane: 0, at: 110.05)
        engine.stop(lane: 1, at: 110.40)
        #expect(engine.phase == .running)
        engine.stop(lane: 2, at: 108.0)
        #expect(engine.phase == .reveal)
        #expect(engine.revealedResults.count == 3)
        engine.advance()
        // One turn per round: the round is over.
        #expect(engine.phase == .roundResults)
        #expect(engine.standings().first?.player.id == mia.id)
    }

    @Test func randomTargetIsSharedByEveryone() throws {
        let engine = try GameEngine(players: [mia, ben], mode: TogetherMode(base: RandomTargetMode()), rounds: 1)
        #expect(RandomTargetMode.targetRange.contains(engine.target))
        #expect(engine.lanes.count == 2)
    }

    @Test func showdownHasNoTogetherVersion() {
        #expect(!TogetherMode.supports(.showdown))
        #expect(TogetherMode.supports(.classic))
        #expect(TogetherMode.supports(.elimination))
    }

    @Test func everyPhonePicksTheSameHost() {
        #expect(LiveMatchRules.host(among: ["G:3", "G:1", "G:2"]) == "G:1")
        #expect(LiveMatchRules.host(among: ["G:2", "G:3", "G:1"]) == "G:1")
        #expect(LiveMatchRules.host(among: []) == nil)
    }
}
