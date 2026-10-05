import SwiftUI

struct PlayersView: View {
    @Environment(AppState.self) private var state
    @AppStorage(SoundSettings.enabledKey) private var soundEnabled = true
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
                    .font(.title3)
                    .focused($nameFieldFocused)
                    .submitLabel(.next)
                    .autocorrectionDisabled()
                    .onSubmit { addPlayer() }
                    .disabled(isFull)
                ForEach(state.roster) { player in
                    HStack(spacing: 12) {
                        Text(player.emoji)
                            .font(.title)
                        Text(player.name)
                            .font(.title3.weight(.semibold))
                    }
                }
                .onDelete { state.roster.remove(atOffsets: $0) }
                .onMove { state.roster.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Players")
            } footer: {
                Text("Up to \(AppState.maxFreePlayers) players. Drag to reorder.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Stepper("Rounds: \(rounds)", value: $rounds, in: 1...10)
                    .font(.title3)
                Toggle("Sound", isOn: $soundEnabled)
                    .font(.title3)
            } footer: {
                Text("Sounds follow the silent switch.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Button("Start game") { startGame() }
                    .buttonStyle(.primary)
                    .disabled(state.roster.count < GameEngine.minPlayers)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                Stepper("Players: \(quickPlayCount)", value: $quickPlayCount, in: GameEngine.minPlayers...AppState.maxFreePlayers)
                    .font(.title3)
                    .listRowBackground(Theme.surface)
                Button("Quick play") { quickPlay() }
                    .buttonStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
            } header: {
                Text("Quick play")
            } footer: {
                Text("Skip names and play as Player 1, Player 2, …")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
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
