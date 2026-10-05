import Foundation
import Testing
@testable import BlindTen

struct AwardsTests {
    let mia = UUID()
    let ben = UUID()
    let zoe = UUID()

    private func stat(_ player: UUID, _ deviation: TimeInterval) -> TurnStat {
        TurnStat(playerID: player, deviation: deviation, outcome: Scoring.outcome(elapsed: 10 + deviation, target: 10))
    }

    private func award(_ kind: AwardKind, in awards: [Award]) -> Award? {
        awards.first { $0.kind == kind }
    }

    @Test func noTurnsNoAwards() {
        #expect(Awards.compute(from: []).isEmpty)
    }

    @Test func bestEverIsTheClosestTimedTurn() throws {
        let awards = Awards.compute(from: [stat(mia, 0.3), stat(ben, -0.02), stat(zoe, 0.1)])
        let best = try #require(award(.bestEver, in: awards))
        #expect(best.playerID == ben)
        #expect(abs(best.value - 0.02) < 1e-9)
    }

    @Test func bestEverIgnoresMisfiresAndTimeouts() throws {
        let misfire = TurnStat(playerID: zoe, deviation: -9.99, outcome: .misfire)
        let timeout = TurnStat(playerID: zoe, deviation: 20, outcome: .timeout)
        let awards = Awards.compute(from: [misfire, timeout, stat(mia, 1.5)])
        #expect(award(.bestEver, in: awards)?.playerID == mia)
    }

    @Test func deadEyeCountsDeadOns() throws {
        let awards = Awards.compute(from: [stat(mia, 0.01), stat(ben, 0.0), stat(ben, -0.03), stat(zoe, 0.2)])
        let deadEye = try #require(award(.deadEye, in: awards))
        #expect(deadEye.playerID == ben)
        #expect(deadEye.value == 2)
    }

    @Test func noDeadEyeWithoutADeadOn() {
        let awards = Awards.compute(from: [stat(mia, 0.3), stat(ben, 0.6)])
        #expect(award(.deadEye, in: awards) == nil)
    }

    @Test func theImpatientOneIsMostlyTooEarly() throws {
        let turns = [stat(mia, -0.4), stat(mia, -1.1), stat(mia, 0.2), stat(ben, 0.5), stat(ben, -0.1), stat(ben, 0.3)]
        let awards = Awards.compute(from: turns)
        let impatient = try #require(award(.impatient, in: awards))
        #expect(impatient.playerID == mia)
        #expect(abs(impatient.value - 2.0 / 3.0) < 1e-9)
        #expect(award(.dawdler, in: awards)?.playerID == ben)
    }

    @Test func tendenciesNeedEnoughTurns() {
        let awards = Awards.compute(from: [stat(mia, -0.4), stat(mia, -1.1)])
        #expect(award(.impatient, in: awards) == nil)
    }

    @Test func tendenciesNeedAClearMajority() {
        // 50 % early is not "always too early".
        let awards = Awards.compute(from: [stat(mia, -0.4), stat(mia, 0.4), stat(mia, -0.2), stat(mia, 0.2)])
        #expect(award(.impatient, in: awards) == nil)
        #expect(award(.dawdler, in: awards) == nil)
    }

    @Test func hairTriggerNeedsTwoMisfires() throws {
        let one = Awards.compute(from: [TurnStat(playerID: mia, deviation: -9.5, outcome: .misfire)])
        #expect(award(.hairTrigger, in: one) == nil)

        let misfires = (0..<2).map { _ in TurnStat(playerID: zoe, deviation: -9.5, outcome: .misfire) }
        let two = Awards.compute(from: misfires + [stat(mia, 0.1)])
        let hairTrigger = try #require(award(.hairTrigger, in: two))
        #expect(hairTrigger.playerID == zoe)
        #expect(hairTrigger.value == 2)
    }

    @Test func tiesGoToTheFirstPlayer() {
        let awards = Awards.compute(from: [stat(ben, 0.0), stat(mia, 0.0)])
        #expect(award(.deadEye, in: awards)?.playerID == ben)
        #expect(award(.bestEver, in: awards)?.playerID == ben)
    }

    @Test func awardsComeInAFixedOrder() {
        let turns = [stat(mia, 0.0), stat(mia, -0.5), stat(mia, -0.7)]
            + (0..<2).map { _ in TurnStat(playerID: ben, deviation: -9.5, outcome: .misfire) }
        let kinds = Awards.compute(from: turns).map(\.kind)
        #expect(kinds == [.bestEver, .deadEye, .impatient, .hairTrigger])
    }
}

struct PartyPackTests {
    @Test func freeModesArePlayableWithoutThePack() {
        for kind in ModeKind.allCases {
            #expect(PartyPack.canPlay(kind, unlocked: false) == kind.isFree)
            #expect(PartyPack.canPlay(kind, unlocked: true))
        }
    }

    @Test func playerLimit() {
        #expect(PartyPack.maxPlayers(unlocked: false) == 10)
        #expect(PartyPack.maxPlayers(unlocked: true) > 10)
    }

    @Test func customHouseRulesNeedThePack() {
        #expect(!PartyPack.canAddCustomHouseRules(unlocked: false))
        #expect(PartyPack.canAddCustomHouseRules(unlocked: true))
    }

    @Test func pickerDoesNotRepeatUntilExhausted() {
        var picker = NoRepeatPicker()
        var generator = SplitMix64(seed: 12)
        let options = ["a", "b", "c", "d"]
        var drawn: [String] = []
        for _ in options {
            if let pick = picker.draw(from: options, using: &generator) { drawn.append(pick) }
        }
        #expect(Set(drawn) == Set(options))
        let next = picker.draw(from: options, using: &generator)
        #expect(next.map { options.contains($0) } == true)
        #expect(picker.draw(from: [], using: &generator) == nil)
    }

    @Test func pickerFollowsChangedOptions() {
        var picker = NoRepeatPicker()
        var generator = SplitMix64(seed: 1)
        _ = picker.draw(from: ["a"], using: &generator)
        let fresh = picker.draw(from: ["a", "b"], using: &generator)
        #expect(fresh == "b")
    }

    @Test("Built-in house rules have English text", arguments: HouseRuleCatalog.defaultKeys)
    func builtInRulesAreInTheCatalog(key: String) {
        let text = HouseRuleCatalog.text(stored: key, isCustom: false)
        #expect(text != key)
        #expect(!text.localizedCaseInsensitiveContains("drink"))
    }

    @Test func customRulesShowTheirOwnText() {
        #expect(HouseRuleCatalog.text(stored: "Moonwalk", isCustom: true) == "Moonwalk")
    }

    @Test(arguments: [
        TurnOutcome.scored(.deadOn), .scored(.sharp), .scored(.close), .scored(.meh),
        .scored(.off), .scored(.lostInTime), .misfire, .timeout,
    ])
    func outcomeCodesRoundTrip(outcome: TurnOutcome) {
        #expect(TurnOutcome(code: outcome.code) == outcome)
    }

    @Test func unknownOutcomeCode() {
        #expect(TurnOutcome(code: "nope") == nil)
    }
}
