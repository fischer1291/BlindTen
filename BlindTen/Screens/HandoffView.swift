import SwiftUI

/// "Pass the phone to Mia" (or "Mia vs Ben" in Showdown). Tap anywhere to continue.
struct HandoffView: View {
    @Environment(AppState.self) private var state
    @State private var confirmingEndGame = false
    let engine: GameEngine

    private var isDuel: Bool { engine.currentPlayers.count == 2 }

    var body: some View {
        Button {
            state.engine?.beginTurn()
        } label: {
            VStack(spacing: 20) {
                header
                Spacer()
                if isDuel {
                    duel
                } else {
                    single
                }
                Spacer()
                Text(isDuel ? LocalizedStringKey("Tap anywhere when you're both ready") : LocalizedStringKey("Tap anywhere when ready"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            Button("End game", role: .destructive) {
                confirmingEndGame = true
            }
            .font(.headline)
            .padding()
        }
        .confirmationDialog("End this game?", isPresented: $confirmingEndGame, titleVisibility: .visible) {
            Button("End game", role: .destructive) {
                state.newGame()
            }
        }
        .onAppear { state.feel.warmUp() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(engine.mode.kind.title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.accent)
            if engine.mode.eliminatesRoundLoser {
                Text("Round \(engine.round) · \(engine.activePlayers.count) players left")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text("Round \(engine.round) of \(engine.rounds)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var single: some View {
        VStack(spacing: 20) {
            Text("Pass the phone to")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Text(engine.currentPlayer?.emoji ?? "")
                .font(.system(size: 120))
            Text(engine.currentPlayer?.name ?? "")
                .font(Theme.display(72))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.4)
            if let player = engine.currentPlayer, let team = engine.team(of: player.id) {
                TeamName(team: team)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.color(forTeam: team))
            }
        }
    }

    private var duel: some View {
        let players = engine.currentPlayers
        return VStack(spacing: 16) {
            Text("Showdown")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                if index == 1 {
                    Text("vs")
                        .font(Theme.display(40))
                        .foregroundStyle(Theme.accent)
                }
                HStack(spacing: 12) {
                    Text(player.emoji)
                        .font(.system(size: 64))
                    Text(player.name)
                        .font(Theme.display(52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
            }
            Text("Hold the phone between you. Each thumb on its own half.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}
