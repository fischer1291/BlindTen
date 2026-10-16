@preconcurrency import MultipeerConnectivity

/// The local-network transport: a thin MultipeerConnectivity wrapper. The
/// host advertises, players browse and invite themselves. Delegate callbacks
/// arrive on background queues and are forwarded, in order, to the main actor.
final class PeerTransport: NSObject, HostTransport, GuestTransport, @unchecked Sendable {
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let onEvent: TransportEventHandler
    /// `MCPeerID` is not Sendable; the rest of the app only sees `TransportPeer`.
    private let lock = NSLock()
    private var peersByID: [MCPeerID: TransportPeer] = [:]
    private var mcPeers: [String: MCPeerID] = [:]

    init(displayName: String, onEvent: @escaping TransportEventHandler) {
        let peer = MCPeerID(displayName: Self.safeName(displayName))
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        self.onEvent = onEvent
        super.init()
        session.delegate = self
    }

    var connectedPeers: [TransportPeer] {
        session.connectedPeers.map(peer(for:))
    }

    /// Host: lets players find this session under `name`.
    func advertise(name: String) {
        let advertiser = MCNearbyServiceAdvertiser(
            peer: session.myPeerID,
            discoveryInfo: [SessionProtocol.nameKey: name],
            serviceType: SessionProtocol.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    /// Player: looks for hosts nearby.
    func browse() {
        guard browser == nil else { return }
        let browser = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: SessionProtocol.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    /// Player: asks a host to connect.
    func join(_ peer: TransportPeer) {
        guard let id = mcPeer(for: peer) else { return }
        browser?.invitePeer(id, to: session, withContext: nil, timeout: 15)
    }

    func send(_ data: Data, to peers: [TransportPeer]) {
        let ids = peers.compactMap(mcPeer(for:))
        guard !ids.isEmpty else { return }
        try? session.send(data, toPeers: ids, with: .reliable)
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
    }

    private func peer(for id: MCPeerID) -> TransportPeer {
        lock.withLock {
            if let known = peersByID[id] { return known }
            let peer = TransportPeer(id: UUID().uuidString, displayName: id.displayName)
            peersByID[id] = peer
            mcPeers[peer.id] = id
            return peer
        }
    }

    private func mcPeer(for peer: TransportPeer) -> MCPeerID? {
        lock.withLock { mcPeers[peer.id] }
    }

    private func emit(_ event: TransportEvent) {
        let handler = onEvent
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                handler(event)
            }
        }
    }

    /// `MCPeerID` needs a non-empty name of at most 63 UTF-8 bytes.
    static func safeName(_ name: String) -> String {
        var result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty { result = "Blind Ten" }
        while result.utf8.count > 63 {
            result.removeLast()
        }
        return result
    }
}

extension PeerTransport: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected: emit(.connected(peer(for: peerID)))
        case .notConnected: emit(.disconnected(peer(for: peerID)))
        case .connecting: break
        @unknown default: break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        emit(.received(data, from: peer(for: peerID)))
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

extension PeerTransport: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Whether a player may stay is decided by their "hello".
        invitationHandler(true, session)
    }
}

extension PeerTransport: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let name = info?[SessionProtocol.nameKey] ?? peerID.displayName
        emit(.found(peer(for: peerID), name: name))
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        emit(.lost(peer(for: peerID)))
    }
}
