import Foundation

/// The host's session rules, free of networking and UI so they can be tested.
/// It keeps the roster and turns player events into `GameEngine` actions.
struct SessionHostLogic: Sendable {
    enum JoinResult: Equatable, Sendable {
        case joined
        case rejoined
        case rejected(SessionRejection)
    }

    /// Grace period before the host auto-stops a running turn itself, so a
    /// player's own timeout (sent over the network) normally arrives first.
    static let timeoutGrace: TimeInterval = 5

    private(set) var players: [Player] = []
    private(set) var connected: Set<Player.ID> = []
    /// Players of the current turn who tapped "ready".
    private(set) var ready: Set<Player.ID> = []
    private var readyTurn: UUID?
    /// Voided attempts so far; sent along so phones reset their turn.
    private(set) var turnAttempt = 0

    var sessionPlayers: [SessionPlayer] {
        players.map { SessionPlayer(player: $0, isConnected: connected.contains($0.id)) }
    }

    var connectedPlayers: [Player] {
        players.filter { connected.contains($0.id) }
    }

    // MARK: - Roster

    /// A new player joins the lobby; a known player may rejoin at any time.
    mutating func join(_ player: Player, protocolVersion: Int, gameInProgress: Bool, maxPlayers: Int) -> JoinResult {
        guard protocolVersion == SessionProtocol.version else { return .rejected(.incompatibleVersion) }
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            if !gameInProgress {
                players[index] = player
            }
            connected.insert(player.id)
            return .rejoined
        }
        if gameInProgress { return .rejected(.gameInProgress) }
        if players.count >= maxPlayers { return .rejected(.full) }
        players.append(player)
        connected.insert(player.id)
        return .joined
    }

    /// In the lobby a player who leaves is removed; during a game they stay
    /// on the roster so they can rejoin.
    mutating func disconnect(_ id: Player.ID, gameInProgress: Bool) {
        connected.remove(id)
        if !gameInProgress {
            players.removeAll { $0.id == id }
        }
    }

    /// Back in the lobby after a game: forget everyone who is gone.
    mutating func dropDisconnected() {
        players.removeAll { !connected.contains($0.id) }
        ready = []
        readyTurn = nil
    }

    // MARK: - Turn events

    /// Applies a player's event to the engine. Returns the result when the
    /// event ended that player's turn.
    @discardableResult
    mutating func apply(
        _ message: ClientMessage,
        from playerID: Player.ID,
        to engine: inout GameEngine,
        now: TimeInterval
    ) -> TurnResult? {
        syncReady(with: engine)
        guard let lane = engine.lanes.firstIndex(where: { $0.playerID == playerID }) else { return nil }
        switch message {
        case .hello:
            return nil
        case .ready:
            guard engine.phase == .handoff else { return nil }
            ready.insert(playerID)
            if engine.lanes.allSatisfy({ ready.contains($0.playerID) }) {
                engine.beginTurn()
            }
            return nil
        case .started:
            engine.start(lane: lane, at: now)
            return nil
        case .stopped(let elapsed):
            guard elapsed.isFinite, let startedAt = engine.lanes[lane].startedAt else { return nil }
            return engine.stop(lane: lane, at: startedAt + max(0, elapsed))
        case .voided:
            guard engine.phase == .ready || engine.phase == .running else { return nil }
            engine.voidTurn()
            ready = []
            turnAttempt += 1
            return nil
        }
    }

    /// Ends a player's turn as a timeout, e.g. when their phone dropped out.
    @discardableResult
    mutating func forfeit(_ playerID: Player.ID, engine: inout GameEngine, now: TimeInterval) -> TurnResult? {
        guard let lane = engine.lanes.firstIndex(where: { $0.playerID == playerID }),
              !engine.lanes[lane].isDone
        else { return nil }
        if engine.phase == .handoff {
            engine.beginTurn()
        }
        if engine.lanes[lane].startedAt == nil {
            engine.start(lane: lane, at: now)
        }
        guard let startedAt = engine.lanes[lane].startedAt else { return nil }
        return engine.stop(lane: lane, at: startedAt + Scoring.timeoutDuration(for: engine.target))
    }

    /// Players of the current turn whose phone is not connected.
    func missingTurnPlayers(in engine: GameEngine) -> [Player.ID] {
        guard [.handoff, .ready, .running].contains(engine.phase) else { return [] }
        return engine.lanes.filter { !$0.isDone && !connected.contains($0.playerID) }.map(\.playerID)
    }

    /// Forgets who was ready once the engine has moved on to another turn.
    mutating func syncReady(with engine: GameEngine) {
        if readyTurn != engine.turnID {
            ready = []
            readyTurn = engine.turnID
        }
    }

    // MARK: - Snapshot

    /// The state every player's phone renders.
    func snapshot(
        engine: GameEngine?,
        hostName: String,
        mode: ModeKind,
        revision: Int,
        revealLanded: Bool,
        reaction: (TurnResult) -> String?
    ) -> SessionSnapshot {
        guard let engine else {
            return SessionSnapshot(
                revision: revision, hostName: hostName, mode: mode, stage: .lobby,
                round: 0, rounds: 0, players: sessionPlayers, turnID: nil, turnAttempt: turnAttempt, turnPlayerIDs: [],
                target: GameEngine.classicTarget, effect: .dark, readyPlayerIDs: [],
                startedPlayerIDs: [], finishedPlayerIDs: [], revealLanded: false,
                results: [], standings: [], winnerID: nil, winningTeam: nil
            )
        }
        let stage: SessionSnapshot.Stage = switch engine.phase {
        case .handoff: .handoff
        case .ready: .ready
        case .running: .running
        case .reveal: .reveal
        case .roundResults: .roundResults
        case .finished: .finished
        }
        let showsTurn = [.handoff, .ready, .running, .reveal].contains(engine.phase)
        let results = (engine.phase == .reveal && revealLanded) ? engine.revealedResults.map { result in
            SessionResult(
                playerID: result.playerID,
                stopped: result.outcome == .misfire || result.outcome == .timeout ? result.stopped : result.displayedStopped,
                deviation: result.displayedDeviation,
                outcome: result.outcome,
                points: result.points,
                reaction: reaction(result)
            )
        } : []
        let isCurrentTurn = readyTurn == engine.turnID
        return SessionSnapshot(
            revision: revision,
            hostName: hostName,
            mode: engine.mode.kind,
            stage: stage,
            round: engine.round,
            rounds: engine.rounds,
            players: sessionPlayers,
            turnID: showsTurn ? engine.turnID : nil,
            turnAttempt: turnAttempt,
            turnPlayerIDs: showsTurn ? engine.lanes.map(\.playerID) : [],
            target: engine.target,
            effect: engine.blindEffect,
            readyPlayerIDs: isCurrentTurn ? engine.lanes.map(\.playerID).filter(ready.contains) : [],
            startedPlayerIDs: engine.lanes.filter { $0.startedAt != nil }.map(\.playerID),
            finishedPlayerIDs: engine.lanes.filter(\.isDone).map(\.playerID),
            revealLanded: revealLanded,
            results: results,
            standings: engine.standings().map {
                SessionStanding(
                    playerID: $0.player.id,
                    points: $0.points,
                    totalDeviation: $0.totalDeviation,
                    isEliminated: $0.eliminatedInRound != nil
                )
            },
            winnerID: engine.winner?.id,
            winningTeam: engine.winningTeam
        )
    }
}
