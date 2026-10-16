@preconcurrency import GameKit
import Observation
import UIKit

/// A real-time match that is ready to play: who hosts and how to talk.
@MainActor
struct LiveMatchConnection {
    let isHost: Bool
    /// The elected host (the local player when `isHost`).
    let hostPeer: TransportPeer
    /// The local player's Game Center name.
    let localName: String
    let makeTransport: @MainActor (@escaping TransportEventHandler) -> GameCenterMatchTransport
}

/// Matchmaking for Live Match (SPEC.md M9): quick match with random players
/// or invites to friends, both through Apple's matchmaking screen. The game
/// itself runs on the regular session host and client.
@MainActor
@Observable
final class LiveMatchCenter {
    private(set) var lastError: String?
    /// Called when a match is ready.
    @ObservationIgnored var onConnection: ((LiveMatchConnection) -> Void)?

    @ObservationIgnored private let matchmakerDelegate = MatchmakerDelegate()
    @ObservationIgnored private var listener: InviteListener?

    init() {
        matchmakerDelegate.onMatch = { [weak self] match in
            self?.connect(match)
        }
        matchmakerDelegate.onError = { [weak self] message in
            self?.lastError = message
        }
    }

    /// Starts listening for invites. Call once Game Center is signed in.
    func start() {
        guard listener == nil else { return }
        let listener = InviteListener(center: self)
        GKLocalPlayer.local.register(listener)
        self.listener = listener
    }

    /// Opens Apple's matchmaking: random players, or friends to invite.
    func findMatch(inviteFriends: Bool) {
        let request = GKMatchRequest()
        request.minPlayers = LiveMatchRules.minPlayers
        request.maxPlayers = LiveMatchRules.maxPlayers
        request.inviteMessage = String(localized: "Can you feel 10 seconds? Join my Blind Ten live match!")
        guard let viewController = GKMatchmakerViewController(matchRequest: request) else { return }
        viewController.matchmakingMode = inviteFriends ? .inviteOnly : .automatchOnly
        present(viewController)
    }

    fileprivate func accept(_ invite: GKInvite) {
        guard let viewController = GKMatchmakerViewController(invite: invite) else { return }
        present(viewController)
    }

    private func present(_ viewController: GKMatchmakerViewController) {
        lastError = nil
        viewController.matchmakerDelegate = matchmakerDelegate
        TopViewController.find()?.present(viewController, animated: true)
    }

    private func connect(_ match: GKMatch) {
        let local = GKLocalPlayer.local
        let ids = [local.gamePlayerID] + match.players.map(\.gamePlayerID)
        guard let hostID = LiveMatchRules.host(among: ids) else { return }
        let isHost = hostID == local.gamePlayerID
        let hostPeer = isHost
            ? TransportPeer(id: local.gamePlayerID, displayName: local.displayName)
            : match.players.first { $0.gamePlayerID == hostID }.map(GameCenterMatchTransport.peer)
                ?? TransportPeer(id: hostID, displayName: "")
        let guestHost: TransportPeer? = isHost ? nil : hostPeer
        nonisolated(unsafe) let match = match
        onConnection?(LiveMatchConnection(
            isHost: isHost,
            hostPeer: hostPeer,
            localName: local.displayName,
            makeTransport: { handler in
                GameCenterMatchTransport(match: match, host: guestHost, onEvent: handler)
            }
        ))
    }

    private final class MatchmakerDelegate: NSObject, GKMatchmakerViewControllerDelegate {
        var onMatch: (@MainActor (GKMatch) -> Void)?
        var onError: (@MainActor (String) -> Void)?

        nonisolated func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            MainActor.assumeIsolated {
                viewController.dismiss(animated: true)
            }
        }

        nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: any Error) {
            let message = error.localizedDescription
            MainActor.assumeIsolated {
                viewController.dismiss(animated: true)
                onError?(message)
            }
        }

        nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            MainActor.assumeIsolated {
                viewController.dismiss(animated: true)
                onMatch?(match)
            }
        }
    }

    /// Invites accepted in Game Center or from a notification.
    private final class InviteListener: NSObject, GKLocalPlayerListener, @unchecked Sendable {
        weak var center: LiveMatchCenter?

        init(center: LiveMatchCenter) {
            self.center = center
        }

        nonisolated func player(_ player: GKPlayer, didAccept invite: GKInvite) {
            nonisolated(unsafe) let invite = invite
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    self?.center?.accept(invite)
                }
            }
        }
    }
}
