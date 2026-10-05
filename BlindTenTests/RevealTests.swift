import Foundation
import Testing
@testable import BlindTen

struct RevealTests {
    @Test func landingCues() {
        #expect(LandingCue(.scored(.deadOn)) == .deadOn)
        #expect(LandingCue(.scored(.lostInTime)) == .fail)
        #expect(LandingCue(.misfire) == .fail)
        #expect(LandingCue(.timeout) == .fail)
        for tier in [Tier.sharp, .close, .meh, .off] {
            #expect(LandingCue(.scored(tier)) == .neutral)
        }
    }

    @Test func drumrollStaysInTheSpecRange() {
        var generator = SeededGenerator(seed: 99)
        for _ in 0..<500 {
            let duration = RevealTiming.randomDrumrollDuration(using: &generator)
            #expect(RevealTiming.drumrollRange.contains(duration))
        }
    }

    @Test func slotRollStartsAtZeroAndLandsOnTarget() {
        #expect(SlotRoll.value(progress: 0, target: 10.27) == 0)
        #expect(SlotRoll.value(progress: 1, target: 10.27) == 10.27)
        #expect(SlotRoll.value(progress: 2, target: 10.27) == 10.27)
        #expect(SlotRoll.value(progress: -1, target: 10.27) == 0)
        #expect(SlotRoll.value(progress: .nan, target: 10.27) == 10.27)
    }

    @Test func slotRollRisesAndDecelerates() {
        var previous = -1.0
        for step in 0...20 {
            let value = SlotRoll.value(progress: Double(step) / 20, target: 10)
            #expect(value >= previous)
            previous = value
        }
        // Ease-out: more than half way after half the time.
        #expect(SlotRoll.value(progress: 0.5, target: 10) > 5)
    }

    @Test func directionFollowsTheDisplayedDeviation() throws {
        let players = ["Mia", "Ben", "Zoe", "Ali"].map { Player(name: $0, emoji: "🦊") }
        var engine = try GameEngine(players: players, rounds: 1)

        func turn(_ elapsed: TimeInterval) -> TurnResult? {
            engine.beginTurn()
            engine.start(at: 100)
            let result = engine.stop(at: 100 + elapsed)
            engine.advance()
            return result
        }

        let results = [turn(9.6), turn(10.4), turn(10.004), turn(0.3)].compactMap { $0 }
        try #require(results.count == 4)
        let (early, late, exact, misfire) = (results[0], results[1], results[2], results[3])
        #expect(early.direction == .early)
        #expect(late.direction == .late)
        #expect(exact.direction == .exact)
        #expect(misfire.direction == .early)
    }
}
