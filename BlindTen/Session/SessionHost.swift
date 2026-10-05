import Foundation
import Observation

/// Hosts a local session. This phone is the main screen (put it on the TV
/// with AirPlay); players join with their own iPhones and play their turns
/// there. The game itself runs in `AppState.engine`, so the TV scene and the
/// regular leaderboards work unchanged.
@MainActor
@Observable
final class SessionHost {
    /// Short emoji code that players pick from the list of sessions nearby.
    let code: String
    var rounds = GameEngine.defaultRounds
    private(set) var logic = SessionHostLogic()
    /// False while the reveal's drumroll spins.
    private(set) var isRevealLanded = false

    private unowned let state: AppState
    @ObservationIgnored private var transport: PeerTransport?
    @ObservationIgnored private var peers: [PeerTransport.Peer: Player.ID] = [:]
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var presentedReveal: UUID?
    @ObservationIgnored private var revealTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutDeadline: TimeInterval?

    init(state: AppState) {
        self.state = state
        let emoji = Avatar.pool.shuffled()
        code = emoji.prefix(3).joined()
    }

    var isGameRunning: Bool { state.engine != nil }

    /// Joined players who are still connected, in joining order.
    var players: [Player] { logic.connectedPlayers }

    var canStart: Bool {
        players.count >= GameEngine.minPlayers
            && PartyPack.canPlay(state.selectedMode, unlocked: state.isPartyPackUnlocked)
    }

    /// Players of the current turn whose phone dropped out.
    var missingPlayers: [Player] {
        guard let engine = state.engine else { return [] }
        return logic.missingTurnPlayers(in: engine).compactMap { engine.player(withID: $0) }
    }

    func open() {
        guard transport == nil else { return }
        let transport = PeerTransport(displayName: code) { [weak self] event in
            self?.handle(event)
        }
        transport.advertise(name: code)
        self.transport = transport
    }

    func close() {
        revealTask?.cancel()
        timeoutTask?.cancel()
        transport?.stop()
        transport = nil
        state.feel.stopAll()
        state.revealPresentation = nil
    }

    // MARK: - Host controls

    func startGame() {
        guard canStart else { return }
        do {
            try state.startGame(players: players, rounds: rounds, remember: false)
        } catch {
            return
        }
        engineDidChange()
    }

    /// Round results → next round; reveal → next turn.
    func next() {
        guard let phase = state.engine?.phase, phase == .reveal || phase == .roundResults else { return }
        state.advance()
        engineDidChange()
    }

    /// Records a timeout for every player of the turn whose phone is gone.
    func skipMissingPlayers() {
        guard var engine = state.engine else { return }
        let now = ProcessInfo.processInfo.systemUptime
        var results: [TurnResult] = []
        for id in logic.missingTurnPlayers(in: engine) {
            if let result = logic.forfeit(id, engine: &engine, now: now) {
                results.append(result)
            }
        }
        state.engine = engine
        for result in results {
            state.assignReaction(to: result)
        }
        engineDidChange()
    }

    func rematch() {
        state.rematch()
        engineDidChange()
    }

    /// Ends the game and opens the lobby again; new players can join.
    func backToLobby() {
        revealTask?.cancel()
        timeoutTask?.cancel()
        state.feel.stopAll()
        state.revealPresentation = nil
        state.newGame()
        logic.dropDisconnected()
        broadcast()
    }

    // MARK: - Network

    private func handle(_ event: PeerTransport.Event) {
        switch event {
        case .found, .lost, .connected:
            break
        case .disconnected(let peer):
            guard let id = peers.removeValue(forKey: peer), !peers.values.contains(id) else { return }
            logic.disconnect(id, gameInProgress: isGameRunning)
            broadcast()
        case .received(let data, let peer):
            guard let message = SessionCoding.decode(ClientMessage.self, from: data) else { return }
            receive(message, from: peer)
        }
    }

    private func receive(_ message: ClientMessage, from peer: PeerTransport.Peer) {
        if case .hello(let player, let version) = message {
            let result = logic.join(player, protocolVersion: version, gameInProgress: isGameRunning, maxPlayers: state.maxPlayers)
            if case .rejected(let reason) = result {
                send(.rejected(reason), to: [peer])
            } else {
                peers[peer] = player.id
                broadcast()
            }
            return
        }
        guard let id = peers[peer], var engine = state.engine else { return }
        let result = logic.apply(message, from: id, to: &engine, now: ProcessInfo.processInfo.systemUptime)
        state.engine = engine
        if let result {
            state.assignReaction(to: result)
        }
        engineDidChange()
    }

    private func send(_ message: HostMessage, to peers: [PeerTransport.Peer]) {
        guard let data = SessionCoding.encode(message) else { return }
        transport?.send(data, to: peers)
    }

    private func broadcast() {
        revision += 1
        let snapshot = logic.snapshot(
            engine: state.engine,
            hostName: code,
            mode: state.selectedMode,
            revision: revision,
            revealLanded: isRevealLanded
        ) { [state] result in
            state.reactionText(for: result)
        }
        send(.snapshot(snapshot), to: Array(peers.keys))
    }

    // MARK: - Game flow

    /// Runs after every change to the game: starts the reveal, arms the
    /// timeout and tells every phone.
    private func engineDidChange() {
        if let engine = state.engine {
            logic.syncReady(with: engine)
            presentRevealIfNeeded(engine)
            armTimeout(engine.timeoutDeadline)
        } else {
            armTimeout(nil)
        }
        broadcast()
    }

    /// The drumroll spins on the main screen, then the result lands on every
    /// phone at once. Advances by itself shortly after.
    private func presentRevealIfNeeded(_ engine: GameEngine) {
        guard engine.phase == .reveal, let first = engine.revealedResults.first else {
            if engine.phase != .reveal {
                isRevealLanded = false
            }
            return
        }
        guard presentedReveal != first.id else { return }
        presentedReveal = first.id
        isRevealLanded = false
        let results = engine.revealedResults
        let duration = RevealTiming.randomDrumrollDuration()
        let start = ProcessInfo.processInfo.systemUptime
        state.revealPresentation = RevealPresentation(firstResultID: first.id, drumrollStart: start, drumrollDuration: duration)
        state.feel.beginDrumroll(duration: duration)
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            self.land(results)
            try? await Task.sleep(for: RevealTiming.autoAdvanceDelay + Self.extraRevealTime)
            guard !Task.isCancelled, self.state.engine?.revealedResults.first?.id == first.id else { return }
            self.next()
        }
    }

    /// Players look at their own phone and then up at the TV, so the reveal
    /// stays a little longer than in pass-the-phone play.
    private static let extraRevealTime: Duration = .seconds(2)

    private func land(_ results: [TurnResult]) {
        isRevealLanded = true
        state.revealPresentation?.landedAt = ProcessInfo.processInfo.systemUptime
        state.feel.land(LandingCue(results: results))
        broadcast()
    }

    /// Auto-stops a running turn a little after its timeout, in case the
    /// player's phone never reports back. A single wait, not a ticking timer.
    private func armTimeout(_ deadline: TimeInterval?) {
        guard deadline != timeoutDeadline else { return }
        timeoutDeadline = deadline
        timeoutTask?.cancel()
        guard let deadline else { return }
        timeoutTask = Task { [weak self] in
            let wait = deadline + SessionHostLogic.timeoutGrace - ProcessInfo.processInfo.systemUptime
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled, let self else { return }
            self.state.autoStopIfOverdue(now: ProcessInfo.processInfo.systemUptime - SessionHostLogic.timeoutGrace)
            self.timeoutDeadline = nil
            self.engineDidChange()
        }
    }
}
