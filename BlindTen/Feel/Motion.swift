import SwiftUI

/// Shared motion: one spring for the whole app, and a staggered entrance
/// for screens that build up block by block. Both respect Reduce Motion.
enum Motion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.75)
}

/// Fades and slides a block in, a little after the block before it.
struct Entrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    let isVisible: Bool

    func body(content: Content) -> some View {
        let shown = isVisible || reduceMotion
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .animation(reduceMotion ? nil : Motion.spring.delay(Double(index) * 0.05), value: isVisible)
    }
}

extension View {
    func entrance(_ index: Int, isVisible: Bool) -> some View {
        modifier(Entrance(index: index, isVisible: isVisible))
    }
}
