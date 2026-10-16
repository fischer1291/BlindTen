import Foundation
import Testing
@testable import BlindTen

struct DuelTests {
    /// Plays a round for a player: begin, then stop at target + offset.
    private func play(_ duel: inout DuelState, player: Int, offset: TimeInterval) throws {
        let round = try #require(duel.nextRound(for: player))
        try duel.begin(round: round, player: player)
        try duel.record(stopped: duel.target(round: round) + offset, round: round, player: player)
    }

    @Test func turnOrderKeepsHandoffsFew() throws {
        var duel = DuelState(kind: .classic, seed: 1)
        #expect(duel.nextRound(for: 0) == 0)
        try play(&duel, player: 0, offset: 0.1)
        // A must wait for B's round 1.
        #expect(duel.nextRound(for: 0) == nil)
        #expect(duel.nextRound(for: 1) == 0)
        try play(&duel, player: 1, offset: 0.2)
        #expect(duel.nextRound(for: 1) == 1)
        try play(&duel, player: 1, offset: 0.3)
        #expect(duel.nextRound(for: 1) == nil)
        #expect(duel.nextRound(for: 0) == 1)
        try play(&duel, player: 0, offset: 0.4)
        #expect(duel.nextRound(for: 0) == 2)
    }

    @Test func playingOutOfTurnIsRejected() {
        #expect(throws: DuelState.DuelError.notYourRound) {
            var duel = DuelState(kind: .classic, seed: 1)
            try duel.begin(round: 1, player: 0)
        }
        #expect(throws: DuelState.DuelError.notYourRound) {
            var duel = DuelState(kind: .classic, seed: 1)
            try duel.record(stopped: 10, round: 0, player: 0)
        }
    }

    @Test func closerStopWinsTheRound() throws {
        var duel = DuelState(kind: .classic, seed: 1)
        try play(&duel, player: 0, offset: -0.12)
        #expect(duel.result(round: 0) == nil)
        try play(&duel, player: 1, offset: 0.30)
        #expect(duel.result(round: 0) == .won(by: 0))
    }

    @Test func aScoredTurnBeatsAMisfireAndTwoMissesTie() throws {
        var duel = DuelState(kind: .classic, seed: 1)
        try play(&duel, player: 0, offset: 1.9)
        try play(&duel, player: 1, offset: -9.5)
        #expect(duel.result(round: 0) == .won(by: 0))

        var both = DuelState(kind: .classic, seed: 1)
        try play(&both, player: 0, offset: -9.5)
        try play(&both, player: 1, offset: 25)
        #expect(both.result(round: 0) == .tie)
    }

    @Test func twoRoundWinsEndTheDuelEarly() throws {
        var duel = DuelState(kind: .classic, seed: 1)
        try play(&duel, player: 0, offset: 0.05)
        try play(&duel, player: 1, offset: 0.5)
        try play(&duel, player: 1, offset: 0.5)
        #expect(duel.outcome == nil)
        try play(&duel, player: 0, offset: 0.05)
        #expect(duel.outcome == .won(by: 0))
        #expect(duel.wins == [2, 0])
        #expect(duel.nextRound(for: 0) == nil)
        #expect(duel.nextRound(for: 1) == nil)
    }

    @Test func fullDuelCanEndInADraw() throws {
        var duel = DuelState(kind: .classic, seed: 1)
        try play(&duel, player: 0, offset: 0.1)   // R1: A wins
        try play(&duel, player: 1, offset: 0.2)
        try play(&duel, player: 1, offset: 0.1)   // R2: B wins
        try play(&duel, player: 0, offset: 0.2)
        try play(&duel, player: 0, offset: 0.3)   // R3: tie
        #expect(duel.outcome == nil)
        try play(&duel, player: 1, offset: -0.3)
        #expect(duel.result(round: 2) == .tie)
        #expect(duel.outcome == .draw)
    }

    @Test func unfinishedTurnCountsAsTimeout() throws {
        var duel = DuelState(kind: .classic, seed: 1)
        try duel.begin(round: 0, player: 0)
        // The app was killed: the round stays played, as a timeout.
        #expect(duel.nextRound(for: 0) == nil)
        try play(&duel, player: 1, offset: 1.5)
        #expect(duel.result(round: 0) == .won(by: 1))
    }

    @Test func opponentResultIsHiddenUntilYouPlayedTheRound() throws {
        var duel = DuelState(kind: .classic, seed: 1)
        try play(&duel, player: 0, offset: 0.1)
        #expect(!duel.isVisible(player: 0, round: 0, to: 1))
        #expect(duel.isVisible(player: 0, round: 0, to: 0))
        try play(&duel, player: 1, offset: 0.2)
        #expect(duel.isVisible(player: 0, round: 0, to: 1))
    }

    @Test func randomTargetsAreSharedAndStable() {
        let a = DuelState(kind: .randomTarget, seed: 7)
        let b = DuelState(kind: .randomTarget, seed: 7)
        let targets = (0..<DuelState.rounds).map { a.target(round: $0) }
        #expect(targets == (0..<DuelState.rounds).map { b.target(round: $0) })
        #expect(targets.allSatisfy { RandomTargetMode.targetRange.contains($0) })
        #expect(Set(targets).count > 1)
    }

    @Test func roundTripsAsMatchData() throws {
        var duel = DuelState(kind: .randomTarget, seed: 3)
        try play(&duel, player: 0, offset: 0.2)
        let decoded = DuelState.decode(duel.encoded())
        #expect(decoded == duel)
        #expect(DuelState.decode(Data()) == nil)
        #expect(DuelState.decode(nil) == nil)
    }
}
