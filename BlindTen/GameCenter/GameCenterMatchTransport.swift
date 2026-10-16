@preconcurrency import GameKit

/// Session messages over a Game Center real-time match, for Live Match.
/// Every phone is connected to every other; the session host is elected
/// with `LiveMatchRules.host(among:)`, so a guest "finds" exactly that host.
final class GameCenterMatchTransport: NSObject, HostTransport, GuestTransport, GKMatchDelegate, @unchecked Sendable {
    private let match: GKMatch
    private let host: TransportPeer?
    private let onEvent: TransportEventHandler
    private let lock = NSLock()
    private var heardFromHost = false

    /// `host` is the elected host, for guests; nil on the host itself.
    init(match: GKMatch, host: TransportPeer?, onEvent: @escaping TransportEventHandler) {
        self.match = match
        self.host = host
        self.onEvent = onEvent
        super.init()
        match.delegate = self
    }

    static func peer(_ player: GKPlayer) -> TransportPeer {
        TransportPeer(id: player.gamePlayerID, displayName: player.displayName)
    }

    var connectedPeers: [TransportPeer] {
        match.players.map(Self.peer)
    }

    func send(_ data: Data, to peers: [TransportPeer]) {
        let ids = Set(peers.map(\.id))
        let players = match.players.filter { ids.contains($0.gamePlayerID) }
        guard !players.isEmpty else { return }
        try? match.send(data, to: players, dataMode: .reliable)
    }

    func stop() {
        match.delegate = nil
        match.disconnect()
    }

    // MARK: - Host

    /// Nothing to announce: everyone in the match is already connected.
    func advertise(name: String) {}

    // MARK: - Guest

    func browse() {
        if let host {
            emit(.found(host, name: host.displayName))
        }
    }

    /// The match is connected already. The host may not listen yet when the
    /// match starts, so "connected" (which sends hello) repeats until the
    /// host answers.
    func join(_ peer: TransportPeer) {
        emit(.connected(peer))
        for delay in [1.0, 2.5, 5.0, 9.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, !self.hasHeardFromHost else { return }
                self.emit(.connected(peer))
            }
        }
    }

    private var hasHeardFromHost: Bool {
        lock.withLock { heardFromHost }
    }

    // MARK: - GKMatchDelegate

    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        let peer = Self.peer(player)
        if peer == host {
            lock.withLock { heardFromHost = true }
        }
        emit(.received(data, from: peer))
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        guard state == .disconnected else { return }
        emit(.disconnected(Self.peer(player)))
    }

    /// Delivers in order on the main actor.
    private func emit(_ event: TransportEvent) {
        let handler = onEvent
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                handler(event)
            }
        }
    }
}
