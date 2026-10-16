import SwiftUI

/// Online duels: start one against a random opponent or a friend, and see
/// whose turn it is in each running duel and the history (SPEC.md M8).
struct DuelListView: View {
    @Environment(AppState.self) private var state
    @State private var kind: ChallengeKind = .classic
    @State private var isSearching = false
    @State private var openDuel: String?

    var body: some View {
        let duels = state.duels
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Best of 3 against a friend or a random opponent. Each of you plays when you like; Game Center tells you when it's your turn.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if state.gameCenter.isAuthenticated {
                    newDuelSection
                    record
                    section("Your turn", duels.duels.filter { $0.status == .yourTurn })
                    section("Their turn", duels.duels.filter { $0.status == .theirTurn })
                    section("Finished", duels.duels.filter { if case .finished = $0.status { true } else { false } })
                    if duels.duels.isEmpty, !duels.isLoading {
                        Text("No duels yet. Start one above!")
                            .font(.headline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                } else {
                    Text(state.gameCenter.hasAnswered
                         ? LocalizedStringKey("Online duels use Game Center. Sign in to Game Center in the Settings app to play.")
                         : LocalizedStringKey("Connecting to Game Center…"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let error = duels.lastError {
                    Text(verbatim: error)
                        .font(.footnote)
                        .foregroundStyle(Theme.late)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .animation(Motion.spring, value: duels.duels.map(\.id))
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Online Duel")
        .refreshable { await duels.refresh() }
        .navigationDestination(item: $openDuel) { id in
            DuelDetailView(matchID: id)
        }
        .onDisappear { state.duels.isListVisible = false }
        .onAppear {
            state.duels.isListVisible = true
            state.gameCenter.authenticate()
            Task { await duels.refresh() }
            openPendingDuel()
        }
        .onChange(of: duels.pendingMatchID) { _, _ in
            openPendingDuel()
        }
    }

    private func openPendingDuel() {
        guard let id = state.duels.pendingMatchID else { return }
        state.duels.pendingMatchID = nil
        openDuel = id
    }

    private var newDuelSection: some View {
        VStack(spacing: 12) {
            Picker("Duel type", selection: $kind) {
                Text("Classic 10 s").tag(ChallengeKind.classic)
                Text("Random Target").tag(ChallengeKind.randomTarget)
            }
            .pickerStyle(.segmented)
            Button {
                isSearching = true
                Task {
                    if let id = await state.duels.findRandomOpponent(kind: kind) {
                        openDuel = id
                    }
                    isSearching = false
                }
            } label: {
                if isSearching {
                    ProgressView()
                        .tint(Theme.onAccent)
                } else {
                    Label("Random opponent", systemImage: "globe")
                }
            }
            .buttonStyle(.primary)
            .disabled(isSearching)
            Button {
                state.duels.inviteFriend(kind: kind)
            } label: {
                Label("Invite a friend", systemImage: "person.badge.plus")
            }
            .buttonStyle(.secondary)
        }
    }

    private var record: some View {
        let records = state.challengeRecords
        return HStack(spacing: 12) {
            RecordTile(title: "Won", value: records.duelWins, color: Theme.accent)
            RecordTile(title: "Lost", value: records.duelLosses, color: Theme.late)
            RecordTile(title: "Draw", value: records.duelDraws, color: Theme.secondaryText)
        }
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, _ duels: [DuelCenter.Summary]) -> some View {
        if !duels.isEmpty {
            Text(title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.primaryText)
                .padding(.top, 8)
            ForEach(duels) { duel in
                Button {
                    openDuel = duel.id
                } label: {
                    DuelRow(duel: duel)
                }
                .buttonStyle(.pressable)
            }
        }
    }
}

private struct RecordTile: View {
    let title: LocalizedStringKey
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(verbatim: "\(value)")
                .font(Theme.display(36))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct DuelRow: View {
    let duel: DuelCenter.Summary

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: duel.opponentName ?? String(localized: "Opponent"))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                DuelStatusText(duel: duel)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Text(verbatim: "\(duel.wins.mine) – \(duel.wins.theirs)")
                .font(Theme.display(28))
                .monospacedDigit()
                .foregroundStyle(Theme.primaryText)
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .background(
            duel.status == .yourTurn ? Theme.accent.opacity(0.18) : Theme.surface,
            in: RoundedRectangle(cornerRadius: 18)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

/// "Your turn", "Waiting for Sam", "You won" and so on.
struct DuelStatusText: View {
    let duel: DuelCenter.Summary

    var body: some View {
        switch duel.status {
        case .yourTurn:
            Text("Your turn")
                .foregroundStyle(Theme.accent)
        case .theirTurn:
            if let name = duel.opponentName {
                Text("Waiting for \(name)")
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text("Looking for an opponent…")
                    .foregroundStyle(Theme.secondaryText)
            }
        case .finished(let outcome):
            switch outcome {
            case .won(let winner)?:
                Text(winner == duel.me ? LocalizedStringKey("You won") : LocalizedStringKey("You lost"))
                    .foregroundStyle(winner == duel.me ? Theme.accent : Theme.late)
            case .draw?:
                Text("Draw")
                    .foregroundStyle(Theme.secondaryText)
            case nil:
                Text(duel.opponentQuit ? LocalizedStringKey("Opponent gave up. You won") : LocalizedStringKey("Duel ended"))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
