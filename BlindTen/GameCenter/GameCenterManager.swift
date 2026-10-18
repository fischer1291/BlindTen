@preconcurrency import GameKit
import Observation
import UIKit

/// Game Center sign-in, score submission, achievements and the leaderboard UI.
/// Everything fails quietly: challenges stay playable without Game Center.
@MainActor
@Observable
final class GameCenterManager {
    private(set) var isAuthenticated = false
    private(set) var playerName: String?
    /// True once Game Center answered, signed in or not.
    private(set) var hasAnswered = false

    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var showsLogin = false
    /// Apple's sign-in screen, held back until the player opens a Game Center feature.
    @ObservationIgnored private var pendingLogin: UIViewController?
    @ObservationIgnored private let dismissDelegate = DismissDelegate()
    /// Called once when the player is signed in.
    @ObservationIgnored var onAuthenticated: (() -> Void)?

    /// Signs in to Game Center. With `showLogin` false (at launch) Apple's
    /// sign-in screen is held back until a Game Center feature is opened;
    /// a player who is already signed in is signed in silently.
    func authenticate(showLogin: Bool = true) {
        guard !ScreenshotMode.isActive else { return }
        if showLogin {
            showsLogin = true
            if let pendingLogin {
                self.pendingLogin = nil
                TopViewController.find()?.present(pendingLogin, animated: true)
            }
        }
        guard !didStart else { return }
        didStart = true
        GKLocalPlayer.local.authenticateHandler = Self.makeAuthenticateHandler { viewController in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if let viewController {
                        if self.showsLogin {
                            TopViewController.find()?.present(viewController, animated: true)
                        } else {
                            self.pendingLogin = viewController
                        }
                    }
                    self.refresh()
                }
            }
        }
    }

    /// GameKit may call the handler on any thread, so it must not be
    /// formed in main-actor code (Swift 6 would trap on the isolation check).
    private nonisolated static func makeAuthenticateHandler(
        _ onAnswer: @escaping @Sendable (UIViewController?) -> Void
    ) -> @Sendable (UIViewController?, (any Error)?) -> Void {
        { viewController, _ in onAnswer(viewController) }
    }

    private func refresh() {
        let player = GKLocalPlayer.local
        let wasAuthenticated = isAuthenticated
        isAuthenticated = player.isAuthenticated
        if isAuthenticated, !wasAuthenticated {
            onAuthenticated?()
        }
        playerName = player.isAuthenticated ? player.displayName : nil
        hasAnswered = true
    }

    func submit(_ score: Int, to leaderboardIDs: [String]) {
        guard isAuthenticated, !leaderboardIDs.isEmpty else { return }
        Task {
            try? await GKLeaderboard.submitScore(
                score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: leaderboardIDs
            )
        }
    }

    func unlock(_ achievements: [AchievementID]) {
        guard isAuthenticated, !achievements.isEmpty else { return }
        let reports = achievements.map { id in
            let achievement = GKAchievement(identifier: id.identifier)
            achievement.percentComplete = 100
            achievement.showsCompletionBanner = true
            return achievement
        }
        Task {
            try? await GKAchievement.report(reports)
        }
    }

    /// Opens Game Center on a leaderboard, or on the dashboard without one.
    func showLeaderboard(_ leaderboardID: String? = nil) {
        guard isAuthenticated else { return }
        let viewController: GKGameCenterViewController
        if let leaderboardID {
            let timeScope: GKLeaderboard.TimeScope = LeaderboardID.isRecurring(leaderboardID) ? .today : .allTime
            // SPEC.md: friends first; Apple's screen switches to everyone.
            viewController = GKGameCenterViewController(
                leaderboardID: leaderboardID, playerScope: .friendsOnly, timeScope: timeScope
            )
        } else {
            viewController = GKGameCenterViewController(state: .leaderboards)
        }
        viewController.gameCenterDelegate = dismissDelegate
        TopViewController.find()?.present(viewController, animated: true)
    }

    func showAchievements() {
        guard isAuthenticated else { return }
        let viewController = GKGameCenterViewController(state: .achievements)
        viewController.gameCenterDelegate = dismissDelegate
        TopViewController.find()?.present(viewController, animated: true)
    }

    private final class DismissDelegate: NSObject, GKGameCenterControllerDelegate {
        nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            MainActor.assumeIsolated {
                gameCenterViewController.dismiss(animated: true)
            }
        }
    }
}

/// The view controller to present Game Center's own screens from.
@MainActor
enum TopViewController {
    static func find() -> UIViewController? {
        let scenes: [UIWindowScene] = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let appScenes = scenes.filter { $0.session.role == .windowApplication }
        let active = appScenes.first { $0.activationState == .foregroundActive }
        let scene: UIWindowScene? = active ?? appScenes.first
        let window: UIWindow? = scene?.keyWindow ?? scene?.windows.first
        var top: UIViewController? = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
