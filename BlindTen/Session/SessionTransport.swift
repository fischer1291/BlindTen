import Foundation

/// A remote device in a session, independent of the network technology.
struct TransportPeer: Hashable, Sendable {
    /// Stable for the lifetime of the transport.
    let id: String
    let displayName: String
}

enum TransportEvent: Sendable {
    /// A host was discovered (guests only).
    case found(TransportPeer, name: String)
    case lost(TransportPeer)
    case connected(TransportPeer)
    case disconnected(TransportPeer)
    case received(Data, from: TransportPeer)
}

typealias TransportEventHandler = @MainActor @Sendable (TransportEvent) -> Void

/// Moves session messages between devices. Local play uses
/// MultipeerConnectivity (`PeerTransport`); online play can plug in another
/// implementation without touching the session logic. Events are delivered
/// in order on the main actor.
protocol SessionTransport: AnyObject, Sendable {
    var connectedPeers: [TransportPeer] { get }
    func send(_ data: Data, to peers: [TransportPeer])
    func stop()
}

/// The host side: makes the session discoverable.
protocol HostTransport: SessionTransport {
    func advertise(name: String)
}

/// The guest side: finds hosts and asks to join one.
protocol GuestTransport: SessionTransport {
    func browse()
    func join(_ peer: TransportPeer)
}
