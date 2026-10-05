#if DEBUG
import SwiftUI
import UIKit

/// The Party Pack's 1024 × 1024 promotional image for App Store Connect.
/// Debug only: rendered by screenshot mode, never shipped or translated.
struct PartyPackArtView: View {
    static let size = CGSize(width: 1024, height: 1024)

    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Theme.accent.opacity(0.35), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 520
            )
            VStack(spacing: 36) {
                LogoMark()
                    .frame(width: 400, height: 400)
                Text(verbatim: "PARTY PACK")
                    .font(.system(size: 108, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(Theme.accent)
                Text(verbatim: "All modes · Unlimited players · TV mode")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

enum PartyPackArtRenderer {
    @MainActor
    static func image() -> UIImage? {
        let renderer = ImageRenderer(content: PartyPackArtView())
        renderer.scale = 1
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(PartyPackArtView.size)
        return renderer.uiImage
    }
}
#endif
