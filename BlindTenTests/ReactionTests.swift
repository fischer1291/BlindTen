import Foundation
import Testing
@testable import BlindTen

struct ReactionTests {
    @Test func categoriesFollowTheOutcome() {
        #expect(ReactionCategory(.scored(.deadOn)) == .deadOn)
        #expect(ReactionCategory(.scored(.sharp)) == .sharp)
        #expect(ReactionCategory(.scored(.close)) == .close)
        #expect(ReactionCategory(.scored(.meh)) == .meh)
        #expect(ReactionCategory(.scored(.off)) == .off)
        #expect(ReactionCategory(.scored(.lostInTime)) == .lostInTime)
        #expect(ReactionCategory(.misfire) == .misfire)
        #expect(ReactionCategory(.timeout) == .timeout)
    }

    @Test func everyTierHasThirtyLines() {
        for tier in Tier.allCases {
            #expect(ReactionCategory(tier).lineCount == 30)
        }
    }

    @Test("Every reaction key has an English line in the String Catalog", arguments: ReactionCategory.allCases)
    func catalogHasEveryLine(category: ReactionCategory) {
        for key in category.allKeys {
            let text = ReactionText.text(forKey: key)
            #expect(text != key, "Missing catalog entry for \(key)")
            #expect(!text.isEmpty)
        }
    }

    @Test func allLinesAreDistinct() {
        let lines = ReactionCategory.allCases.flatMap(\.allKeys).map { ReactionText.text(forKey: $0) }
        #expect(Set(lines).count == lines.count)
    }

    @Test("A game never repeats a line until the category is used up", arguments: ReactionCategory.allCases)
    func noRepeatsWithinAGame(category: ReactionCategory) {
        var deck = ReactionDeck()
        var generator = SeededGenerator(seed: 42)
        var drawn: [String] = []
        for _ in 0..<category.lineCount {
            drawn.append(deck.draw(for: category, using: &generator))
        }
        #expect(Set(drawn).count == category.lineCount)
        #expect(Set(drawn) == Set(category.allKeys))

        let next = deck.draw(for: category, using: &generator)
        #expect(category.allKeys.contains(next))
    }

    @Test func categoriesAreTrackedSeparately() {
        var deck = ReactionDeck()
        var generator = SeededGenerator(seed: 7)
        let sharp = deck.draw(for: .sharp, using: &generator)
        let deadOn = deck.draw(for: .deadOn, using: &generator)
        #expect(sharp.hasPrefix("reaction.sharp."))
        #expect(deadOn.hasPrefix("reaction.deadOn."))
    }

    @Test func resetAllowsLinesAgain() {
        var deck = ReactionDeck()
        var generator = SeededGenerator(seed: 1)
        for _ in 0..<ReactionCategory.misfire.lineCount - 1 {
            _ = deck.draw(for: .misfire, using: &generator)
        }
        deck.reset()
        var drawn: Set<String> = []
        for _ in 0..<ReactionCategory.misfire.lineCount {
            drawn.insert(deck.draw(for: .misfire, using: &generator))
        }
        #expect(drawn.count == ReactionCategory.misfire.lineCount)
    }
}
