import SwiftUI
import UIKit

/// SPEC.md v1.1 TV scene: on an AirPlay or cabled display the TV shows the
/// leaderboard and big reveals while the phone stays the controller.
@MainActor
enum ExternalDisplay {
    /// Set at launch so the TV scene shares the phone's game state.
    static weak var state: AppState?
}

/// Routes external-display scenes to `ExternalDisplaySceneDelegate`;
/// everything else keeps SwiftUI's default handling.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            configuration.delegateClass = ExternalDisplaySceneDelegate.self
        }
        return configuration
    }
}

final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Without a window the system mirrors the phone, which is the free behavior.
        guard let windowScene = scene as? UIWindowScene,
              let state = ExternalDisplay.state,
              PartyPack.canUseTVScene(unlocked: state.isPartyPackUnlocked)
        else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: TVView()
                .environment(state)
                .preferredColorScheme(.dark)
        )
        window.isHidden = false
        self.window = window
        state.isTVConnected = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if window != nil {
            ExternalDisplay.state?.isTVConnected = false
        }
        window = nil
    }
}
