import SwiftUI

/// The host phone: the main screen (mirrored to the TV with AirPlay, or the
/// TV scene with the Party Pack) plus the host's controls. When the host
/// plays too, the phone switches to START and the blind phase for the
/// host's own turns and back to the main screen right after.
struct HostSessionView: View {
    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    let host: SessionHost

    @AppStorage(SessionIdentity.hostPlaysKey) private var hostPlays = true
    @AppStorage(SessionIdentity.nameKey) private var name = ""
    @AppStorage(SessionIdentity.emojiKey) private var emoji = Avatar.pool[0]
    @State private var showsPaywall = false
    @State private var confirmsEnd = false

    /// The host player's screen while it needs the host's hands, else nil.
    private var hostTurnScreen: ClientTurn.Screen? {
        guard let screen = host.localScreen, screen.needsPlayer else { return nil }
        return screen
    }

    var body: some View {
        Group {
            if let player = host.localPlayer, let screen = hostTurnScreen {
                hostTurn(player, screen)
            } else {
                mainScreen
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.primaryText)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            syncHostPlayer()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            ScreenBrightness.restore()
        }
        .onChange(of: hostPlays) { syncHostPlayer() }
        .onChange(of: name) { syncHostPlayer() }
        .onChange(of: emoji) { syncHostPlayer() }
        .onChange(of: hostTurnScreen == nil) { _, isMainScreen in
            if isMainScreen {
                ScreenBrightness.restore()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // SPEC.md: leaving the app mid-turn voids the turn and it is replayed.
            if newPhase != .active {
                host.localVoidIfRunning()
            }
        }
        .sheet(isPresented: $showsPaywall) {
            PaywallView(mode: .liarsClock)
        }
        .confirmationDialog("End the session for everyone?", isPresented: $confirmsEnd, titleVisibility: .visible) {
            Button("End session", role: .destructive) {
                state.endHostedSession()
            }
        }
    }

    private func syncHostPlayer() {
        guard !host.isGameRunning else { return }
        host.setLocalPlayer(hostPlays ? SessionIdentity.player(name: name, emoji: emoji) : nil)
    }

    // MARK: - Host's own turn

    @ViewBuilder
    private func hostTurn(_ player: Player, _ screen: ClientTurn.Screen) -> some View {
        switch screen {
        case .yourTurn:
            SessionYourTurnView(player: player, opponent: opponent(of: player)) {
                host.localReady()
            }
        case .waitingForOpponent:
            VStack(spacing: 18) {
                Text("Ready!")
                    .font(Theme.display(48))
                Text("Waiting for your opponent…")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .start(let target):
            SessionStartView(target: target) { timestamp in
                host.localStart(at: timestamp)
                state.feel.touch()
            }
        case .blind(let startedAt):
            SessionBlindView(
                effect: host.snapshot?.effect ?? .dark,
                target: host.snapshot?.target ?? GameEngine.classicTarget,
                startedAt: startedAt
            ) { timestamp in
                if host.localStop(at: timestamp) {
                    state.feel.touch()
                }
            }
        case .connecting, .lobby, .stopped, .drumroll, .result, .watching, .roundResults, .finished:
            mainScreen
        }
    }

    private func opponent(of player: Player) -> Player? {
        guard let snapshot = host.snapshot, snapshot.turnPlayerIDs.count == 2 else { return nil }
        guard let id = snapshot.turnPlayerIDs.first(where: { $0 != player.id }) else { return nil }
        return snapshot.player(id)
    }

    // MARK: - Main screen

    private var mainScreen: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height
            Group {
                if isWide {
                    HStack(spacing: 16) {
                        board
                        controls
                            .frame(width: min(340, proxy.size.width * 0.35))
                    }
                } else {
                    VStack(spacing: 16) {
                        board
                        controls
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var board: some View {
        if state.isTVConnected {
            VStack(spacing: 12) {
                Image(systemName: "tv")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("Showing on the TV")
                    .font(Theme.display(28))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        } else {
            ScaledBoard {
                TVView()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let engine = state.engine {
                    gameControls(engine)
                } else {
                    lobbyControls
                }
                Button("End session") {
                    confirmsEnd = true
                }
                .buttonStyle(.secondary)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Lobby

    @ViewBuilder
    private var lobbyControls: some View {
        @Bindable var state = state
        @Bindable var host = host
        Text("Session \(host.code)")
            .font(.title2.weight(.heavy))
        Text("Players join with \"Join a session\" on their iPhone. Share this screen with AirPlay so everyone sees the game.")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

        Picker("Mode", selection: $state.selectedMode) {
            ForEach(ModeKind.allCases.filter { PartyPack.canPlay($0, unlocked: state.isPartyPackUnlocked) }) { kind in
                Text(kind.title).tag(kind)
            }
        }
        .pickerStyle(.menu)
        .font(.title3.weight(.bold))
        if !state.isPartyPackUnlocked {
            Button("More modes with the Party Pack") {
                showsPaywall = true
            }
            .font(.subheadline.weight(.bold))
        }
        if state.selectedMode != .elimination {
            Stepper("Rounds: \(host.rounds)", value: $host.rounds, in: 1...10)
                .font(.headline)
        }

        hostPlayerSettings

        Button {
            host.startGame()
        } label: {
            Text("Start game")
        }
        .buttonStyle(.primary)
        .disabled(!host.canStart)
        if host.players.count < GameEngine.minPlayers {
            Text("Waiting for at least 2 players…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    /// "I'm playing too" with the host's name and avatar.
    @ViewBuilder
    private var hostPlayerSettings: some View {
        Toggle("I'm playing too", isOn: $hostPlays)
            .font(.headline)
        if hostPlays {
            TextField("Your name", text: $name)
                .font(.title3.weight(.bold))
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Avatar.pool, id: \.self) { option in
                        Button {
                            emoji = option
                        } label: {
                            Text(verbatim: option)
                                .font(.system(size: 28))
                                .frame(width: 48, height: 48)
                                .background(
                                    option == emoji ? Theme.accent : Theme.surface,
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(option == emoji ? .isSelected : [])
                    }
                }
            }
            if host.localPlayer == nil {
                Text("Enter your name to join your own game.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    // MARK: - Game

    @ViewBuilder
    private func gameControls(_ engine: GameEngine) -> some View {
        HStack {
            Text(engine.mode.kind.title)
                .foregroundStyle(Theme.accent)
            Spacer()
            Text("Round \(engine.round) of \(engine.rounds)")
                .foregroundStyle(Theme.secondaryText)
        }
        .font(.headline.weight(.heavy))

        switch engine.phase {
        case .handoff, .ready, .running:
            Text(verbatim: engine.currentPlayers.map { "\($0.emoji) \($0.name)" }.joined(separator: "  vs  "))
                .font(.title2.weight(.heavy))
            Text("Playing on their phone")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            let missing = host.missingPlayers
            if !missing.isEmpty {
                Text("\(missing.map(\.name).formatted(.list(type: .and))) lost the connection.")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.late)
                Button("Skip turn") {
                    host.skipMissingPlayers()
                }
                .buttonStyle(.secondary)
            }
        case .reveal:
            Button("Next") {
                host.next()
            }
            .buttonStyle(.primary)
            .disabled(!host.isRevealLanded)
        case .roundResults:
            Button {
                host.next()
            } label: {
                if engine.isFinalRound {
                    Text("Final results")
                } else {
                    Text("Next round")
                }
            }
            .buttonStyle(.primary)
        case .finished:
            Button("Rematch") {
                host.rematch()
            }
            .buttonStyle(.primary)
            Button("Back to lobby") {
                host.backToLobby()
            }
            .buttonStyle(.secondary)
        }
    }
}
