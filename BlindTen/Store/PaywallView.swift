import SwiftUI

/// SPEC.md: shown only when tapping a locked mode card (or from Settings),
/// never on launch. Shows a 5-second looping preview of the mode.
struct PaywallView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    /// The locked mode that was tapped, if any.
    let mode: ModeKind?

    private var purchases: PurchaseManager { state.purchases }
    private var previewMode: ModeKind { mode ?? .liarsClock }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ModePreview(kind: previewMode)
                        .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text(previewMode.title)
                            .font(Theme.display(36))
                            .foregroundStyle(Theme.primaryText)
                        Text(previewMode.rules)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Party Pack")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Theme.accent)
                        Benefit(symbol: "square.grid.2x2.fill", text: "All 8 game modes")
                        Benefit(symbol: "person.3.fill", text: "Unlimited players")
                        Benefit(symbol: "rectangle.stack.badge.plus", text: "Your own house-rule cards")
                        Benefit(symbol: "tv", text: "Big reveals on the TV via AirPlay")
                        Benefit(symbol: "checkmark.seal.fill", text: "One-time purchase. No subscription, no ads.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))

                    buyButton

                    Button("Restore Purchases") {
                        Task { await purchases.restore() }
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)

                    if let issue = purchases.issue {
                        IssueText(issue: issue)
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: purchases.isPartyPackUnlocked) { _, unlocked in
            guard unlocked else { return }
            if let mode {
                state.selectedMode = mode
            }
            dismiss()
        }
    }

    @ViewBuilder
    private var buyButton: some View {
        Button {
            Task { await purchases.purchase() }
        } label: {
            if purchases.isPurchasing {
                ProgressView()
                    .tint(Theme.onAccent)
            } else if let product = purchases.product {
                Text("Unlock for \(product.displayPrice)")
            } else {
                Text("Unlock the Party Pack")
            }
        }
        .buttonStyle(.primary)
        .disabled(purchases.isPurchasing)
    }
}

private struct Benefit: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        Label {
            Text(text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
        }
    }
}

/// Purchase problems in plain words.
struct IssueText: View {
    let issue: PurchaseManager.Issue

    var body: some View {
        Group {
            switch issue {
            case .failed:
                Text("Something went wrong. Please try again.")
            case .pending:
                Text("Your purchase is waiting for approval.")
            case .unavailable:
                Text("The store is not available right now.")
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.late)
        .multilineTextAlignment(.center)
    }
}

/// A small phone mock-up that loops a 5-second demo of a mode.
struct ModePreview: View {
    let kind: ModeKind
    static let loop: TimeInterval = 5

    var body: some View {
        TimelineView(.animation) { _ in
            let t = ProcessInfo.processInfo.systemUptime.truncatingRemainder(dividingBy: Self.loop)
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.black)
                scene(at: t)
                    .padding(14)
                RoundedRectangle(cornerRadius: 30)
                    .strokeBorder(Theme.secondaryText.opacity(0.5), lineWidth: 3)
            }
            .frame(width: 190, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 30))
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func scene(at t: TimeInterval) -> some View {
        switch kind {
        case .classic, .randomTarget:
            let targets: [TimeInterval] = kind == .classic ? [10] : [13.37, 6.42, 17.05]
            let target = targets[Int(t / Self.loop * Double(targets.count)) % targets.count]
            turnScene(at: t, target: target)
        case .showdown:
            VStack(spacing: 4) {
                half(started: t > 0.8, done: t > 3.6)
                    .rotationEffect(.degrees(180))
                half(started: t > 1.1, done: t > 3.9)
            }
        case .distraction:
            let beeps: [TimeInterval] = [0.4, 1.7, 2.1, 3.5, 4.4]
            let active = beeps.contains { t >= $0 && t < $0 + 0.25 }
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 64))
                .foregroundStyle(active ? Theme.accent : Color(white: 0.25))
                .scaleEffect(active ? 1.2 : 1)
        case .liarsClock:
            Text(verbatim: max(0, 10 - t * 2.6).formatted(.number.precision(.fractionLength(1))))
                .font(Theme.display(64))
                .monospacedDigit()
                .foregroundStyle(Color(white: 0.6))
        case .heartbeat:
            let phase = t.truncatingRemainder(dividingBy: 0.9)
            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.late)
                .scaleEffect(phase < 0.15 ? 1.25 : 1)
        case .elimination:
            let remaining = max(1, 4 - Int(t / 1.25))
            VStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    Text(Avatar.pool[index])
                        .font(.system(size: 40))
                        .opacity(index < remaining ? 1 : 0.15)
                }
            }
        case .teams:
            HStack(alignment: .bottom, spacing: 24) {
                teamBar(team: 0, height: 40 + 30 * min(t, 3))
                teamBar(team: 1, height: 40 + 22 * min(t, 3))
            }
        }
    }

    private func turnScene(at t: TimeInterval, target: TimeInterval) -> some View {
        Group {
            if t < 1.2 {
                VStack(spacing: 10) {
                    Text("Stop at \(TimeFormat.seconds(target))")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.primaryText)
                    Text("START")
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 90)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18))
                }
            } else if t < 3.8 {
                Color.black
            } else {
                VStack(spacing: 6) {
                    Text("\(TimeFormat.seconds(target + 0.03)) s")
                        .font(Theme.display(34))
                        .foregroundStyle(Theme.primaryText)
                    Text("DEAD ON")
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func half(started: Bool, done: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(done ? Color(white: 0.15) : (started ? Color.black : Theme.accent))
            .overlay {
                if !started {
                    Text("START")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.onAccent)
                }
            }
    }

    private func teamBar(team: Int, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Theme.color(forTeam: team))
            .frame(width: 44, height: height)
    }
}
