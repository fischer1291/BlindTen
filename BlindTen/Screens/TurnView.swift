import SwiftUI

/// Target + START, then the blind phase with a whole-screen STOP surface.
///
/// Nothing on this screen changes on a timer during the blind phase.
struct TurnView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine

    var body: some View {
        Group {
            if case .running = engine.phase {
                blindPhase
            } else {
                readyPhase
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { ScreenBrightness.maximize() }
        .onDisappear { ScreenBrightness.restore() }
        .task(id: engine.timeoutDeadline) {
            await autoStopWhenOverdue()
        }
    }

    private var readyPhase: some View {
        VStack(spacing: 28) {
            Text(engine.currentPlayer?.name ?? "")
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("Stop at \(TimeFormat.seconds(engine.target))")
                .font(Theme.display(52))
                .monospacedDigit()
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            TouchTimerView(accessibilityLabel: String(localized: "Start")) { timestamp in
                state.feel.touch()
                state.engine?.start(at: timestamp)
            }
            .frame(maxWidth: .infinity, maxHeight: 360)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 40))
            .overlay {
                Text("START")
                    .font(Theme.display(72))
                    .foregroundStyle(Theme.onAccent)
                    .allowsHitTesting(false)
            }
        }
        .padding(24)
    }

    private var blindPhase: some View {
        ZStack {
            Color.black
            TouchTimerView(accessibilityLabel: String(localized: "Stop")) { timestamp in
                state.feel.touch()
                state.stop(at: timestamp)
            }
            Text("Tap anywhere to stop")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(white: 0.35))
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    /// One-shot wait until the auto-stop deadline (target × 3). Not a ticking timer.
    private func autoStopWhenOverdue() async {
        guard let deadline = engine.timeoutDeadline else { return }
        while !Task.isCancelled {
            let now = ProcessInfo.processInfo.systemUptime
            if now >= deadline {
                state.autoStopIfOverdue(now: now)
                return
            }
            try? await Task.sleep(for: .seconds(deadline - now))
        }
    }
}
