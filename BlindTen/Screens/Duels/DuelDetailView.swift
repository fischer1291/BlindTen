import SwiftUI

/// One duel: the rounds so far, whose turn it is, and the button to play.
struct DuelDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let matchID: String
    @State private var session: ChallengeSession?
    @State private var confirmsForfeit = false

    var body: some View {
        let duel = state.duels.summary(id: matchID)
        ScrollView {
            VStack(spacing: 20) {
                if let duel {
                    header(duel)
                    rounds(duel)
                    actions(duel)
                } else {
                    ProgressView()
                        .padding(.top, 40)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Duel")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await state.duels.refresh() }
        .fullScreenCover(item: $session, onDismiss: {
            Task { await state.duels.refresh() }
        }, content: { session in
            ChallengeRunView(session: session) {}
        })
        .confirmationDialog("Give up this duel?", isPresented: $confirmsForfeit, titleVisibility: .visible) {
            Button("Give up", role: .destructive) {
                Task {
                    await state.duels.forfeit(matchID)
                    dismiss()
                }
            }
        } message: {
            Text("Your opponent wins the duel.")
        }
    }

    private func header(_ duel: DuelCenter.Summary) -> some View {
        VStack(spacing: 8) {
            Text(verbatim: duel.opponentName ?? String(localized: "Opponent"))
                .font(.title.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let kind = duel.state?.kind {
                Text(kind == .classic ? LocalizedStringKey("Classic 10 s") : LocalizedStringKey("Random Target"))
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(verbatim: "\(duel.wins.mine) – \(duel.wins.theirs)")
                .font(Theme.display(72))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
            DuelStatusText(duel: duel)
                .font(.title3.weight(.heavy))
        }
        .foregroundStyle(Theme.primaryText)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func rounds(_ duel: DuelCenter.Summary) -> some View {
        if let duelState = duel.state {
            VStack(spacing: 0) {
                ForEach(0..<DuelState.rounds, id: \.self) { round in
                    RoundRow(duel: duelState, round: round, me: duel.me, opponentName: duel.opponentName)
                    if round < DuelState.rounds - 1 {
                        Divider().overlay(Theme.secondaryText.opacity(0.3))
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    @ViewBuilder
    private func actions(_ duel: DuelCenter.Summary) -> some View {
        VStack(spacing: 12) {
            switch duel.status {
            case .yourTurn:
                Button("Play your turn") {
                    if let plan = state.duels.plan(for: matchID) {
                        session = state.makeDuelSession(plan)
                    }
                }
                .buttonStyle(.primary)
                forfeitButton
            case .theirTurn:
                Text("You'll get a notification when it's your turn.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                forfeitButton
            case .finished:
                Button("Remove from list") {
                    Task {
                        await state.duels.remove(matchID)
                        dismiss()
                    }
                }
                .buttonStyle(.secondary)
            }
        }
    }

    private var forfeitButton: some View {
        Button("Give up") {
            confirmsForfeit = true
        }
        .font(.headline)
        .foregroundStyle(Theme.secondaryText)
        .padding(.vertical, 12)
    }
}

/// One round: target, both results (the opponent's hidden until you played
/// the round too) and who won it.
private struct RoundRow: View {
    let duel: DuelState
    let round: Int
    let me: Int
    let opponentName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Round \(round + 1)")
                    .font(.headline.weight(.heavy))
                Spacer()
                Text("Stop at \(TimeFormat.seconds(duel.target(round: round)))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()
            }
            HStack(alignment: .top) {
                cell(title: Text("You"), player: me)
                Spacer()
                cell(title: Text(verbatim: opponentName ?? String(localized: "Opponent")), player: 1 - me)
            }
        }
        .padding(16)
        .foregroundStyle(Theme.primaryText)
    }

    private func cell(title: Text, player: Int) -> some View {
        let won: Bool = {
            if case .won(let winner) = duel.result(round: round) { return winner == player }
            return false
        }()
        return VStack(alignment: .leading, spacing: 2) {
            title
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            value(for: player)
                .font(.title3.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(won ? Theme.accent : Theme.primaryText)
        }
    }

    private func value(for player: Int) -> Text {
        guard let stopped = duel.stopped(player: player, round: round) else {
            return Text(verbatim: "–")
        }
        guard duel.isVisible(player: player, round: round, to: me) else {
            return Text("Played · hidden")
        }
        switch Scoring.outcome(elapsed: stopped, target: duel.target(round: round)) {
        case .scored:
            return Text("\(TimeFormat.signedDeviation(stopped - duel.target(round: round))) s off")
        case .misfire:
            return Text("Too eager!")
        case .timeout:
            return Text("Time's up")
        }
    }
}
