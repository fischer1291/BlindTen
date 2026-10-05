import Foundation
import Testing
@testable import BlindTen

struct ModeTests {
    let players = ["Mia", "Ben", "Zoe", "Ali", "Kim"].map { Player(name: $0, emoji: "🦊") }

    /// Plays the current single-player turn.
    private func play(_ engine: inout GameEngine, elapsed: TimeInterval) {
        engine.beginTurn()
        engine.start(at: 1_000)
        engine.stop(at: 1_000 + elapsed)
        engine.advance()
    }

    // MARK: - Catalog

    @Test func threeModesAreFree() {
        #expect(ModeKind.allCases.filter(\.isFree) == [.classic, .randomTarget, .showdown])
    }

    @Test("Every kind builds its own mode", arguments: ModeKind.allCases)
    func kindsBuildMatchingModes(kind: ModeKind) {
        #expect(kind.mode.kind == kind)
    }

    // MARK: - Random Target

    @Test func randomTargetsStayInRangeWithTwoDecimals() {
        var generator = SplitMix64(seed: 3)
        var targets: Set<TimeInterval> = []
        for _ in 0..<500 {
            let target = RandomTargetMode().makeTarget(using: &generator)
            #expect(RandomTargetMode.targetRange.contains(target))
            #expect(abs(target * 100 - (target * 100).rounded()) < 1e-6)
            targets.insert(target)
        }
        #expect(targets.count > 100)
    }

    @Test func randomTargetGivesEachTurnANewTarget() throws {
        var engine = try GameEngine(players: Array(players.prefix(3)), mode: RandomTargetMode(), seed: 11)
        var seen: [TimeInterval] = []
        for _ in 0..<3 {
            seen.append(engine.target)
            play(&engine, elapsed: engine.target)
        }
        #expect(Set(seen).count == 3)
        #expect(engine.results.map(\.outcome) == [TurnOutcome](repeating: .scored(.deadOn), count: 3))
    }

    @Test func randomTargetTimeoutScalesWithTheTarget() throws {
        var engine = try GameEngine(players: Array(players.prefix(2)), mode: RandomTargetMode(), seed: 5)
        let target = engine.target
        engine.beginTurn()
        engine.start(at: 0)
        #expect(engine.timeoutDeadline == target * 3)
    }

    // MARK: - Showdown

    @Test func showdownPairsTwoPlayersEveryRound() {
        let ids = players.prefix(2).map(\.id)
        for round in 1...3 {
            #expect(Showdown.pairings(round: round, players: ids) == [ids])
        }
    }

    @Test func showdownRotatesOpponentsAndEveryonePlaysWithEvenCounts() {
        let ids = players.prefix(4).map(\.id)
        var opponents: [Player.ID: Set<Player.ID>] = [:]
        for round in 1...3 {
            let duels = Showdown.pairings(round: round, players: ids)
            #expect(duels.count == 2)
            #expect(Set(duels.flatMap { $0 }) == Set(ids))
            for duel in duels {
                opponents[duel[0], default: []].insert(duel[1])
                opponents[duel[1], default: []].insert(duel[0])
            }
        }
        // Three rounds of four players: everyone met everyone once.
        for id in ids {
            #expect(opponents[id]?.count == 3)
        }
    }

    @Test func showdownGivesOneByePerRoundWithOddCounts() {
        let ids = players.prefix(3).map(\.id)
        var sittingOut: [Player.ID] = []
        for round in 1...3 {
            let duels = Showdown.pairings(round: round, players: ids)
            #expect(duels.count == 1)
            let playing = Set(duels.flatMap { $0 })
            sittingOut.append(contentsOf: ids.filter { !playing.contains($0) })
        }
        #expect(Set(sittingOut) == Set(ids))
    }

    @Test func showdownRunsTwoIndependentLanes() throws {
        var engine = try GameEngine(players: Array(players.prefix(2)), mode: ShowdownMode())
        #expect(engine.lanes.count == 2)
        #expect(engine.currentPlayers == Array(players.prefix(2)))

        engine.beginTurn()
        engine.start(lane: 1, at: 100)
        #expect(engine.phase == .running)
        engine.start(lane: 0, at: 100.4)
        engine.stop(lane: 1, at: 109.7)            // Ben: off by 0.30
        #expect(engine.phase == .running)
        let deadline = try #require(engine.timeoutDeadline)
        #expect(abs(deadline - 130.4) < 1e-9)
        engine.stop(lane: 0, at: 110.5)            // Mia: off by 0.10
        #expect(engine.phase == .reveal)

        let results = engine.revealedResults
        #expect(results.count == 2)
        #expect(Set(results.map(\.turnID)).count == 1)
        #expect(GameEngine.duelWinner(of: results) == players[0].id)
    }

    @Test func showdownRanksByDuelsWon() throws {
        var engine = try GameEngine(players: Array(players.prefix(2)), mode: ShowdownMode(), rounds: 3)
        // Mia wins one duel and scores more points (20 vs 15); Ben wins two duels.
        let plan: [(mia: TimeInterval, ben: TimeInterval)] = [(10.0, 12.0), (10.3, 10.2), (10.3, 9.85)]
        for (mia, ben) in plan {
            engine.beginTurn()
            engine.start(lane: 0, at: 0)
            engine.start(lane: 1, at: 0)
            engine.stop(lane: 0, at: mia)
            engine.stop(lane: 1, at: ben)
            engine.advance()
            engine.advance()
        }
        #expect(engine.phase == .finished)
        let standings = engine.standings()
        #expect(standings.map(\.player.name) == ["Ben", "Mia"])
        #expect(standings.map(\.duelWins) == [2, 1])
        #expect(standings.map(\.points) == [15, 20])
    }

    @Test func duelTiedOnTheDisplayedDeviationHasNoWinner() {
        let a = TurnResult(id: UUID(), turnID: UUID(), playerID: UUID(), round: 1, target: 10, stopped: 10.271, outcome: .scored(.close))
        let b = TurnResult(id: UUID(), turnID: a.turnID, playerID: UUID(), round: 1, target: 10, stopped: 9.732, outcome: .scored(.close))
        #expect(GameEngine.duelWinner(of: [a, b]) == nil)
    }

    @Test func scoredTurnBeatsAMisfireEvenIfFurtherOff() {
        // Random Target 4 s: a misfire at 0.99 s is 3.01 off, a stop at 7.20 s is 3.20 off.
        let misfire = TurnResult(id: UUID(), turnID: UUID(), playerID: UUID(), round: 1, target: 4, stopped: 0.99, outcome: .misfire)
        let scored = TurnResult(id: UUID(), turnID: misfire.turnID, playerID: UUID(), round: 1, target: 4, stopped: 7.2, outcome: .scored(.lostInTime))
        #expect(GameEngine.duelWinner(of: [misfire, scored]) == scored.playerID)
        #expect(GameEngine.duelWinner(of: [scored, misfire]) == scored.playerID)
    }

    @Test func duelTiesHaveNoWinner() {
        let a = TurnResult(id: UUID(), turnID: UUID(), playerID: UUID(), round: 1, target: 10, stopped: 10.5, outcome: .scored(.close))
        let b = TurnResult(id: UUID(), turnID: a.turnID, playerID: UUID(), round: 1, target: 10, stopped: 9.5, outcome: .scored(.close))
        #expect(GameEngine.duelWinner(of: [a, b]) == nil)
    }

    @Test func voidingAShowdownDropsTheFinishedLaneToo() throws {
        var engine = try GameEngine(players: Array(players.prefix(2)), mode: ShowdownMode())
        engine.beginTurn()
        engine.start(lane: 0, at: 0)
        engine.start(lane: 1, at: 0)
        engine.stop(lane: 0, at: 10)
        #expect(engine.results.count == 1)
        engine.voidTurn()
        #expect(engine.results.isEmpty)
        #expect(engine.lanes.allSatisfy { $0.startedAt == nil && $0.result == nil })
        #expect(engine.phase == .handoff)
    }

    // MARK: - Distraction

    @Test(arguments: [1, 2, 3, 4, 5] as [UInt64])
    func distractionBeepsAreIrregular(seed: UInt64) {
        var generator = SplitMix64(seed: seed)
        let end: TimeInterval = 30
        let times = Distraction.beepTimes(until: end, using: &generator)
        #expect(!times.isEmpty)
        #expect(times == times.sorted())
        #expect(times.allSatisfy { $0 > 0 && $0 < end })

        let gaps = zip([0] + times, times).map { $1 - $0 }
        for gap in gaps {
            #expect(Distraction.gapRange.contains(gap))
            #expect(!Distraction.forbiddenGaps.contains(gap))
        }
        for (previous, next) in zip(gaps, gaps.dropFirst()) {
            #expect(abs(previous - next) >= Distraction.minimumGapChange - 1e-9)
        }
    }

    @Test func distractionEffectCoversTheWholeTurn() throws {
        let engine = try GameEngine(players: Array(players.prefix(2)), mode: DistractionMode(), seed: 9)
        guard case .distraction(let times) = engine.blindEffect else {
            Issue.record("Expected a distraction effect")
            return
        }
        #expect(times.allSatisfy { $0 < Scoring.timeoutDuration(for: engine.target) })
    }

    // MARK: - Liar's Clock

    @Test func liarsClockIsAlwaysTenToThirtyPercentOff() {
        var generator = SplitMix64(seed: 21)
        var sawFast = false
        var sawSlow = false
        for _ in 0..<400 {
            let rate = LiarsClock.randomRate(using: &generator)
            let offBy = abs(rate - 1)
            #expect(offBy >= 0.1 - 1e-9 && offBy <= 0.3 + 1e-9)
            sawFast = sawFast || rate > 1
            sawSlow = sawSlow || rate < 1
        }
        #expect(sawFast && sawSlow)
    }

    @Test func liarsClockCountdownLiesAndStopsAtZero() {
        #expect(LiarsClock.displayedRemaining(elapsed: 0, target: 10, rate: 1.2) == 10)
        #expect(abs(LiarsClock.displayedRemaining(elapsed: 5, target: 10, rate: 1.2) - 4) < 1e-9)
        #expect(abs(LiarsClock.displayedRemaining(elapsed: 5, target: 10, rate: 0.8) - 6) < 1e-9)
        #expect(LiarsClock.displayedRemaining(elapsed: 20, target: 10, rate: 1.2) == 0)
        #expect(LiarsClock.displayedRemaining(elapsed: -1, target: 10, rate: 1.2) == 10)
    }

    @Test func liarsClockTempoChangesBetweenTurns() throws {
        var engine = try GameEngine(players: Array(players.prefix(3)), mode: LiarsClockMode(), seed: 4)
        var rates: [Double] = []
        for _ in 0..<3 {
            if case .liarsClock(let rate) = engine.blindEffect { rates.append(rate) }
            play(&engine, elapsed: 10)
        }
        #expect(rates.count == 3)
        #expect(Set(rates).count == 3)
    }

    // MARK: - Heartbeat

    @Test func heartbeatIsNeverOneSecond() {
        var generator = SplitMix64(seed: 8)
        var sawFast = false
        var sawSlow = false
        for _ in 0..<400 {
            let interval = Heartbeat.randomInterval(using: &generator)
            #expect(Heartbeat.fastIntervals.contains(interval) || Heartbeat.slowIntervals.contains(interval))
            #expect(abs(interval - 1) >= 0.08 - 1e-9)
            sawFast = sawFast || interval < 1
            sawSlow = sawSlow || interval > 1
        }
        #expect(sawFast && sawSlow)
    }

    @Test func heartbeatEffectIsSetPerTurn() throws {
        let engine = try GameEngine(players: Array(players.prefix(2)), mode: HeartbeatMode(), seed: 2)
        guard case .heartbeat(let interval) = engine.blindEffect else {
            Issue.record("Expected a heartbeat effect")
            return
        }
        #expect(interval != 1)
    }

    // MARK: - Elimination

    @Test func eliminationRunsUntilOneIsLeft() throws {
        let four = Array(players.prefix(4))
        var engine = try GameEngine(players: four, mode: EliminationMode(), rounds: 3)
        #expect(engine.rounds == 3)

        // Round 1: Zoe worst. Round 2: Mia worst. Round 3: Ben vs Ali, Ali worst.
        let plan: [[String: TimeInterval]] = [
            ["Mia": 10.3, "Ben": 10.0, "Zoe": 14, "Ali": 10.1],
            ["Mia": 13, "Ben": 10.2, "Ali": 10.4],
            ["Ben": 10.0, "Ali": 11.5],
        ]
        for (index, times) in plan.enumerated() {
            let scheduled = Set(engine.schedule.flatMap { $0 })
            let expected = Set(four.filter { times[$0.name] != nil }.map(\.id))
            #expect(scheduled == expected)
            while engine.phase != .roundResults {
                let name = try #require(engine.currentPlayer?.name)
                let elapsed = try #require(times[name])
                play(&engine, elapsed: elapsed)
            }
            #expect(engine.eliminated.count == index + 1)
            engine.advance()
        }

        #expect(engine.phase == .finished)
        #expect(engine.activePlayers.map(\.name) == ["Ben"])
        #expect(engine.winner?.name == "Ben")
        #expect(engine.eliminated.compactMap { engine.player(withID: $0)?.name } == ["Zoe", "Mia", "Ali"])
        // Survivor first, then by how long each lasted.
        #expect(engine.standings().map(\.player.name) == ["Ben", "Ali", "Mia", "Zoe"])
        #expect(engine.standings().map(\.eliminatedInRound) == [nil, 3, 2, 1])
    }

    @Test func eliminationIgnoresTheRoundSetting() throws {
        let engine = try GameEngine(players: Array(players.prefix(5)), mode: EliminationMode(), rounds: 1)
        #expect(engine.rounds == 4)
    }

    // MARK: - Teams

    @Test func teamsAlternateByRosterOrder() {
        #expect((0..<5).map(Teams.team(forPlayerAt:)) == [0, 1, 0, 1, 0])
    }

    @Test func teamsAreRankedByCombinedDeviation() throws {
        let four = Array(players.prefix(4))      // Team 0: Mia, Zoe. Team 1: Ben, Ali.
        var engine = try GameEngine(players: four, mode: TeamsMode(), rounds: 1)
        for elapsed in [10.5, 10.1, 10.3, 10.0] {   // Mia, Ben, Zoe, Ali
            play(&engine, elapsed: elapsed)
        }
        engine.advance()
        #expect(engine.phase == .finished)

        let teams = engine.teamStandings()
        #expect(teams.map(\.team) == [1, 0])
        #expect(abs(teams[0].totalDeviation - 0.1) < 1e-6)
        #expect(abs(teams[1].totalDeviation - 0.8) < 1e-6)
        #expect(teams[0].members.map(\.name) == ["Ben", "Ali"])
        #expect(engine.winningTeam == 1)
        #expect(engine.standings().first?.team == 1)
    }

    @Test func unevenTeamsCompareAveragePerTurn() throws {
        let three = Array(players.prefix(3))     // Team 0: Mia, Zoe. Team 1: Ben.
        var engine = try GameEngine(players: three, mode: TeamsMode(), rounds: 1)
        for elapsed in [10.2, 10.3, 10.2] {        // Mia 0.2, Ben 0.3, Zoe 0.2
            play(&engine, elapsed: elapsed)
        }
        engine.advance()
        // Team 0 has the larger sum (0.4 vs 0.3) but the better average (0.2 vs 0.3).
        #expect(engine.winningTeam == 0)
    }

    @Test func nonTeamModesHaveNoTeams() throws {
        let engine = try GameEngine(players: Array(players.prefix(2)))
        #expect(engine.teamStandings().isEmpty)
        #expect(engine.standings().allSatisfy { $0.team == nil })
    }
}
