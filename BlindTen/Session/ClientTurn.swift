import Foundation

/// A joined player's own turn state, plus what their phone shows for a
/// host snapshot. Free of networking and UI so it can be tested.
struct ClientTurn: Equatable, Sendable {
    enum Screen: Equatable, Sendable {
        /// No snapshot from the host yet.
        case connecting
        case lobby
        /// "It's your turn" with a tap-when-ready button.
        case yourTurn
        /// Ready, waiting for the other duel player.
        case waitingForOpponent
        /// Target and START.
        case start(target: TimeInterval)
        /// The blind phase. `startedAt` is this phone's START touch timestamp.
        case blind(startedAt: TimeInterval)
        /// Stopped; waiting for the reveal.
        case stopped
        /// The reveal is spinning on the main screen.
        case drumroll
        case result(SessionResult)
        /// Somebody else is playing.
        case watching(playerIDs: [Player.ID])
        case roundResults
        case finished
    }

    /// START touch timestamp on this phone (system uptime).
    private(set) var startedAt: TimeInterval?
    /// Elapsed seconds, measured on this phone and sent to the host.
    private(set) var elapsed: TimeInterval?
    private(set) var readySent = false
    private var turnKey: TurnKey?

    private struct TurnKey: Equatable, Sendable {
        let turnID: UUID?
        let attempt: Int
    }

    /// Starts over whenever the host moves to another turn or replays one.
    mutating func sync(with snapshot: SessionSnapshot) {
        let key = TurnKey(turnID: snapshot.turnID, attempt: snapshot.turnAttempt)
        guard key != turnKey else { return }
        turnKey = key
        startedAt = nil
        elapsed = nil
        readySent = false
    }

    /// Returns true if "ready" should be sent.
    mutating func markReady() -> Bool {
        guard !readySent else { return false }
        readySent = true
        return true
    }

    /// Returns true if START should be sent.
    mutating func start(at timestamp: TimeInterval) -> Bool {
        guard startedAt == nil else { return false }
        startedAt = timestamp
        return true
    }

    /// Returns the elapsed seconds to send, or nil if this turn already stopped.
    mutating func stop(at timestamp: TimeInterval) -> TimeInterval? {
        guard let startedAt, elapsed == nil else { return nil }
        let value = max(0, timestamp - startedAt)
        elapsed = value
        return value
    }

    /// True while this phone's timer runs.
    var isRunning: Bool { startedAt != nil && elapsed == nil }

    func screen(for snapshot: SessionSnapshot?, me: Player.ID) -> Screen {
        guard let snapshot else { return .connecting }
        let isMine = snapshot.turnPlayerIDs.contains(me)
        switch snapshot.stage {
        case .lobby:
            return .lobby
        case .handoff:
            guard isMine else { return .watching(playerIDs: snapshot.turnPlayerIDs) }
            return readySent || snapshot.readyPlayerIDs.contains(me) ? .waitingForOpponent : .yourTurn
        case .ready, .running:
            guard isMine else { return .watching(playerIDs: snapshot.turnPlayerIDs) }
            if elapsed != nil || snapshot.finishedPlayerIDs.contains(me) { return .stopped }
            if let startedAt { return .blind(startedAt: startedAt) }
            return .start(target: snapshot.target)
        case .reveal:
            guard isMine else { return .watching(playerIDs: snapshot.turnPlayerIDs) }
            if snapshot.revealLanded, let result = snapshot.results.first(where: { $0.playerID == me }) {
                return .result(result)
            }
            return .drumroll
        case .roundResults:
            return .roundResults
        case .finished:
            return .finished
        }
    }
}

extension ClientTurn.Screen {
    /// True while this player has to act on their phone: get ready, START,
    /// the blind phase. The host phone shows its turn only then and the
    /// main screen the rest of the time.
    var needsPlayer: Bool {
        switch self {
        case .yourTurn, .waitingForOpponent, .start, .blind: true
        case .connecting, .lobby, .stopped, .drumroll, .result, .watching, .roundResults, .finished: false
        }
    }
}

/// The player identity this phone uses in sessions, as host or guest. The ID
/// stays the same so a dropped phone rejoins as the same player.
enum SessionIdentity {
    static let idKey = "session.playerID"
    static let nameKey = "session.playerName"
    static let emojiKey = "session.playerEmoji"
    /// Whether the host also plays (on by default).
    static let hostPlaysKey = "session.hostPlays"

    static func playerID(defaults: UserDefaults = .standard) -> UUID {
        if let stored = defaults.string(forKey: idKey), let id = UUID(uuidString: stored) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: idKey)
        return id
    }

    /// Nil until a name is entered. Names are capped so they fit on the TV.
    static func player(name: String, emoji: String, defaults: UserDefaults = .standard) -> Player? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Player(id: playerID(defaults: defaults), name: String(trimmed.prefix(24)), emoji: emoji)
    }
}
