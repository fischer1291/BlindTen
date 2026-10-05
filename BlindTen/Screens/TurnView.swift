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
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task(id: engine.timeoutDeadline) {
            await autoStopWhenOverdue()
        }
    }

    private var readyPhase: some View {
        VStack(spacing: 32) {
            Text(engine.currentPlayer?.name ?? "")
                .font(.title2)
            Text("Stop at \(TimeFormat.seconds(engine.target))")
                .font(.system(size: 44, weight: .bold))
                .monospacedDigit()
            TouchTimerView(accessibilityLabel: String(localized: "Start")) { timestamp in
                state.engine?.start(at: timestamp)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .background(.tint, in: RoundedRectangle(cornerRadius: 32))
            .overlay {
                Text("START")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(.white)
                    .allowsHitTesting(false)
            }
        }
        .padding()
    }

    private var blindPhase: some View {
        ZStack {
            Color.black
            TouchTimerView(accessibilityLabel: String(localized: "Stop")) { timestamp in
                state.engine?.stop(at: timestamp)
            }
            Text("Tap anywhere to stop")
                .font(.headline)
                .foregroundStyle(.gray)
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
                state.engine?.autoStopIfOverdue(now: now)
                return
            }
            try? await Task.sleep(for: .seconds(deadline - now))
        }
    }
}
