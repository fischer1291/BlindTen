import SwiftUI

/// The Blind Ten stopwatch mark, drawn with the same geometry as the app
/// icon and launch image (Tools/generate_icon.py, 1024 × 1024 design space).
struct LogoMark: View {
    /// Hand rotation, clockwise from 12 o'clock.
    var handAngle: Angle = .zero
    var showsHand = true
    var color: Color = Theme.accent

    // Keep in sync with Tools/generate_icon.py.
    static let center = CGPoint(x: 512, y: 560)
    static let ringRadius: CGFloat = 296      // midway between 262 and 330
    static let ringWidth: CGFloat = 68
    /// The gap ("blind" part) between these angles, 0° = right, clockwise.
    static let gapDegrees: ClosedRange<Double> = 100...150
    static let handWidth: CGFloat = 34
    static let handLength: CGFloat = 212
    static let hubRadius: CGFloat = 46

    /// True while the hand points into the gap, where it is hidden.
    static func handIsInGap(_ angle: Angle) -> Bool {
        // The hand's angle from 12 o'clock maps to the ring's angle minus 90°.
        var ringDegrees = (angle.degrees - 90).truncatingRemainder(dividingBy: 360)
        if ringDegrees < 0 { ringDegrees += 360 }
        return gapDegrees.contains(ringDegrees)
    }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 1024
            let origin = CGPoint(x: (size.width - 1024 * scale) / 2, y: (size.height - 1024 * scale) / 2)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
            }
            let shading = GraphicsContext.Shading.color(color)
            let center = Self.center

            // Ring, from the end of the gap all the way round to its start.
            var ring = Path()
            var degrees = Self.gapDegrees.upperBound
            ring.move(to: point(center.x + Self.ringRadius * cos(degrees * .pi / 180), center.y + Self.ringRadius * sin(degrees * .pi / 180)))
            while degrees < Self.gapDegrees.lowerBound + 360 {
                degrees = min(degrees + 2, Self.gapDegrees.lowerBound + 360)
                ring.addLine(to: point(center.x + Self.ringRadius * cos(degrees * .pi / 180), center.y + Self.ringRadius * sin(degrees * .pi / 180)))
            }
            context.stroke(ring, with: shading, style: StrokeStyle(lineWidth: Self.ringWidth * scale, lineCap: .butt, lineJoin: .round))

            // Crown: stem and cap.
            context.fill(Path(CGRect(origin: point(460, 138), size: CGSize(width: 104 * scale, height: 102 * scale))), with: shading)
            context.fill(Path(CGRect(origin: point(422, 100), size: CGSize(width: 180 * scale, height: 50 * scale))), with: shading)

            // Hand.
            if showsHand {
                var hand = context
                hand.translateBy(x: point(center.x, center.y).x, y: point(center.x, center.y).y)
                hand.rotate(by: handAngle)
                let rect = CGRect(
                    x: -Self.handWidth / 2 * scale,
                    y: -Self.handLength * scale,
                    width: Self.handWidth * scale,
                    height: Self.handLength * scale
                )
                hand.fill(Path(rect), with: shading)
            }

            // Hub.
            let hub = Self.hubRadius
            context.fill(Path(ellipseIn: CGRect(origin: point(center.x - hub, center.y - hub), size: CGSize(width: 2 * hub * scale, height: 2 * hub * scale))), with: shading)
        }
        .accessibilityHidden(true)
    }
}
