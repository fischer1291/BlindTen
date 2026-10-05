import Foundation
import Observation

/// A player's side of a local session: finds hosts nearby, joins one and
/// plays turns on this phone. START and STOP are measured here with
/// `UITouch.timestamp`; only the elapsed time goes to the host.
@MainActor
@Observable
final class SessionClient {
    struct Host: Identifiable, Equatable {
        let peer: PeerTransport.Peer
        let name: String

        var id: PeerTransport.Peer { peer }
    }

    enum Status: Equatable {
        case browsing
        case connecting(String)
        case connected
        case rejected(SessionRejection)
        /// The connection dropped; reconnects when the host shows up again.
        case reconnecting(String)
    }

    let player: Player
    private(set) var hosts: [Host] = []
    private(set) var status: Status = .browsing
    private(set) var snapshot: SessionSnapshot?
    private(set) var turn = ClientTurn()

    @ObservationIgnored private var transport: PeerTransport?
    @ObservationIgnored private var hostPeer: PeerTransport.Peer?
    @ObservationIgnored private var hostName: String?

    init(player: Player) {
        self.player = player
    }

    /// True once the host has sent the session state.
    var isInSession: Bool { snapshot != nil }

    var screen: ClientTurn.Screen { turn.screen(for: snapshot, me: player.id) }

    func open() {
        guard transport == nil else { return }
        let transport = PeerTransport(displayName: player.name) { [weak self] event in
            self?.handle(event)
        }
        transport.browse()
        self.transport = transport
    }

    func close() {
        transport?.stop()
        transport = nil
    }

    func join(_ host: Host) {
        hostName = host.name
        hostPeer = host.peer
        status = .connecting(host.name)
        transport?.join(host.peer)
    }

    // MARK: - Turn

    func ready() {
        if turn.markReady() {
            send(.ready)
        }
    }

    func start(at timestamp: TimeInterval) {
        if turn.start(at: timestamp) {
            send(.started)
        }
    }

    /// Returns true if this touch ended the turn.
    @discardableResult
    func stop(at timestamp: TimeInterval) -> Bool {
        guard let elapsed = turn.stop(at: timestamp) else { return false }
        send(.stopped(elapsed: elapsed))
        return true
    }

    /// The app left the foreground mid-turn: the host replays the turn.
    func voidIfRunning() {
        guard turn.isRunning else { return }
        send(.voided)
    }

    // MARK: - Network

    private func handle(_ event: PeerTransport.Event) {
        switch event {
        case .found(let peer, let name):
            hosts.removeAll { $0.peer == peer || $0.name == name }
            hosts.append(Host(peer: peer, name: name))
            // Back in range after a dropout: rejoin the same session.
            if case .reconnecting(let previous) = status, previous == name {
                join(Host(peer: peer, name: name))
            }
        case .lost(let peer):
            hosts.removeAll { $0.peer == peer }
        case .connected(let peer):
            guard peer == hostPeer else { return }
            status = .connected
            send(.hello(player: player, protocolVersion: SessionProtocol.version))
        case .disconnected(let peer):
            guard peer == hostPeer else { return }
            hostPeer = nil
            if case .rejected = status { return }
            guard snapshot != nil else {
                // Never got in: back to the list of sessions.
                status = .browsing
                return
            }
            status = .reconnecting(hostName ?? "")
            if turn.isRunning {
                // The turn cannot be finished without the host.
                turn = ClientTurn()
            }
            if let host = hosts.first(where: { $0.name == hostName }) {
                join(host)
                status = .reconnecting(host.name)
            }
        case .received(let data, let peer):
            guard peer == hostPeer, let message = SessionCoding.decode(HostMessage.self, from: data) else { return }
            switch message {
            case .snapshot(let snapshot):
                turn.sync(with: snapshot)
                self.snapshot = snapshot
            case .rejected(let reason):
                status = .rejected(reason)
                snapshot = nil
                hostPeer = nil
                transport?.stop()
                transport = nil
                open()
            }
        }
    }

    private func send(_ message: ClientMessage) {
        guard let hostPeer, let data = SessionCoding.encode(message) else { return }
        transport?.send(data, to: [hostPeer])
    }
}
