import Foundation
import Testing
@testable import BlindTen

struct SessionProtocolTests {
    let mia = Player(name: "Mia", emoji: "🦊")

    @Test func clientMessagesRoundTrip() throws {
        let messages: [ClientMessage] = [
            .hello(player: mia, protocolVersion: SessionProtocol.version),
            .ready,
            .started,
            .stopped(elapsed: 9.87),
            .voided,
        ]
        for message in messages {
            let data = try #require(SessionCoding.encode(message))
            #expect(SessionCoding.decode(ClientMessage.self, from: data) == message)
        }
    }

    @Test func snapshotRoundTrips() throws {
        var engine = try GameEngine(players: [mia, Player(name: "Ben", emoji: "🐸")], mode: DistractionMode(), seed: 7)
        var logic = SessionHostLogic()
        _ = logic.join(mia, protocolVersion: SessionProtocol.version, gameInProgress: false, maxPlayers: 10)
        logic.apply(.ready, from: mia.id, to: &engine, now: 100)
        let snapshot = logic.snapshot(engine: engine, hostName: "🦊🐙", mode: .distraction, revision: 3, revealLanded: false) { _ in nil }
        let message = HostMessage.snapshot(snapshot)
        let data = try #require(SessionCoding.encode(message))
        #expect(SessionCoding.decode(HostMessage.self, from: data) == message)
        #expect(SessionCoding.decode(HostMessage.self, from: Data("nonsense".utf8)) == nil)
    }
}

struct SessionHostLogicTests {
    let mia = Player(name: "Mia", emoji: "🦊")
    let ben = Player(name: "Ben", emoji: "🐸")
    let zoe = Player(name: "Zoe", emoji: "🐙")
    let version = SessionProtocol.version

    private func lobby(_ players: [Player]) -> SessionHostLogic {
        var logic = SessionHostLogic()
        for player in players {
            _ = logic.join(player, protocolVersion: version, gameInProgress: false, maxPlayers: 10)
        }
        return logic
    }

    // MARK: - Roster

    @Test func playersJoinTheLobby() {
        var logic = SessionHostLogic()
        let joined1 = logic.join(mia, protocolVersion: version, gameInProgress: false, maxPlayers: 10)
        #expect(joined1 == .joined)
        let joined2 = logic.join(ben, protocolVersion: version, gameInProgress: false, maxPlayers: 10)
        #expect(joined2 == .joined)
        #expect(logic.connectedPlayers == [mia, ben])
    }

    @Test func lobbyCanBeFull() {
        var logic = lobby([mia, ben])
        let joined3 = logic.join(zoe, protocolVersion: version, gameInProgress: false, maxPlayers: 2)
        #expect(joined3 == .rejected(.full))
    }

    @Test func wrongVersionIsRejected() {
        var logic = SessionHostLogic()
        let joined4 = logic.join(mia, protocolVersion: version + 1, gameInProgress: false, maxPlayers: 10)
        #expect(joined4 == .rejected(.incompatibleVersion))
        #expect(logic.players.isEmpty)
    }

    @Test func newPlayersCannotJoinAGameInProgress() {
        var logic = lobby([mia, ben])
        let joined5 = logic.join(zoe, protocolVersion: version, gameInProgress: true, maxPlayers: 10)
        #expect(joined5 == .rejected(.gameInProgress))
    }

    @Test func leavingTheLobbyRemovesThePlayer() {
        var logic = lobby([mia, ben])
        logic.disconnect(mia.id, gameInProgress: false)
        #expect(logic.players == [ben])
    }

    @Test func droppingOutMidGameKeepsTheSeat() {
        var logic = lobby([mia, ben])
        logic.disconnect(mia.id, gameInProgress: true)
        #expect(logic.players == [mia, ben])
        #expect(logic.connectedPlayers == [ben])
        let joined6 = logic.join(mia, protocolVersion: version, gameInProgress: true, maxPlayers: 10)
        #expect(joined6 == .rejoined)
        #expect(logic.connectedPlayers == [mia, ben])
    }

    @Test func backInTheLobbyTheMissingAreDropped() {
        var logic = lobby([mia, ben])
        logic.disconnect(mia.id, gameInProgress: true)
        logic.dropDisconnected()
        #expect(logic.players == [ben])
    }

    // MARK: - Turns

    @Test func playerPlaysATurnFromTheirPhone() throws {
        var logic = lobby([mia, ben])
        var engine = try GameEngine(players: [mia, ben])
        logic.apply(.ready, from: mia.id, to: &engine, now: 100)
        #expect(engine.phase == .ready)
        logic.apply(.started, from: mia.id, to: &engine, now: 100.2)
        #expect(engine.phase == .running)
        // Elapsed time comes from the phone, so network delay does not count.
        let stopped = logic.apply(.stopped(elapsed: 10.03), from: mia.id, to: &engine, now: 111)
        let result = try #require(stopped)
        #expect(abs(result.stopped - 10.03) < 0.000_1)
        #expect(result.outcome == .scored(.deadOn))
        #expect(engine.phase == .reveal)
    }

    @Test func eventsFromSomeoneElseAreIgnored() throws {
        var logic = lobby([mia, ben])
        var engine = try GameEngine(players: [mia, ben])
        logic.apply(.ready, from: ben.id, to: &engine, now: 100)
        #expect(engine.phase == .handoff)
    }

    @Test func showdownWaitsForBothPlayersToBeReady() throws {
        var logic = lobby([mia, ben])
        var engine = try GameEngine(players: [mia, ben], mode: ShowdownMode())
        logic.apply(.ready, from: mia.id, to: &engine, now: 100)
        #expect(engine.phase == .handoff)
        let waiting = logic.snapshot(engine: engine, hostName: "", mode: .showdown, revision: 1, revealLanded: false) { _ in nil }
        #expect(waiting.readyPlayerIDs == [mia.id])
        logic.apply(.ready, from: ben.id, to: &engine, now: 101)
        #expect(engine.phase == .ready)
    }

    @Test func voidReplaysTheTurnAndCountsTheAttempt() throws {
        var logic = lobby([mia, ben])
        var engine = try GameEngine(players: [mia, ben])
        logic.apply(.ready, from: mia.id, to: &engine, now: 100)
        logic.apply(.started, from: mia.id, to: &engine, now: 101)
        logic.apply(.voided, from: mia.id, to: &engine, now: 102)
        #expect(engine.phase == .handoff)
        #expect(logic.turnAttempt == 1)
        // A late void after the turn is over changes nothing.
        logic.apply(.voided, from: mia.id, to: &engine, now: 103)
        #expect(logic.turnAttempt == 1)
    }

    @Test func forfeitRecordsATimeout() throws {
        var logic = lobby([mia, ben])
        var engine = try GameEngine(players: [mia, ben])
        logic.disconnect(mia.id, gameInProgress: true)
        #expect(logic.missingTurnPlayers(in: engine) == [mia.id])
        let forfeited = logic.forfeit(mia.id, engine: &engine, now: 200)
        let result = try #require(forfeited)
        #expect(result.outcome == .timeout)
        #expect(engine.phase == .reveal)
        #expect(logic.missingTurnPlayers(in: engine).isEmpty)
    }

    // MARK: - Snapshot

    @Test func resultsStayHiddenUntilTheRevealLands() throws {
        var logic = lobby([mia, ben])
        var engine = try GameEngine(players: [mia, ben])
        logic.apply(.ready, from: mia.id, to: &engine, now: 100)
        logic.apply(.started, from: mia.id, to: &engine, now: 100)
        logic.apply(.stopped(elapsed: 9.8), from: mia.id, to: &engine, now: 110)
        let spinning = logic.snapshot(engine: engine, hostName: "", mode: .classic, revision: 1, revealLanded: false) { _ in nil }
        #expect(spinning.stage == .reveal)
        #expect(spinning.results.isEmpty)
        let landed = logic.snapshot(engine: engine, hostName: "", mode: .classic, revision: 2, revealLanded: true) { _ in "Nice" }
        let result = try #require(landed.results.first)
        #expect(result.playerID == mia.id)
        #expect(abs(result.deviation - -0.2) < 0.000_1)
        #expect(result.reaction == "Nice")
    }

    @Test func lobbySnapshotListsThePlayers() {
        var logic = lobby([mia, ben])
        logic.disconnect(ben.id, gameInProgress: true)
        let snapshot = logic.snapshot(engine: nil, hostName: "🦊🐙", mode: .teams, revision: 1, revealLanded: false) { _ in nil }
        #expect(snapshot.stage == .lobby)
        #expect(snapshot.mode == .teams)
        #expect(snapshot.players.map(\.isConnected) == [true, false])
    }
}

struct ClientTurnTests {
    let mia = Player(name: "Mia", emoji: "🦊")
    let ben = Player(name: "Ben", emoji: "🐸")

    private func snapshot(
        _ stage: SessionSnapshot.Stage,
        turn: [Player.ID],
        turnID: UUID? = UUID(),
        attempt: Int = 0,
        ready: [Player.ID] = [],
        finished: [Player.ID] = [],
        landed: Bool = false,
        results: [SessionResult] = []
    ) -> SessionSnapshot {
        SessionSnapshot(
            revision: 1, hostName: "", mode: .classic, stage: stage, round: 1, rounds: 3,
            players: [SessionPlayer(player: mia, isConnected: true), SessionPlayer(player: ben, isConnected: true)],
            turnID: turnID, turnAttempt: attempt, turnPlayerIDs: turn, target: 10, effect: .dark,
            readyPlayerIDs: ready, startedPlayerIDs: [], finishedPlayerIDs: finished,
            revealLanded: landed, results: results, standings: [], winnerID: nil, winningTeam: nil
        )
    }

    @Test func noSnapshotMeansConnecting() {
        #expect(ClientTurn().screen(for: nil, me: mia.id) == .connecting)
    }

    @Test func fullTurnOnThePhone() {
        var turn = ClientTurn()
        let id = UUID()
        let handoff = snapshot(.handoff, turn: [mia.id], turnID: id)
        turn.sync(with: handoff)
        #expect(turn.screen(for: handoff, me: mia.id) == .yourTurn)
        let firstReady = turn.markReady()
        let secondReady = turn.markReady()
        #expect(firstReady)
        #expect(!secondReady)

        let ready = snapshot(.ready, turn: [mia.id], turnID: id, ready: [mia.id])
        turn.sync(with: ready)
        #expect(turn.screen(for: ready, me: mia.id) == .start(target: 10))
        let firstStart = turn.start(at: 50)
        let secondStart = turn.start(at: 51)
        #expect(firstStart)
        #expect(!secondStart)
        #expect(turn.screen(for: ready, me: mia.id) == .blind(startedAt: 50))

        let elapsed = turn.stop(at: 59.9)
        #expect(elapsed.map { abs($0 - 9.9) < 0.000_1 } == true)
        let secondStop = turn.stop(at: 61)
        #expect(secondStop == nil)
        #expect(turn.screen(for: ready, me: mia.id) == .stopped)

        let spinning = snapshot(.reveal, turn: [mia.id], turnID: id)
        #expect(turn.screen(for: spinning, me: mia.id) == .drumroll)
        let result = SessionResult(playerID: mia.id, stopped: 9.9, deviation: -0.1, outcome: .scored(.sharp), points: 70, reaction: nil)
        let landed = snapshot(.reveal, turn: [mia.id], turnID: id, landed: true, results: [result])
        #expect(turn.screen(for: landed, me: mia.id) == .result(result))
    }

    @Test func othersWatchTheTurn() {
        let turn = ClientTurn()
        let handoff = snapshot(.handoff, turn: [mia.id])
        #expect(turn.screen(for: handoff, me: ben.id) == .watching(playerIDs: [mia.id]))
    }

    @Test func aNewTurnOrAReplayResetsThePhone() {
        var turn = ClientTurn()
        let id = UUID()
        let running = snapshot(.running, turn: [mia.id], turnID: id)
        turn.sync(with: running)
        _ = turn.markReady()
        _ = turn.start(at: 10)
        #expect(turn.isRunning)

        let replay = snapshot(.handoff, turn: [mia.id], turnID: id, attempt: 1)
        turn.sync(with: replay)
        #expect(!turn.isRunning)
        #expect(turn.screen(for: replay, me: mia.id) == .yourTurn)
    }

    @Test func showdownWaitsForTheOpponent() {
        var turn = ClientTurn()
        let handoff = snapshot(.handoff, turn: [mia.id, ben.id])
        turn.sync(with: handoff)
        _ = turn.markReady()
        #expect(turn.screen(for: handoff, me: mia.id) == .waitingForOpponent)
    }

    @Test func aForfeitedTurnShowsAsStopped() {
        let turn = ClientTurn()
        let running = snapshot(.running, turn: [mia.id, ben.id], finished: [mia.id])
        #expect(turn.screen(for: running, me: mia.id) == .stopped)
    }
}

struct HostPlaysTooTests {
    @Test func onlyTurnScreensTakeOverTheHostPhone() {
        let result = SessionResult(playerID: UUID(), stopped: 10, deviation: 0, outcome: .scored(.deadOn), points: 10, reaction: nil)
        let needsPlayer: [ClientTurn.Screen] = [.yourTurn, .waitingForOpponent, .start(target: 10), .blind(startedAt: 1)]
        let mainScreen: [ClientTurn.Screen] = [
            .connecting, .lobby, .stopped, .drumroll, .result(result), .watching(playerIDs: []), .roundResults, .finished,
        ]
        #expect(needsPlayer.allSatisfy(\.needsPlayer))
        #expect(!mainScreen.contains(where: \.needsPlayer))
    }

    @Test func identityKeepsItsIDAndNeedsAName() throws {
        let suite = "SessionIdentityTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(SessionIdentity.player(name: "   ", emoji: "🦊", defaults: defaults) == nil)
        let first = try #require(SessionIdentity.player(name: " Mia ", emoji: "🦊", defaults: defaults))
        let second = try #require(SessionIdentity.player(name: "Mia the Great", emoji: "🐸", defaults: defaults))
        #expect(first.name == "Mia")
        #expect(first.id == second.id)
        let long = try #require(SessionIdentity.player(name: String(repeating: "x", count: 40), emoji: "🦊", defaults: defaults))
        #expect(long.name.count == 24)
    }

    @Test func hostAndGuestPlayTheSameGame() throws {
        let host = Player(name: "Host", emoji: "🦊")
        let guest = Player(name: "Guest", emoji: "🐸")
        var logic = SessionHostLogic()
        let hostJoined = logic.join(host, protocolVersion: SessionProtocol.version, gameInProgress: false, maxPlayers: 10)
        let guestJoined = logic.join(guest, protocolVersion: SessionProtocol.version, gameInProgress: false, maxPlayers: 10)
        #expect(hostJoined == .joined)
        #expect(guestJoined == .joined)

        var engine = try GameEngine(players: logic.connectedPlayers, rounds: 1)
        var hostTurn = ClientTurn()
        var snapshot = logic.snapshot(engine: engine, hostName: "", mode: .classic, revision: 1, revealLanded: false) { _ in nil }
        hostTurn.sync(with: snapshot)
        #expect(hostTurn.screen(for: snapshot, me: host.id) == .yourTurn)

        let ready = hostTurn.markReady()
        #expect(ready)
        logic.apply(.ready, from: host.id, to: &engine, now: 10)
        let started = hostTurn.start(at: 20)
        #expect(started)
        logic.apply(.started, from: host.id, to: &engine, now: 20)
        let elapsed = try #require(hostTurn.stop(at: 30.01))
        let result = logic.apply(.stopped(elapsed: elapsed), from: host.id, to: &engine, now: 31)
        #expect(result?.playerID == host.id)

        snapshot = logic.snapshot(engine: engine, hostName: "", mode: .classic, revision: 2, revealLanded: false) { _ in nil }
        #expect(hostTurn.screen(for: snapshot, me: host.id) == .drumroll)
        #expect(!(hostTurn.screen(for: snapshot, me: host.id).needsPlayer))
    }
}
