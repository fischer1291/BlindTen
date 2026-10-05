import SwiftUI
import UIKit

/// A touch surface that reports the hardware timestamp of each touch-down.
///
/// `UITouch.timestamp` is seconds of system uptime at the moment the finger
/// landed, so START and STOP come from the same clock as
/// `ProcessInfo.systemUptime`, free of SwiftUI action latency.
struct TouchTimerView: UIViewRepresentable {
    /// VoiceOver label, e.g. "Start" or "Stop".
    var accessibilityLabel: String
    /// Called on touch-down with `UITouch.timestamp`.
    var onTouch: (TimeInterval) -> Void

    func makeUIView(context: Context) -> TouchSurface {
        let surface = TouchSurface()
        surface.backgroundColor = .clear
        surface.isMultipleTouchEnabled = false
        surface.isAccessibilityElement = true
        surface.accessibilityTraits = [.button, .allowsDirectInteraction]
        return surface
    }

    func updateUIView(_ surface: TouchSurface, context: Context) {
        surface.onTouch = onTouch
        surface.accessibilityLabel = accessibilityLabel
    }

    final class TouchSurface: UIView {
        var onTouch: ((TimeInterval) -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            onTouch?(touch.timestamp)
        }

        /// VoiceOver double-tap. There is no UITouch, so use the same uptime clock.
        override func accessibilityActivate() -> Bool {
            onTouch?(ProcessInfo.processInfo.systemUptime)
            return true
        }
    }
}
