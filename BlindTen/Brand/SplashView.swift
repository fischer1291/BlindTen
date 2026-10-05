import SwiftUI

/// Animated splash that continues from the static launch screen: the same
/// logo at the same size and position. The hand sweeps once around the dial,
/// disappears while it passes the gap (the "blind" part), lands on 12 with a
/// pulse, the wordmark fades in, and the splash hands over to Home.
/// A tap skips it; Reduce Motion replaces the sweep with a short fade.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = ProcessInfo.processInfo.systemUptime
    @State private var wordmarkOpacity = 0.0
    @State private var leaving = false
    @State private var finished = false

    /// Size of the launch image (LaunchLogo, 200 pt).
    static let logoSize: CGFloat = 200
    static let sweepDuration: TimeInterval = 0.9
    static let pulseDuration: TimeInterval = 0.45

    var body: some View {
        ZStack {
            Color.black
            TimelineView(.animation(minimumInterval: nil, paused: leaving)) { _ in
                let elapsed = ProcessInfo.processInfo.systemUptime - start
                let angle = Self.handAngle(elapsed: elapsed, reduceMotion: reduceMotion)
                let pulse = Self.pulseProgress(elapsed: elapsed, reduceMotion: reduceMotion)
                ZStack {
                    if let pulse {
                        Circle()
                            .stroke(Theme.accent, lineWidth: 6)
                            .frame(width: Self.logoSize * 0.6, height: Self.logoSize * 0.6)
                            .scaleEffect(1 + pulse * 0.9)
                            .opacity(1 - pulse)
                            .offset(y: Self.logoSize * (560 - 512) / 1024)
                    }
                    LogoMark(handAngle: angle, showsHand: !LogoMark.handIsInGap(angle))
                        .frame(width: Self.logoSize, height: Self.logoSize)
                }
            }
            Text("BLIND TEN")
                .font(Theme.display(40))
                .tracking(4)
                .foregroundStyle(Theme.primaryText)
                .opacity(wordmarkOpacity)
                .offset(y: Self.logoSize * 0.72)
        }
        .scaleEffect(leaving ? 1.4 : 1)
        .opacity(leaving ? 0 : 1)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task { await run() }
        .accessibilityElement()
        .accessibilityLabel(Text("Blind Ten"))
    }

    /// Ease-out sweep from 12 back to 12.
    static func handAngle(elapsed: TimeInterval, reduceMotion: Bool) -> Angle {
        guard !reduceMotion else { return .zero }
        let progress = min(max(elapsed / sweepDuration, 0), 1)
        let eased = 1 - pow(1 - progress, 3)
        return .degrees(eased * 360)
    }

    /// 0…1 while the landing pulse runs, nil otherwise.
    static func pulseProgress(elapsed: TimeInterval, reduceMotion: Bool) -> Double? {
        guard !reduceMotion else { return nil }
        let progress = (elapsed - sweepDuration) / pulseDuration
        return (0..<1).contains(progress) ? progress : nil
    }

    private func run() async {
        start = ProcessInfo.processInfo.systemUptime
        withAnimation(.easeOut(duration: 0.4).delay(reduceMotion ? 0 : 0.35)) {
            wordmarkOpacity = 1
        }
        let hold: TimeInterval = reduceMotion ? 0.5 : Self.sweepDuration + Self.pulseDuration + 0.15
        try? await Task.sleep(for: .seconds(hold))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        withAnimation(.easeIn(duration: 0.3)) {
            leaving = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            onFinish()
        }
    }
}
