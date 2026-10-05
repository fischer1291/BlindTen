import SwiftUI
import UIKit

/// The 1080 × 1920 story-sized results image (SPEC.md "Share card").
struct ShareCardView: View {
    static let size = CGSize(width: 1080, height: 1920)
    let summary: ShareSummary

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 40)
            winnerBlock
            Spacer(minLength: 40)
            bestTimes
            Spacer(minLength: 40)
            footer
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 100)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.black)
        .foregroundStyle(Theme.primaryText)
    }

    private var header: some View {
        VStack(spacing: 24) {
            LogoMark()
                .frame(width: 220, height: 220)
            Text("BLIND TEN")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .tracking(8)
            Text(summary.mode.title)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
    }

    @ViewBuilder
    private var winnerBlock: some View {
        if summary.isTeamGame {
            if let team = summary.winningTeam {
                Text("Team \(team + 1) wins!")
                    .font(.system(size: 110, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.color(forTeam: team))
            } else {
                Text("It's a tie!")
                    .font(.system(size: 110, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
        } else if let winner = summary.winner {
            VStack(spacing: 12) {
                Text("Winner")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                Text(winner.emoji)
                    .font(.system(size: 160))
                Text(winner.name)
                    .font(.system(size: 120, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
        }
    }

    private var bestTimes: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Best times")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
            ForEach(Array(summary.rows.prefix(8).enumerated()), id: \.element.player.id) { index, row in
                HStack(spacing: 24) {
                    Text(verbatim: "\(index + 1)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(index == 0 ? Theme.accent : Theme.secondaryText)
                        .frame(width: 56, alignment: .leading)
                    Text(verbatim: "\(row.player.emoji) \(row.player.name)")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer()
                    if let best = row.best {
                        Text("\(TimeFormat.seconds(best.displayedStopped)) s")
                            .font(.system(size: 50, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                        Text(verbatim: TimeFormat.signedDeviation(best.displayedDeviation))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.color(for: best.direction))
                            .frame(width: 150, alignment: .trailing)
                    } else {
                        Text(verbatim: "–")
                            .font(.system(size: 50, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
        .padding(48)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 48))
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text("Think you can stop at exactly 10?")
                .font(.system(size: 46, weight: .bold, design: .rounded))
            Text("Blind Ten on the App Store")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .multilineTextAlignment(.center)
    }
}

enum ShareCardRenderer {
    /// Renders the card at exactly 1080 × 1920 pixels.
    @MainActor
    static func image(for summary: ShareSummary) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(summary: summary))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(ShareCardView.size)
        return renderer.uiImage
    }
}
