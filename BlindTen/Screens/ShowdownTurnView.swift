import SwiftUI

/// Showdown: two players at once on a split screen. Each half is its own
/// START/STOP surface timed from `UITouch.timestamp`. The top half is
/// upside down for the player across the table.
struct ShowdownTurnView: View {
    @Environment(AppState.self) private var state
    let engine: GameEngine

    var body: some View {
        VStack(spacing: 0) {
            half(lane: 0)
                .rotationEffect(.degrees(180))
            // A wide black bar so the two yellow START halves read as separate buttons.
            Rectangle()
                .fill(Color.black)
                .frame(height: 16)
            half(lane: 1)
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            state.feel.warmUp()
            ScreenBrightness.maximize()
        }
        .onDisappear { ScreenBrightness.restore() }
        .modifier(AutoStop(deadline: engine.timeoutDeadline))
    }

    @ViewBuilder
    private func half(lane index: Int) -> some View {
        if engine.lanes.indices.contains(index) {
            let lane = engine.lanes[index]
            let name = engine.player(withID: lane.playerID)?.name ?? ""
            Group {
                if lane.isDone {
                    VStack(spacing: 8) {
                        Text(verbatim: name)
                            .font(.title.weight(.heavy))
                        Text("Done. Waiting for the other player…")
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Color(white: 0.45))
                    .padding()
                } else if lane.isRunning {
                    ZStack {
                        Color.black
                        TouchTimerView(accessibilityLabel: String(localized: "Stop")) { timestamp in
                            state.feel.touch()
                            state.stop(lane: index, at: timestamp)
                        }
                        Text(verbatim: name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(white: 0.3))
                            .allowsHitTesting(false)
                    }
                } else {
                    ZStack {
                        Theme.accent
                        TouchTimerView(accessibilityLabel: String(localized: "Start")) { timestamp in
                            state.feel.touch()
                            state.engine?.start(lane: index, at: timestamp)
                        }
                        VStack(spacing: 6) {
                            Text(verbatim: name)
                                .font(.title.weight(.heavy))
                            Text("Stop at \(TimeFormat.seconds(engine.target))")
                                .font(.title2.weight(.bold))
                                .monospacedDigit()
                            Text("START")
                                .font(Theme.display(56))
                        }
                        .foregroundStyle(Theme.onAccent)
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
