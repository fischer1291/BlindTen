import SwiftUI

/// Shows a 1920×1080 TV layout scaled down to fit, e.g. on the host phone.
struct ScaledBoard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 1920, proxy.size.height / 1080)
            content
                .frame(width: 1920, height: 1080)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
    }
}

/// Emoji avatars drifting slowly around their area. Each one moves on its
/// own odd period, so nothing pulses at a regular one-second rhythm.
struct DriftingAvatars: View {
    let emojis: [String]
    var size: CGFloat = 56

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                let time = ProcessInfo.processInfo.systemUptime
                ZStack {
                    ForEach(Array(emojis.enumerated()), id: \.offset) { index, emoji in
                        let point = Drift.position(index: index, time: time)
                        Text(verbatim: emoji)
                            .font(.system(size: size))
                            .scaleEffect(Drift.scale(index: index, time: time))
                            .position(
                                x: proxy.size.width * point.x,
                                y: proxy.size.height * point.y
                            )
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Positions for `DriftingAvatars`, kept out of the view so they can be tested.
enum Drift {
    private static let golden = 0.618_033_988_75

    /// A point in 0.1…0.9 of the area. Periods grow with the golden ratio,
    /// so no two avatars move in step and none repeats every second.
    static func position(index: Int, time: TimeInterval) -> CGPoint {
        let seed = Double(index) + 1
        let fx = 0.11 + 0.07 * (seed * golden).truncatingRemainder(dividingBy: 1)
        let fy = 0.09 + 0.06 * (seed * golden * golden).truncatingRemainder(dividingBy: 1)
        let x = 0.5 + 0.4 * sin(time * fx + seed * 2.1)
        let y = 0.5 + 0.4 * sin(time * fy + seed * 1.3)
        return CGPoint(x: x, y: y)
    }

    static func scale(index: Int, time: TimeInterval) -> Double {
        let seed = Double(index) + 1
        return 1 + 0.08 * sin(time * (0.37 + 0.05 * seed) + seed)
    }
}

/// The session's lobby on the main screen: how to join and who is in.
struct SessionLobbyBoard: View {
    @Environment(AppState.self) private var state
    let host: SessionHost

    var body: some View {
        HStack(spacing: 80) {
            VStack(alignment: .leading, spacing: 36) {
                HStack(spacing: 24) {
                    LogoMark()
                        .frame(width: 120, height: 120)
                    Text("BLIND TEN")
                        .font(Theme.display(72))
                        .tracking(6)
                }
                Text("Join on your iPhone")
                    .font(Theme.display(64))
                VStack(alignment: .leading, spacing: 16) {
                    Text("1. Open Blind Ten")
                    Text("2. Tap \"Join a session\"")
                    Text("3. Pick this session:")
                }
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                Text(verbatim: host.code)
                    .font(.system(size: 120))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 32))
                HStack(spacing: 16) {
                    Text(state.selectedMode.title)
                        .foregroundStyle(Theme.accent)
                    Text(verbatim: "·")
                    Text("\(host.rounds) rounds")
                }
                .font(.system(size: 40, weight: .heavy, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 24) {
                Text("\(host.players.count) players")
                    .font(Theme.display(56))
                ZStack {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(Theme.surface)
                    if host.players.isEmpty {
                        Text("Waiting for players…")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    } else {
                        DriftingAvatars(emojis: host.players.map(\.emoji), size: 90)
                            .padding(60)
                    }
                }
                .frame(height: 440)
                Text(verbatim: host.players.map(\.name).joined(separator: " · "))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 760)
        }
        .padding(90)
    }
}
