@preconcurrency import MultipeerConnectivity

/// A thin MultipeerConnectivity wrapper: the host advertises, players browse
/// and invite themselves. Delegate callbacks arrive on background queues and
/// are forwarded, in order, to the main actor.
final class PeerTransport: NSObject, @unchecked Sendable {
    /// A remote phone. Wraps `MCPeerID`, which is not marked Sendable.
    struct Peer: Hashable, @unchecked Sendable {
        let id: MCPeerID
        var displayName: String { id.displayName }
    }

    enum Event: Sendable {
        case found(Peer, name: String)
        case lost(Peer)
        case connected(Peer)
        case disconnected(Peer)
        case received(Data, from: Peer)
    }

    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let onEvent: @MainActor @Sendable (Event) -> Void

    init(displayName: String, onEvent: @escaping @MainActor @Sendable (Event) -> Void) {
        let peer = MCPeerID(displayName: Self.safeName(displayName))
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        self.onEvent = onEvent
        super.init()
        session.delegate = self
    }

    var connectedPeers: [Peer] {
        session.connectedPeers.map(Peer.init)
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
    func join(_ peer: Peer) {
        browser?.invitePeer(peer.id, to: session, withContext: nil, timeout: 15)
    }

    func send(_ data: Data, to peers: [Peer]) {
        guard !peers.isEmpty else { return }
        try? session.send(data, toPeers: peers.map(\.id), with: .reliable)
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
    }

    private func emit(_ event: Event) {
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
        case .connected: emit(.connected(Peer(id: peerID)))
        case .notConnected: emit(.disconnected(Peer(id: peerID)))
        case .connecting: break
        @unknown default: break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        emit(.received(data, from: Peer(id: peerID)))
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
        emit(.found(Peer(id: peerID), name: name))
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        emit(.lost(Peer(id: peerID)))
    }
}
