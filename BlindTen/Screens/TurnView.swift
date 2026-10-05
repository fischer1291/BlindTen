import SwiftUI

/// Target + START, then the blind phase with a whole-screen STOP surface.
struct TurnView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine

    var body: some View {
        Group {
            if let startedAt = engine.lanes.first?.startedAt {
                BlindPhaseView(effect: engine.blindEffect, target: engine.target, startedAt: startedAt) { timestamp in
                    state.stop(at: timestamp)
                    state.feel.touch()
                }
            } else {
                readyPhase
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // A thumb sliding in from an edge must not open Control Center and void the turn.
        .defersSystemGestures(on: .all)
        .onAppear {
            state.feel.warmUp()
            ScreenBrightness.maximize()
        }
        .onDisappear { ScreenBrightness.restore() }
        .modifier(AutoStop(deadline: engine.timeoutDeadline))
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
                state.engine?.start(at: timestamp)
                state.feel.touch()
            }
            .frame(maxWidth: .infinity, maxHeight: 360)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 40))
            .overlay {
                Text("START")
                    .font(Theme.display(72))
                    .foregroundStyle(Theme.onAccent)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .padding(24)
    }
}

/// The blind phase: whole-screen STOP plus the mode's effect.
///
/// It opens with a single "GO" flash so the start is unmistakable. After
/// that nothing changes at a regular one-second rhythm.
struct BlindPhaseView: View {
    @Environment(AppState.self) private var state
    let effect: BlindEffect
    let target: TimeInterval
    /// START touch timestamp (system uptime).
    let startedAt: TimeInterval
    var onStop: (TimeInterval) -> Void

    @State private var goFlash = 0.8

    var body: some View {
        ZStack {
            Color.black
            TouchTimerView(accessibilityLabel: String(localized: "Stop")) { timestamp in
                onStop(timestamp)
            }
            effectOverlay
                .allowsHitTesting(false)
            Theme.accent
                .opacity(goFlash)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(.easeOut(duration: 0.3)) {
                goFlash = 0
            }
        }
        .task(id: startedAt) {
            await runEffect()
        }
        .onDisappear {
            state.feel.stopHeartbeat()
        }
    }

    @ViewBuilder
    private var effectOverlay: some View {
        switch effect {
        case .liarsClock(let rate):
            TimelineView(.animation) { _ in
                let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
                let remaining = LiarsClock.displayedRemaining(elapsed: elapsed, target: target, rate: rate)
                Text(verbatim: remaining.formatted(.number.precision(.fractionLength(1))))
                    .font(Theme.display(120))
                    .monospacedDigit()
                    .foregroundStyle(Color(white: 0.6))
            }
        case .dark, .distraction, .heartbeat:
            Text("Tap anywhere to stop")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(white: 0.35))
        }
    }

    private func runEffect() async {
        switch effect {
        case .distraction(let beepTimes):
            for time in beepTimes {
                let wait = startedAt + time - ProcessInfo.processInfo.systemUptime
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                }
                guard !Task.isCancelled else { return }
                state.feel.beep()
            }
        case .heartbeat(let interval):
            state.feel.startHeartbeat(interval: interval)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
            }
            state.feel.stopHeartbeat()
        case .dark, .liarsClock:
            break
        }
    }
}

/// One-shot wait until the earliest auto-stop deadline (target × 3).
/// Not a ticking timer.
struct AutoStop: ViewModifier {
    @Environment(AppState.self) private var state
    let deadline: TimeInterval?

    func body(content: Content) -> some View {
        content.task(id: deadline) {
            guard let deadline else { return }
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
}
