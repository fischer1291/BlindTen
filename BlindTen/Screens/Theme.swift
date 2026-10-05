import SwiftUI

/// Dark, high-contrast palette and type, readable from 1 m in a dark bar.
enum Theme {
    static let background = Color.black
    static let surface = Color(white: 0.11)
    /// Signal yellow. Black text on it, or it on black, is well above 7:1.
    static let accent = Color(red: 1.0, green: 0.82, blue: 0.0)
    static let onAccent = Color.black
    static let primaryText = Color.white
    /// Light gray, still above 9:1 on black.
    static let secondaryText = Color(white: 0.72)
    /// SPEC.md: blue = too early.
    static let early = Color(red: 0.33, green: 0.65, blue: 1.0)
    /// SPEC.md: red = too late.
    static let late = Color(red: 1.0, green: 0.33, blue: 0.33)

    static func color(for tier: Tier) -> Color {
        switch tier {
        case .deadOn: accent
        case .sharp: Color(red: 0.25, green: 0.95, blue: 0.55)
        case .close: Color(red: 0.7, green: 0.93, blue: 0.35)
        case .meh: primaryText
        case .off: Color(red: 1.0, green: 0.62, blue: 0.25)
        case .lostInTime: late
        }
    }

    static func color(for direction: TimingDirection) -> Color {
        switch direction {
        case .early: early
        case .late: late
        case .exact: accent
        }
    }

    /// Big, heavy, rounded display type.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}

/// Full-width yellow button with a large tap target.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration, isPrimary: true)
    }
}

/// Full-width outlined button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration, isPrimary: false)
    }
}

private struct ButtonBody: View {
    @Environment(\.isEnabled) private var isEnabled
    let configuration: ButtonStyleConfiguration
    let isPrimary: Bool

    var body: some View {
        configuration.label
            .font(.title2.weight(.heavy))
            .foregroundStyle(isPrimary ? Theme.onAccent : Theme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isPrimary ? Theme.accent : Theme.surface)
            }
            .overlay {
                if !isPrimary {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Theme.primaryText.opacity(0.5), lineWidth: 2)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
            .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
