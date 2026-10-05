import UIKit

/// SPEC.md Turn screen: max brightness. Restores the user's level afterwards.
@MainActor
enum ScreenBrightness {
    private static var savedBrightness: CGFloat?

    static func maximize() {
        guard let screen = currentScreen else { return }
        if savedBrightness == nil {
            savedBrightness = screen.brightness
        }
        screen.brightness = 1.0
    }

    static func restore() {
        guard let saved = savedBrightness, let screen = currentScreen else { return }
        screen.brightness = saved
        savedBrightness = nil
    }

    private static var currentScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen
    }
}
