import SwiftUI

struct PlayersView: View {
    @Environment(AppState.self) private var state
    @State private var newName = ""
    @State private var rounds = GameEngine.defaultRounds
    @State private var quickPlayCount = GameEngine.minPlayers
    @FocusState private var nameFieldFocused: Bool

    private static let maxNameLength = 20
    private var isFull: Bool { state.roster.count >= AppState.maxFreePlayers }

    var body: some View {
        List {
            Section {
                TextField("Add player", text: $newName)
                    .focused($nameFieldFocused)
                    .submitLabel(.next)
                    .autocorrectionDisabled()
                    .onSubmit { addPlayer() }
                    .disabled(isFull)
                ForEach(state.roster) { player in
                    HStack(spacing: 12) {
                        Text(player.emoji)
                        Text(player.name)
                    }
                    .font(.title3)
                }
                .onDelete { state.roster.remove(atOffsets: $0) }
                .onMove { state.roster.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Players")
            } footer: {
                Text("Up to \(AppState.maxFreePlayers) players. Drag to reorder.")
            }

            Section {
                Stepper("Rounds: \(rounds)", value: $rounds, in: 1...10)
            }

            Section {
                Button("Start game") { startGame() }
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .disabled(state.roster.count < GameEngine.minPlayers)
            }

            Section {
                Stepper("Players: \(quickPlayCount)", value: $quickPlayCount, in: GameEngine.minPlayers...AppState.maxFreePlayers)
                Button("Quick play") { quickPlay() }
                    .frame(maxWidth: .infinity, minHeight: 44)
            } header: {
                Text("Quick play")
            } footer: {
                Text("Skip names and play as Player 1, Player 2, …")
            }
        }
        .navigationTitle("Blind Ten")
        .toolbar {
            EditButton()
        }
    }

    private func addPlayer() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isFull else { return }
        let emoji = Avatar.next(excluding: state.roster.map(\.emoji))
        state.roster.append(Player(name: String(name.prefix(Self.maxNameLength)), emoji: emoji))
        newName = ""
        nameFieldFocused = true
    }

    private func startGame() {
        try? state.startGame(players: state.roster, rounds: rounds)
    }

    private func quickPlay() {
        var players: [Player] = []
        for number in 1...quickPlayCount {
            let emoji = Avatar.next(excluding: players.map(\.emoji))
            players.append(Player(name: String(localized: "Player \(number)"), emoji: emoji))
        }
        try? state.startGame(players: players, rounds: rounds)
    }
}
