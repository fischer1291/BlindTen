import Foundation
import Testing
@testable import BlindTen

struct GameEngineTests {
    let mia = Player(name: "Mia", emoji: "🦊")
    let ben = Player(name: "Ben", emoji: "🐸")
    let zoe = Player(name: "Zoe", emoji: "🐙")

    /// Plays the current single-player turn: tap, START at `startAt`, STOP after `elapsed`.
    @discardableResult
    private func play(_ engine: inout GameEngine, elapsed: TimeInterval, startAt: TimeInterval = 1_000) -> TurnResult? {
        engine.beginTurn()
        engine.start(at: startAt)
        return engine.stop(at: startAt + elapsed)
    }

    // MARK: - Setup

    @Test func needsAtLeastTwoPlayers() {
        #expect(throws: GameEngine.SetupError.notEnoughPlayers) {
            try GameEngine(players: [mia])
        }
        #expect(throws: GameEngine.SetupError.notEnoughPlayers) {
            try GameEngine(players: [])
        }
    }

    @Test func needsAtLeastOneRound() {
        #expect(throws: GameEngine.SetupError.invalidRoundCount) {
            try GameEngine(players: [mia, ben], rounds: 0)
        }
    }

    @Test func classicDefaults() throws {
        let engine = try GameEngine(players: [mia, ben])
        #expect(engine.mode.kind == .classic)
        #expect(engine.rounds == 3)
        #expect(engine.target == 10)
        #expect(engine.blindEffect == .dark)
        #expect(engine.round == 1)
        #expect(engine.phase == .handoff)
        #expect(engine.currentPlayer == mia)
        #expect(engine.lanes.count == 1)
        #expect(engine.results.isEmpty)
    }

    // MARK: - Turn flow

    @Test func singleTurnGoesThroughAllPhases() throws {
        var engine = try GameEngine(players: [mia, ben])
        engine.beginTurn()
        #expect(engine.phase == .ready)
        engine.start(at: 500)
        #expect(engine.phase == .running)
        #expect(engine.lanes[0].startedAt == 500)
        #expect(engine.timeoutDeadline == 530)

        let resultValue = engine.stop(at: 510.27)
        let result = try #require(resultValue)
        #expect(engine.phase == .reveal)
        #expect(engine.revealedResults == [result])
        #expect(result.playerID == mia.id)
        #expect(result.round == 1)
        #expect(abs(result.stopped - 10.27) < 1e-9)
        #expect(result.outcome == .scored(.close))
        #expect(result.points == 5)
        #expect(result.displayedDeviation == 0.27)
        #expect(engine.timeoutDeadline == nil)
    }

    @Test func actionsOutOfOrderAreIgnored() throws {
        var engine = try GameEngine(players: [mia, ben])
        engine.start(at: 1)
        #expect(engine.phase == .handoff)
        let noResult1 = engine.stop(at: 2)
        #expect(noResult1 == nil)
        engine.advance()
        #expect(engine.phase == .handoff)

        engine.beginTurn()
        engine.beginTurn()
        #expect(engine.phase == .ready)
        let noResult2 = engine.stop(at: 2)
        #expect(noResult2 == nil)

        engine.start(at: 100)
        engine.start(at: 105)
        #expect(engine.lanes[0].startedAt == 100)
        engine.stop(at: 110)
        let noResult3 = engine.stop(at: 111)
        #expect(noResult3 == nil)
        engine.start(lane: 5, at: 1)
        #expect(engine.results.count == 1)
    }

    @Test func fullGameFlow() throws {
        var engine = try GameEngine(players: [mia, ben], rounds: 2)

        play(&engine, elapsed: 10.02)   // Mia: DEAD ON, 10
        #expect(engine.currentPlayer == mia)
        engine.advance()
        #expect(engine.phase == .handoff)
        #expect(engine.currentPlayer == ben)

        play(&engine, elapsed: 11.5)    // Ben: Off, 1
        engine.advance()
        #expect(engine.phase == .roundResults)
        #expect(engine.currentPlayer == nil)
        #expect(engine.roundLoser(1) == ben)
        #expect(!engine.isFinalRound)
        #expect(engine.winner == nil)

        engine.advance()
        #expect(engine.round == 2)
        #expect(engine.phase == .handoff)
        #expect(engine.currentPlayer == mia)

        play(&engine, elapsed: 9.8)     // Mia: Sharp, 7
        engine.advance()
        play(&engine, elapsed: 10.0)    // Ben: DEAD ON, 10
        engine.advance()
        #expect(engine.phase == .roundResults)
        #expect(engine.isFinalRound)
        #expect(engine.roundLoser(2) == mia)

        engine.advance()
        #expect(engine.phase == .finished)
        #expect(engine.winner == mia)

        let standings = engine.standings()
        #expect(standings.map(\.player) == [mia, ben])
        #expect(standings.map(\.points) == [17, 11])

        engine.advance()
        #expect(engine.phase == .finished)
    }

    // MARK: - Edge cases

    @Test func stoppingBeforeOneSecondIsAMisfire() throws {
        var engine = try GameEngine(players: [mia, ben])
        let resultValue = play(&engine, elapsed: 0.4)
        let result = try #require(resultValue)
        #expect(result.outcome == .misfire)
        #expect(result.points == 0)
        #expect(abs(result.stopped - 0.4) < 1e-9)
    }

    @Test func noStopAfterThreeTimesTargetAutoStops() throws {
        var engine = try GameEngine(players: [mia, ben])
        engine.beginTurn()
        engine.start(at: 100)

        let early = engine.autoStopIfOverdue(now: 129.99)
        #expect(early.isEmpty)
        #expect(engine.phase == .running)

        let stopped = engine.autoStopIfOverdue(now: 130)
        let result = try #require(stopped.first)
        #expect(stopped.count == 1)
        #expect(result.outcome == .timeout)
        #expect(result.points == 0)
        #expect(result.stopped == 30)
        #expect(engine.phase == .reveal)
        let again = engine.autoStopIfOverdue(now: 200)
        #expect(again.isEmpty)
    }

    @Test func aLateTapAfterTheDeadlineCountsAsTimeout() throws {
        var engine = try GameEngine(players: [mia, ben])
        let resultValue = play(&engine, elapsed: 45)
        let result = try #require(resultValue)
        #expect(result.outcome == .timeout)
        #expect(result.stopped == 30)
    }

    @Test func autoStopDoesNothingWhenNotRunning() throws {
        var engine = try GameEngine(players: [mia, ben])
        let before = engine.autoStopIfOverdue(now: 1e9)
        #expect(before.isEmpty)
        engine.beginTurn()
        let ready = engine.autoStopIfOverdue(now: 1e9)
        #expect(ready.isEmpty)
        #expect(engine.phase == .ready)
    }

    @Test func voidingARunningTurnReplaysItForTheSamePlayer() throws {
        var engine = try GameEngine(players: [mia, ben])
        engine.beginTurn()
        engine.start(at: 10)
        engine.voidTurn()
        #expect(engine.phase == .handoff)
        #expect(engine.currentPlayer == mia)
        #expect(engine.lanes[0].startedAt == nil)
        #expect(engine.results.isEmpty)

        engine.beginTurn()
        engine.voidTurn()
        #expect(engine.phase == .handoff)
    }

    @Test func voidingDoesNotTouchFinishedTurns() throws {
        var engine = try GameEngine(players: [mia, ben])
        play(&engine, elapsed: 10)
        engine.voidTurn()
        #expect(engine.phase == .reveal)
        #expect(engine.results.count == 1)
    }

    @Test func replayDiscardsTheRevealedResult() throws {
        var engine = try GameEngine(players: [mia, ben])
        play(&engine, elapsed: 14)
        engine.replayTurn()
        #expect(engine.phase == .handoff)
        #expect(engine.currentPlayer == mia)
        #expect(engine.results.isEmpty)

        let replayedValue = play(&engine, elapsed: 10)
        let replayed = try #require(replayedValue)
        #expect(replayed.playerID == mia.id)
        #expect(engine.results == [replayed])
    }

    // MARK: - Leaderboards

    @Test func equalPointsAreBrokenByTotalDeviation() throws {
        var engine = try GameEngine(players: [mia, ben, zoe], rounds: 1)
        play(&engine, elapsed: 10.20)   // Mia: Sharp 7, off by 0.20
        engine.advance()
        play(&engine, elapsed: 9.90)    // Ben: Sharp 7, off by 0.10
        engine.advance()
        play(&engine, elapsed: 13)      // Zoe: Lost in time 0
        engine.advance()

        #expect(engine.standings().map(\.player) == [ben, mia, zoe])
        #expect(engine.roundLoser(1) == zoe)
    }

    @Test func fullTiesKeepPlayerOrder() throws {
        var engine = try GameEngine(players: [mia, ben], rounds: 1)
        play(&engine, elapsed: 10.1)
        engine.advance()
        play(&engine, elapsed: 10.1)
        engine.advance()
        #expect(engine.standings().map(\.player) == [mia, ben])
    }

    @Test func roundStandingsOnlyCountThatRound() throws {
        var engine = try GameEngine(players: [mia, ben], rounds: 2)
        play(&engine, elapsed: 10); engine.advance()      // Mia 10
        play(&engine, elapsed: 12.5); engine.advance()    // Ben 0
        engine.advance()
        play(&engine, elapsed: 13); engine.advance()      // Mia 0
        play(&engine, elapsed: 10.3); engine.advance()    // Ben 5

        #expect(engine.standings(round: 2).map(\.player) == [ben, mia])
        #expect(engine.standings(round: 2).map(\.points) == [5, 0])
        #expect(engine.standings().map(\.points) == [10, 5])
    }

    @Test func roundLoserNeedsACompleteRound() throws {
        var engine = try GameEngine(players: [mia, ben])
        play(&engine, elapsed: 10)
        #expect(engine.roundLoser(1) == nil)
    }

    @Test func misfiresAndTimeoutsCountTheirRealDeviation() throws {
        var engine = try GameEngine(players: [mia, ben], rounds: 1)
        play(&engine, elapsed: 0.5); engine.advance()     // misfire, off by 9.5
        play(&engine, elapsed: 40); engine.advance()      // timeout, off by 20
        let standings = engine.standings()
        #expect(standings.map(\.player) == [mia, ben])
        #expect(abs(standings[0].totalDeviation - 9.5) < 1e-9)
        #expect(abs(standings[1].totalDeviation - 20) < 1e-9)
    }

    @Test func restartKeepsPlayersAndClearsResults() throws {
        var engine = try GameEngine(players: [mia, ben], rounds: 1)
        play(&engine, elapsed: 10); engine.advance()
        play(&engine, elapsed: 10); engine.advance()
        engine.advance()
        #expect(engine.phase == .finished)

        engine.restart()
        #expect(engine.phase == .handoff)
        #expect(engine.round == 1)
        #expect(engine.currentPlayer == mia)
        #expect(engine.results.isEmpty)
        #expect(engine.players == [mia, ben])
    }

    // MARK: - Avatars

    @Test func avatarsAreUniqueUntilThePoolRunsOut() {
        var used: [String] = []
        for _ in Avatar.pool {
            used.append(Avatar.next(excluding: used))
        }
        #expect(Set(used).count == Avatar.pool.count)
        #expect(Avatar.pool.contains(Avatar.next(excluding: used)))
    }
}
