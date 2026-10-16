import SwiftUI

/// A Live Match on every player's phone (SPEC.md M9): all players play each
/// turn at once with the same target, the timer starts by itself at a random
/// moment, and the results land on every phone together. The elected host
/// runs the game on the regular session host and plays like everyone else.
struct LiveMatchView: View {
    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    let match: AppState.LiveMatch

    @State private var confirmsLeave = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(Theme.primaryText)
            .overlay(alignment: .top) {
                if chatContext != nil {
                    QuickChatBubbles(feed: chat, player: player(withID:), me: me?.id)
                        .padding(.top, 8)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let chatContext {
                    QuickChatBar(context: chatContext) { id in
                        sendReaction(id)
                    }
                    .padding(.vertical, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Motion.spring, value: chatContext)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                state.feel.prepare()
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                ScreenBrightness.restore()
            }
            .onChange(of: screen.needsPlayer) { _, needsPlayer in
                if !needsPlayer {
                    ScreenBrightness.restore()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Leaving the app mid-turn voids the turn and everyone replays it.
                if newPhase != .active {
                    voidIfRunning()
                    state.feel.stopAll()
                }
            }
            .confirmationDialog("Leave the live match?", isPresented: $confirmsLeave, titleVisibility: .visible) {
                Button("Leave", role: .destructive) {
                    state.leaveLiveMatch()
                }
            } message: {
                if isHost {
                    Text("You are hosting. The match ends for everyone.")
                }
            }
    }

    // MARK: - Host or guest

    private var isHost: Bool {
        if case .host = match { true } else { false }
    }

    private var snapshot: SessionSnapshot? {
        switch match {
        case .host(let host): host.snapshot
        case .client(let client): client.snapshot
        }
    }

    private var me: Player? {
        switch match {
        case .host(let host): host.localPlayer
        case .client(let client): client.player
        }
    }

    private var screen: ClientTurn.Screen {
        switch match {
        case .host(let host): host.localScreen ?? .connecting
        case .client(let client): client.screen
        }
    }

    /// The host is gone; a live match cannot continue without it.
    private var lostHost: Bool {
        guard case .client(let client) = match else { return false }
        switch client.status {
        case .reconnecting, .rejected: return true
        case .browsing, .connecting, .connected: return false
        }
    }

    // MARK: - Quick chat

    private var chat: QuickChatFeed {
        switch match {
        case .host(let host): host.chat
        case .client(let client): client.chat
        }
    }

    private func sendReaction(_ id: String) {
        switch match {
        case .host(let host): host.sendReaction(id)
        case .client(let client): client.sendReaction(id)
        }
    }

    private func player(withID id: String) -> Player? {
        snapshot?.players.first { $0.player.id.uuidString == id }?.player
    }

    /// Phrases that fit the moment; nil hides the chat (START and the blind
    /// phase must stay free of distractions).
    private var chatContext: QuickChat.Context? {
        guard !lostHost else { return nil }
        switch screen {
        case .connecting, .start, .blind:
            return nil
        case .lobby:
            return .lobby
        case .yourTurn, .waitingForOpponent, .stopped, .drumroll, .watching:
            return .waiting
        case .result(let result):
            switch result.outcome {
            case .scored(.deadOn), .scored(.sharp), .scored(.close): return .goodResult
            case .scored, .misfire, .timeout: return .badResult
            }
        case .roundResults:
            return .roundOver
        case .finished:
            guard let snapshot else { return .draw }
            if let winner = snapshot.winnerID {
                return winner == me?.id ? .won : .lost
            }
            return .draw
        }
    }

    private func ready() {
        switch match {
        case .host(let host): host.localReady()
        case .client(let client): client.ready()
        }
    }

    private func start(at timestamp: TimeInterval) {
        switch match {
        case .host(let host): host.localStart(at: timestamp)
        case .client(let client): client.start(at: timestamp)
        }
    }

    private func stop(at timestamp: TimeInterval) -> Bool {
        switch match {
        case .host(let host): host.localStop(at: timestamp)
        case .client(let client): client.stop(at: timestamp)
        }
    }

    private func voidIfRunning() {
        switch match {
        case .host(let host): host.localVoidIfRunning()
        case .client(let client): client.voidIfRunning()
        }
    }

    // MARK: - Screens

    @ViewBuilder
    private var content: some View {
        if lostHost {
            message(
                title: "Connection lost",
                subtitle: "The host left the match or the connection dropped.",
                showsLeave: true
            )
        } else {
            switch screen {
            case .connecting:
                VStack(spacing: 18) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Connecting to the match…")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    leaveButton
                }
            case .lobby:
                LiveLobbyView(match: match, snapshot: snapshot, leave: { confirmsLeave = true })
            case .yourTurn:
                LiveReadyView(snapshot: snapshot, onReady: ready)
            case .waitingForOpponent:
                waitingForPlayers(title: "Ready!", ids: snapshot?.readyPlayerIDs ?? [])
            case .start(let target):
                LiveAutoStartView(target: target) { timestamp in
                    start(at: timestamp)
                    state.feel.touch()
                }
            case .blind(let startedAt):
                SessionBlindView(
                    effect: snapshot?.effect ?? .dark,
                    target: snapshot?.target ?? GameEngine.classicTarget,
                    startedAt: startedAt
                ) { timestamp in
                    if stop(at: timestamp) {
                        state.feel.touch()
                    }
                }
            case .stopped:
                waitingForPlayers(title: "Stopped!", ids: snapshot?.finishedPlayerIDs ?? [])
            case .drumroll:
                message(title: "And the times are…", subtitle: "Everyone's result lands at once.", showsLeave: false)
            case .result(let result):
                ScrollView {
                    VStack(spacing: 8) {
                        ClientResultView(result: result)
                        LiveTurnResults(snapshot: snapshot, me: me?.id)
                    }
                    .padding(.vertical, 20)
                }
            case .watching:
                message(title: "You're out", subtitle: "Cheer the others on!", showsLeave: true)
            case .roundResults, .finished:
                VStack(spacing: 0) {
                    ClientStandingsView(
                        snapshot: snapshot,
                        me: me?.id ?? UUID(),
                        isFinal: screen == .finished,
                        leave: { confirmsLeave = true }
                    )
                    if case .host(let host) = match {
                        LiveHostControls(host: host)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
    }

    private var leaveButton: some View {
        Button("Leave") {
            confirmsLeave = true
        }
        .font(.headline)
        .foregroundStyle(Theme.secondaryText)
        .padding(.vertical, 12)
    }

    private func message(title: LocalizedStringKey, subtitle: LocalizedStringKey, showsLeave: Bool) -> some View {
        VStack(spacing: 18) {
            Text(title)
                .font(Theme.display(44))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            if showsLeave {
                leaveButton
            }
        }
        .padding(24)
    }

    /// "Ready!" or "Stopped!" with who is done so far.
    private func waitingForPlayers(title: LocalizedStringKey, ids: [Player.ID]) -> some View {
        let total = snapshot?.turnPlayerIDs.count ?? 0
        return VStack(spacing: 18) {
            Text(title)
                .font(Theme.display(48))
            Text("Waiting for the others… \(ids.count) of \(total)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .monospacedDigit()
            HStack(spacing: 8) {
                ForEach(snapshot?.turnPlayerIDs ?? [], id: \.self) { id in
                    Text(verbatim: snapshot?.player(id)?.emoji ?? "")
                        .font(.system(size: 34))
                        .opacity(ids.contains(id) ? 1 : 0.3)
                        .scaleEffect(ids.contains(id) ? 1.1 : 0.9)
                        .animation(Motion.snappy, value: ids.contains(id))
                }
            }
            if case .host(let host) = match, !host.missingPlayers.isEmpty {
                Text("\(host.missingPlayers.map(\.name).formatted(.list(type: .and))) lost the connection.")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.late)
                    .multilineTextAlignment(.center)
                Button("Continue without them") {
                    host.skipMissingPlayers()
                }
                .buttonStyle(.secondary)
            }
        }
        .padding(24)
    }
}

// MARK: - Lobby

private struct LiveLobbyView: View {
    @Environment(AppState.self) private var state
    let match: AppState.LiveMatch
    let snapshot: SessionSnapshot?
    let leave: () -> Void

    private var players: [SessionPlayer] { snapshot?.players ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Live Match")
                    .font(Theme.display(40))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Players \(players.count) of \(LiveMatchRules.maxPlayers)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.secondaryText)
                        .textCase(.uppercase)
                    FlowChips(players: players)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "shuffle")
                            .frame(width: 24, alignment: .leading)
                        Text("The timer starts by itself")
                    }
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                    Text("We can't control whether someone uses a second stopwatch. So there is no START button: after everyone is ready, the timer starts at a random moment. Watch for the yellow flash and the buzz.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))

                if case .host(let host) = match {
                    LiveHostLobbyControls(host: host)
                } else {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Waiting for the host to start the game.")
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
                }

                Button("Leave", action: leave)
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}

/// The players as avatar chips, wrapping onto new lines.
private struct FlowChips: View {
    let players: [SessionPlayer]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(players) { entry in
                HStack(spacing: 8) {
                    Text(verbatim: entry.player.emoji)
                    Text(verbatim: entry.player.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.headline.weight(.heavy))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: Capsule())
                .opacity(entry.isConnected ? 1 : 0.4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Motion.snappy, value: players.map(\.id))
    }
}

private struct LiveHostLobbyControls: View {
    @Environment(AppState.self) private var state
    let host: SessionHost

    var body: some View {
        @Bindable var state = state
        @Bindable var host = host
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                HStack {
                    Text("Mode")
                        .font(.headline)
                    Spacer()
                    Picker("Mode", selection: $state.selectedMode) {
                        ForEach(ModeKind.allCases.filter {
                            TogetherMode.supports($0) && PartyPack.canPlay($0, unlocked: state.isPartyPackUnlocked)
                        }) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                if state.selectedMode != .elimination {
                    Divider().overlay(Theme.secondaryText.opacity(0.3))
                    Stepper(value: $host.rounds, in: 1...10) {
                        Text("Rounds: \(host.rounds)")
                            .font(.headline)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))

            Button("Start game") {
                host.startGame()
            }
            .buttonStyle(.primary)
            .disabled(!host.canStart)
            if host.players.count < LiveMatchRules.minPlayers {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Waiting for the other players to connect…")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

// MARK: - Turn

/// Everyone taps "I'm ready"; then the timer starts by itself.
private struct LiveReadyView: View {
    let snapshot: SessionSnapshot?
    let onReady: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if let snapshot {
                Text("Round \(snapshot.round) of \(snapshot.rounds)")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.secondaryText)
                Text("Stop at \(TimeFormat.seconds(snapshot.target))")
                    .font(Theme.display(52))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Button("I'm ready", action: onReady)
                .buttonStyle(.primary)
            Text("When everyone is ready, the timer starts by itself at a random moment.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

/// The silent random wait before the timer starts. Nothing moves, so it
/// gives away neither the moment nor a rhythm. A tap restarts the wait.
struct LiveAutoStartView: View {
    @Environment(AppState.self) private var state
    let target: TimeInterval
    let onStart: (TimeInterval) -> Void
    @State private var attempt = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Get ready…")
                .font(Theme.display(56))
            Text("Prepare yourself now. The timer starts any moment.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Text("Stop at \(TimeFormat.seconds(target))")
                .font(Theme.display(44))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if attempt > 0 {
                Text("Too early! Wait for the flash.")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.late)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            attempt += 1
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onAppear {
            state.feel.warmUp()
            ScreenBrightness.maximize()
        }
        .task(id: attempt) {
            try? await Task.sleep(for: .seconds(RandomStart.delay()))
            guard !Task.isCancelled else { return }
            onStart(ProcessInfo.processInfo.systemUptime)
        }
    }
}

/// Everyone's result of the turn, closest first.
private struct LiveTurnResults: View {
    let snapshot: SessionSnapshot?
    let me: Player.ID?

    var body: some View {
        let results = (snapshot?.results ?? []).sorted { lhs, rhs in
            rank(lhs) < rank(rhs)
        }
        VStack(spacing: 8) {
            ForEach(results) { result in
                let player = snapshot?.player(result.playerID)
                HStack {
                    Text(verbatim: "\(player?.emoji ?? "") \(player?.name ?? "")")
                        .lineLimit(1)
                    Spacer()
                    resultText(result)
                        .monospacedDigit()
                }
                .font(.headline.weight(.heavy))
                .padding(14)
                .background(
                    result.playerID == me ? Theme.accent.opacity(0.25) : Theme.surface,
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private func rank(_ result: SessionResult) -> Double {
        guard case .scored = result.outcome else { return .infinity }
        return abs(result.deviation)
    }

    private func resultText(_ result: SessionResult) -> Text {
        switch result.outcome {
        case .scored: Text(verbatim: TimeFormat.signedDeviation(result.deviation))
        case .misfire: Text("Too eager!")
        case .timeout: Text("Time's up")
        }
    }
}

/// Next round, rematch or back to the lobby, for the host.
private struct LiveHostControls: View {
    @Environment(AppState.self) private var state
    let host: SessionHost

    var body: some View {
        if let engine = state.engine {
            switch engine.phase {
            case .roundResults:
                Button {
                    host.next()
                } label: {
                    Text(engine.isFinalRound ? LocalizedStringKey("Final results") : LocalizedStringKey("Next round"))
                }
                .buttonStyle(.primary)
            case .finished:
                HStack(spacing: 12) {
                    Button("Rematch") { host.rematch() }
                        .buttonStyle(.primary)
                    Button("Lobby") { host.backToLobby() }
                        .buttonStyle(.secondary)
                }
            case .handoff, .ready, .running, .reveal:
                EmptyView()
            }
        }
    }
}
