import SwiftUI

/// Full-screen confetti burst for the DEAD ON moment.
struct ConfettiView: View {
    /// `ProcessInfo.systemUptime` when the burst started.
    let startTime: TimeInterval
    @State private var particles = ConfettiParticle.burst(count: 160)
    /// Every piece has fallen off screen; stop redrawing.
    @State private var isDone = false

    private static let palette: [Color] = [
        Theme.accent, Theme.early, Theme.late, .white,
        Color(red: 0.25, green: 0.95, blue: 0.55), Color(red: 1.0, green: 0.45, blue: 0.85),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: isDone)) { _ in
            Canvas { context, size in
                let elapsed = ProcessInfo.processInfo.systemUptime - startTime
                for particle in particles {
                    let point = particle.position(at: elapsed, in: size)
                    guard point.y < size.height + 30 else { continue }
                    var piece = context
                    piece.translateBy(x: point.x, y: point.y)
                    piece.rotate(by: .radians(particle.spin * elapsed))
                    // Squash horizontally to fake a flutter in 3D.
                    piece.scaleBy(x: cos(particle.flutter * elapsed), y: 1)
                    let rect = CGRect(
                        x: -particle.width / 2, y: -particle.height / 2,
                        width: particle.width, height: particle.height
                    )
                    let color = Self.palette[particle.colorIndex % Self.palette.count]
                    piece.fill(Path(rect), with: .color(color))
                }
            }
        }
        .opacity(isDone ? 0 : 1)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: startTime) {
            let wait = startTime + Self.lifetime - ProcessInfo.processInfo.systemUptime
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }
            isDone = true
        }
    }

    /// Long enough for the slowest piece to fall past the bottom edge.
    private static let lifetime: TimeInterval = 4
}

/// One piece of confetti, in units relative to the screen size.
struct ConfettiParticle: Sendable {
    /// Start position as a fraction of width/height.
    var x: Double
    var y: Double
    /// Velocity in screen fractions per second.
    var vx: Double
    var vy: Double
    var spin: Double
    var flutter: Double
    var width: Double
    var height: Double
    var colorIndex: Int

    static let gravity = 0.9

    static func burst(count: Int) -> [ConfettiParticle] {
        (0..<count).map { index in
            ConfettiParticle(
                x: .random(in: 0...1),
                y: .random(in: -0.15...0.05),
                vx: .random(in: -0.25...0.25),
                vy: .random(in: -0.35...0.15),
                spin: .random(in: -9...9),
                flutter: .random(in: 4...12),
                width: .random(in: 7...12),
                height: .random(in: 10...18),
                colorIndex: index
            )
        }
    }

    func position(at time: TimeInterval, in size: CGSize) -> CGPoint {
        let t = max(0, time)
        let px = x + vx * t
        let py = y + vy * t + 0.5 * Self.gravity * t * t
        return CGPoint(x: px * size.width, y: py * size.height)
    }
}
