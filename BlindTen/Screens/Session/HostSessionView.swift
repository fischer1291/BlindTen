import SwiftUI

/// The host phone: the main screen (mirrored to the TV with AirPlay, or the
/// TV scene with the Party Pack) plus the host's controls.
struct HostSessionView: View {
    @Environment(AppState.self) private var state
    let host: SessionHost

    @State private var showsPaywall = false
    @State private var confirmsEnd = false

    var body: some View {
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
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(Theme.primaryText)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(isPresented: $showsPaywall) {
            PaywallView(mode: .liarsClock)
        }
        .confirmationDialog("End the session for everyone?", isPresented: $confirmsEnd, titleVisibility: .visible) {
            Button("End session", role: .destructive) {
                state.endHostedSession()
            }
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
