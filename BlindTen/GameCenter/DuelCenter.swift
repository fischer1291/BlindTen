@preconcurrency import GameKit
import Observation
import UIKit

/// Online duels as Game Center turn-based matches (SPEC.md M8). The duel
/// rules live in `DuelState`; this class only loads, saves and passes turns.
/// Game Center sends the "your turn" notifications itself.
@MainActor
@Observable
final class DuelCenter {
    /// One duel as the lists show it.
    struct Summary: Identifiable, Equatable {
        enum Status: Equatable {
            /// The local player can play now.
            case yourTurn
            /// Waiting for the opponent, or for Game Center to find one.
            case theirTurn
            case finished(DuelState.Outcome?)
        }

        let id: String
        let me: Int
        let opponentName: String?
        let state: DuelState?
        let status: Status
        let lastChange: Date?
        /// The opponent quit or let the turn time out.
        let opponentQuit: Bool

        var wins: (mine: Int, theirs: Int) {
            guard let state else { return (0, 0) }
            let wins = state.wins
            return (wins[me], wins[1 - me])
        }
    }

    private(set) var duels: [Summary] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    /// Set when a "your turn" notification was opened; the duel screen shows it.
    var pendingMatchID: String?
    /// True while the duel list is on screen, so Home does not push a second one.
    @ObservationIgnored var isListVisible = false
    /// The duel being played right now; its turn is passed from the summary.
    @ObservationIgnored var activeMatchID: String?

    @ObservationIgnored private var matches: [String: GKTurnBasedMatch] = [:]
    /// The kind picked for the last new duel; a creator's match starts empty.
    @ObservationIgnored private var requestedKind: ChallengeKind = .classic
    @ObservationIgnored private var claiming: Set<String> = []
    @ObservationIgnored private var listener: Listener?
    @ObservationIgnored private let matchmakerDelegate = MatchmakerDelegate()
    /// Called when a duel ends, to count it in the records.
    @ObservationIgnored var onFinished: ((String, ChallengeRecords.DuelResult) -> Void)?

    /// Starts listening for turn events. Call once Game Center is signed in.
    func start() {
        guard listener == nil else { return }
        let listener = Listener(center: self)
        GKLocalPlayer.local.register(listener)
        self.listener = listener
        Task { await refresh() }
    }

    func refresh() async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await GKTurnBasedMatch.loadMatches()
            matches = Dictionary(loaded.map { ($0.matchID, $0) }, uniquingKeysWith: { first, _ in first })
            duels = loaded.compactMap(summary(for:)).sorted(by: Self.order)
            lastError = nil
            countFinishedDuels()
            passFinishedTurns()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func summary(id: String) -> Summary? {
        duels.first { $0.id == id }
    }

    // MARK: - New duels

    /// Plays against a random opponent with the same kind of duel.
    func findRandomOpponent(kind: ChallengeKind) async -> String? {
        requestedKind = kind
        do {
            let match = try await GKTurnBasedMatch.find(for: Self.request(kind: kind))
            matches[match.matchID] = match
            await refresh()
            return match.matchID
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Shows Apple's screen to invite a friend. The new match arrives as a
    /// turn event and opens on its own.
    func inviteFriend(kind: ChallengeKind) {
        requestedKind = kind
        let request = Self.request(kind: kind)
        request.inviteMessage = String(localized: "Can you feel 10 seconds? Duel me in Blind Ten!")
        let viewController = GKTurnBasedMatchmakerViewController(matchRequest: request)
        viewController.turnBasedMatchmakerDelegate = matchmakerDelegate
        viewController.showExistingMatches = false
        TopViewController.find()?.present(viewController, animated: true)
    }

    private static func request(kind: ChallengeKind) -> GKMatchRequest {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        // Random opponents only meet players of the same kind of duel.
        request.playerGroup = kind == .classic ? 1 : 2
        return request
    }

    // MARK: - Playing

    /// The plan for the local player's turn, if it is their turn. A new
    /// match gets its duel state here, from its creator.
    func plan(for id: String) -> DuelPlan? {
        guard let match = matches[id], let me = localIndex(in: match), isLocalTurn(match) else { return nil }
        let state = DuelState.decode(match.matchData) ?? DuelState(kind: requestedKind)
        guard state.nextRound(for: me) != nil else { return nil }
        return DuelPlan(matchID: id, me: me, opponentName: opponentName(in: match, me: me), state: state)
    }

    /// Saves progress, and passes the turn on or ends the duel once the
    /// player's rounds are done.
    func update(_ id: String, state: DuelState, isTurnComplete: Bool) {
        guard let data = state.encoded() else { return }
        Task {
            await send(id, data: data, outcome: state.outcome, isTurnComplete: isTurnComplete)
            await refresh()
        }
    }

    private func send(_ id: String, data: Data, outcome: DuelState.Outcome?, isTurnComplete: Bool) async {
        guard let match = matches[id], let me = localIndex(in: match), match.participants.count == 2 else { return }
        do {
            if !isTurnComplete {
                try await match.saveCurrentTurn(withMatch: data)
            } else if let outcome {
                setOutcomes(outcome, in: match)
                match.message = String(localized: "The duel is over. See who won!")
                try await match.endMatchInTurn(withMatch: data)
                onFinished?(id, Self.result(outcome, me: me))
            } else {
                let opponent = match.participants[1 - me]
                let previous = DuelState.decode(match.matchData)?.messages.count ?? 0
                let newState = DuelState.decode(data)
                if let newState, newState.messages.count > previous, let last = newState.messages.last,
                   last.player == me, let phrase = QuickChat.text(for: last.phraseID) {
                    match.message = "\(GKLocalPlayer.local.displayName): \(phrase)"
                } else {
                    match.message = String(localized: "\(GKLocalPlayer.local.displayName) played. Your turn!")
                }
                try await match.endTurn(withNextParticipants: [opponent], turnTimeout: GKTurnTimeoutDefault, match: data)
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Gives up: the opponent wins.
    func forfeit(_ id: String) async {
        guard let match = matches[id], let me = localIndex(in: match), match.participants.count == 2 else { return }
        do {
            if isLocalTurn(match) {
                let opponent = match.participants[1 - me]
                try await match.participantQuitInTurn(
                    with: .quit, nextParticipants: [opponent], turnTimeout: GKTurnTimeoutDefault,
                    match: match.matchData ?? Data()
                )
            } else {
                try await match.participantQuitOutOfTurn(with: .quit)
            }
            onFinished?(id, .loss)
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
    }

    /// Removes a finished duel from the list.
    func remove(_ id: String) async {
        guard let match = matches[id] else { return }
        try? await match.remove()
        await refresh()
    }

    /// The opponent left: the local player wins, which ends the match.
    private func claimWin(_ id: String, me: Int) async {
        guard let match = matches[id], claiming.insert(id).inserted else { return }
        defer { claiming.remove(id) }
        for (index, participant) in match.participants.enumerated() where participant.matchOutcome == .none {
            participant.matchOutcome = index == me ? .won : .quit
        }
        try? await match.endMatchInTurn(withMatch: match.matchData ?? Data())
        onFinished?(id, .win)
    }

    // MARK: - Turn events

    fileprivate func handleTurnEvent(matchID: String, didBecomeActive: Bool) {
        Task {
            await refresh()
            if didBecomeActive {
                pendingMatchID = matchID
            }
        }
    }

    fileprivate func handleWantsToQuit(matchID: String) {
        Task { await forfeit(matchID) }
    }

    // MARK: - Helpers

    private func summary(for match: GKTurnBasedMatch) -> Summary? {
        guard match.participants.count == 2, let me = localIndex(in: match) else { return nil }
        let state = DuelState.decode(match.matchData)
        let opponent = match.participants[1 - me]
        let opponentQuit = opponent.matchOutcome == .quit || opponent.matchOutcome == .timeExpired
            || opponent.status == .declined
        let status: Summary.Status
        if match.status == .ended {
            status = .finished(state?.outcome)
        } else if isLocalTurn(match) {
            status = .yourTurn
        } else {
            status = .theirTurn
        }
        if opponentQuit, isLocalTurn(match), match.status != .ended {
            let id = match.matchID
            Task { await claimWin(id, me: me) }
        }
        return Summary(
            id: match.matchID,
            me: me,
            opponentName: opponentName(in: match, me: me),
            state: state,
            status: status,
            lastChange: match.participants.compactMap(\.lastTurnDate).max() ?? match.creationDate,
            opponentQuit: opponentQuit
        )
    }

    /// A turn whose rounds are all played but that never went on (the app
    /// was closed on the summary) is passed on now.
    private func passFinishedTurns() {
        for duel in duels where duel.status == .yourTurn && duel.id != activeMatchID {
            guard let state = duel.state, state.nextRound(for: duel.me) == nil,
                  state.turn(player: duel.me, round: 0) != nil
            else { continue }
            update(duel.id, state: state, isTurnComplete: true)
        }
    }

    private func countFinishedDuels() {
        for duel in duels {
            guard case .finished(let outcome) = duel.status else { continue }
            if let outcome {
                onFinished?(duel.id, Self.result(outcome, me: duel.me))
            } else if duel.opponentQuit {
                onFinished?(duel.id, .win)
            } else if let match = matches[duel.id], match.participants.count == 2,
                      match.participants[duel.me].matchOutcome == .quit {
                onFinished?(duel.id, .loss)
            }
        }
    }

    private func setOutcomes(_ outcome: DuelState.Outcome, in match: GKTurnBasedMatch) {
        for (index, participant) in match.participants.enumerated() {
            switch outcome {
            case .draw: participant.matchOutcome = .tied
            case .won(let winner): participant.matchOutcome = index == winner ? .won : .lost
            }
        }
    }

    private static func result(_ outcome: DuelState.Outcome, me: Int) -> ChallengeRecords.DuelResult {
        switch outcome {
        case .draw: .draw
        case .won(let winner): winner == me ? .win : .loss
        }
    }

    private func localIndex(in match: GKTurnBasedMatch) -> Int? {
        let localID = GKLocalPlayer.local.gamePlayerID
        return match.participants.firstIndex { $0.player?.gamePlayerID == localID }
    }

    private func isLocalTurn(_ match: GKTurnBasedMatch) -> Bool {
        match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID
    }

    private func opponentName(in match: GKTurnBasedMatch, me: Int) -> String? {
        guard match.participants.count > 1 - me else { return nil }
        return match.participants[1 - me].player?.displayName
    }

    /// Your turn first, then waiting, then finished; newest first in each.
    private static func order(_ a: Summary, _ b: Summary) -> Bool {
        func rank(_ status: Summary.Status) -> Int {
            switch status {
            case .yourTurn: 0
            case .theirTurn: 1
            case .finished: 2
            }
        }
        if rank(a.status) != rank(b.status) {
            return rank(a.status) < rank(b.status)
        }
        return (a.lastChange ?? .distantPast) > (b.lastChange ?? .distantPast)
    }

    /// Game Center's turn events. GameKit may call these on any thread, so
    /// only the match ID crosses over to the main actor.
    private final class Listener: NSObject, GKLocalPlayerListener, @unchecked Sendable {
        weak var center: DuelCenter?

        init(center: DuelCenter) {
            self.center = center
        }

        nonisolated func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
            let id = match.matchID
            Task { @MainActor [weak center] in
                center?.handleTurnEvent(matchID: id, didBecomeActive: didBecomeActive)
            }
        }

        nonisolated func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
            let id = match.matchID
            Task { @MainActor [weak center] in
                center?.handleTurnEvent(matchID: id, didBecomeActive: false)
            }
        }

        nonisolated func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
            let id = match.matchID
            Task { @MainActor [weak center] in
                center?.handleWantsToQuit(matchID: id)
            }
        }
    }

    private final class MatchmakerDelegate: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
        nonisolated func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
            MainActor.assumeIsolated {
                viewController.dismiss(animated: true)
            }
        }

        nonisolated func turnBasedMatchmakerViewController(
            _ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: any Error
        ) {
            MainActor.assumeIsolated {
                viewController.dismiss(animated: true)
            }
        }
    }
}
