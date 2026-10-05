import SwiftUI

/// A joined player's phone: waits while others play, then runs this
/// player's turn with the same START and blind phase as pass-the-phone play.
struct ClientSessionView: View {
    @Environment(AppState.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    let client: SessionClient

    @State private var confirmsLeave = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(Theme.primaryText)
            .overlay(alignment: .top) {
                if case .reconnecting = client.status {
                    Label("Reconnecting…", systemImage: "wifi.exclamationmark")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Theme.accent, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                state.feel.prepare()
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                ScreenBrightness.restore()
            }
            .onChange(of: client.screen.needsPlayer) { _, needsPlayer in
                // Full brightness only for START and the blind phase.
                if !needsPlayer {
                    ScreenBrightness.restore()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // SPEC.md: leaving the app mid-turn voids the turn and it is replayed.
                if newPhase != .active {
                    client.voidIfRunning()
                    state.feel.stopAll()
                }
            }
            .confirmationDialog("Leave this session?", isPresented: $confirmsLeave, titleVisibility: .visible) {
                Button("Leave", role: .destructive) {
                    state.leaveSession()
                }
            }
    }

    private var snapshot: SessionSnapshot? { client.snapshot }

    @ViewBuilder
    private var content: some View {
        switch client.screen {
        case .connecting:
            ProgressView()
                .controlSize(.large)
        case .lobby:
            waiting(
                title: "You're in!",
                subtitle: "Waiting for the host to start the game.",
                spotlight: [client.player]
            )
        case .yourTurn:
            yourTurn
        case .waitingForOpponent:
            waiting(
                title: "Ready!",
                subtitle: "Waiting for your opponent…",
                spotlight: turnPlayers
            )
        case .start(let target):
            SessionStartView(target: target) { timestamp in
                state.feel.touch()
                client.start(at: timestamp)
            }
        case .blind(let startedAt):
            SessionBlindView(
                effect: snapshot?.effect ?? .dark,
                target: snapshot?.target ?? GameEngine.classicTarget,
                startedAt: startedAt
            ) { timestamp in
                if client.stop(at: timestamp) {
                    state.feel.touch()
                }
            }
        case .stopped:
            waiting(title: "Stopped!", subtitle: "Look at the TV.", spotlight: [client.player])
        case .drumroll:
            waiting(title: "Look at the TV", subtitle: "Here comes your time…", spotlight: [client.player])
        case .result(let result):
            ClientResultView(result: result)
        case .watching(let ids):
            waiting(
                title: "Up now",
                subtitle: isEliminated ? "You're out. Cheer the others on!" : "Watch the TV. Your turn is coming.",
                spotlight: ids.compactMap { snapshot?.player($0) }
            )
        case .roundResults:
            ClientStandingsView(snapshot: snapshot, me: client.player.id, isFinal: false, leave: leave)
        case .finished:
            ClientStandingsView(snapshot: snapshot, me: client.player.id, isFinal: true, leave: leave)
        }
    }

    private var turnPlayers: [Player] {
        (snapshot?.turnPlayerIDs ?? []).compactMap { snapshot?.player($0) }
    }

    private var isEliminated: Bool {
        snapshot?.standings.first { $0.playerID == client.player.id }?.isEliminated ?? false
    }

    private func leave() {
        confirmsLeave = true
    }

    private var yourTurn: some View {
        SessionYourTurnView(
            player: client.player,
            opponent: turnPlayers.count == 2 ? turnPlayers.first { $0.id != client.player.id } : nil
        ) {
            client.ready()
        }
    }

    /// The animated waiting screen: everyone's avatar drifts in the
    /// background, the players of the moment sit in the middle.
    private func waiting(title: LocalizedStringKey, subtitle: LocalizedStringKey, spotlight: [Player]) -> some View {
        ZStack {
            DriftingAvatars(emojis: (snapshot?.players ?? []).map(\.player.emoji), size: 44)
                .opacity(0.35)
            VStack(spacing: 18) {
                Text(title)
                    .font(.title.weight(.heavy))
                    .foregroundStyle(Theme.secondaryText)
                ForEach(spotlight) { player in
                    VStack(spacing: 4) {
                        Text(verbatim: player.emoji)
                            .font(.system(size: 80))
                        Text(verbatim: player.name)
                            .font(Theme.display(40))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                Text(subtitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .overlay(alignment: .topLeading) {
            Button {
                leave()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.heavy))
                    .frame(width: 44, height: 44)
                    .background(Theme.surface, in: Circle())
            }
            .accessibilityLabel(Text("Leave session"))
            .padding(16)
        }
    }
}

/// "Your turn!" with a whole-screen tap-when-ready button. Shared by joined
/// phones and the host when the host plays too.
struct SessionYourTurnView: View {
    let player: Player
    /// The other duel player in Showdown.
    let opponent: Player?
    let onReady: () -> Void

    var body: some View {
        Button(action: onReady) {
            VStack(spacing: 20) {
                Text(verbatim: player.emoji)
                    .font(.system(size: 96))
                Text("Your turn!")
                    .font(Theme.display(56))
                if let opponent {
                    Text("Showdown against \(opponent.name)")
                        .font(.title2.weight(.heavy))
                }
                Text("Tap when ready")
                    .font(.title2.weight(.bold))
                    .opacity(0.7)
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 40))
            .contentShape(RoundedRectangle(cornerRadius: 40))
        }
        .buttonStyle(.plain)
        .padding(24)
        .onAppear {
            // A strong buzz so the phone in a pocket says "you're up".
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

/// Target and a big START surface, measured with `UITouch.timestamp`.
struct SessionStartView: View {
    @Environment(AppState.self) private var state
    let target: TimeInterval
    let onStart: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Text("Stop at \(TimeFormat.seconds(target))")
                .font(Theme.display(52))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            TouchTimerView(accessibilityLabel: String(localized: "Start")) { timestamp in
                onStart(timestamp)
            }
            .frame(maxWidth: .infinity, maxHeight: 420)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 40))
            .overlay {
                Text("START")
                    .font(Theme.display(72))
                    .foregroundStyle(Theme.onAccent)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .padding(24)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onAppear {
            state.feel.warmUp()
            ScreenBrightness.maximize()
        }
    }
}

/// The blind phase, plus a one-shot auto-stop at target × 3.
struct SessionBlindView: View {
    let effect: BlindEffect
    let target: TimeInterval
    let startedAt: TimeInterval
    let onStop: (TimeInterval) -> Void

    var body: some View {
        BlindPhaseView(effect: effect, target: target, startedAt: startedAt, onStop: onStop)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .defersSystemGestures(on: .all)
            .task(id: startedAt) {
                let deadline = startedAt + Scoring.timeoutDuration(for: target)
                let wait = deadline - ProcessInfo.processInfo.systemUptime
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                }
                guard !Task.isCancelled else { return }
                onStop(deadline)
            }
    }
}

/// This player's own result, the same moment the TV lands.
private struct ClientResultView: View {
    let result: SessionResult

    var body: some View {
        VStack(spacing: 18) {
            Text("\(TimeFormat.seconds(result.stopped)) s")
                .font(Theme.display(88))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            switch result.outcome {
            case .scored(let tier):
                Text(tier.label)
                    .font(Theme.display(56))
                    .foregroundStyle(Theme.color(for: tier))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(verbatim: TimeFormat.signedDeviation(result.deviation))
                    .font(Theme.display(40))
                    .monospacedDigit()
                    .foregroundStyle(deviationColor(tier))
            case .misfire:
                Text("Too eager!")
                    .font(Theme.display(56))
                    .foregroundStyle(Theme.early)
            case .timeout:
                Text("Still waiting...")
                    .font(Theme.display(56))
                    .foregroundStyle(Theme.late)
            }
            if let reaction = result.reaction {
                Text(verbatim: reaction)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            Text("+\(result.points) points")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(24)
        .sensoryFeedback(trigger: result) { _, result in
            let feedback: SensoryFeedback = switch result.outcome {
            case .scored(.deadOn): .success
            case .scored(.lostInTime), .misfire, .timeout: .error
            case .scored: .impact
            }
            return feedback
        }
    }

    private func deviationColor(_ tier: Tier) -> Color {
        if tier == .deadOn { return Theme.accent }
        if result.deviation < 0 { return Theme.early }
        if result.deviation > 0 { return Theme.late }
        return Theme.accent
    }
}

/// Round or final leaderboard, with this player highlighted.
private struct ClientStandingsView: View {
    let snapshot: SessionSnapshot?
    let me: Player.ID
    let isFinal: Bool
    let leave: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isFinal {
                    if let team = snapshot?.winningTeam {
                        Text("Team \(team + 1) wins!")
                            .font(Theme.display(44))
                            .foregroundStyle(Theme.color(forTeam: team))
                    } else if let winner = snapshot?.winnerID.flatMap({ snapshot?.player($0) }) {
                        Text(verbatim: winner.emoji)
                            .font(.system(size: 80))
                        Group {
                            if winner.id == me {
                                Text("You win!")
                            } else {
                                Text("\(winner.name) wins!")
                            }
                        }
                            .font(Theme.display(44))
                            .foregroundStyle(Theme.accent)
                            .multilineTextAlignment(.center)
                    }
                } else if let round = snapshot?.round {
                    Text("Round \(round) results")
                        .font(Theme.display(36))
                }

                ForEach(Array((snapshot?.standings ?? []).enumerated()), id: \.element.id) { index, standing in
                    let player = snapshot?.player(standing.playerID)
                    HStack(spacing: 14) {
                        Text(verbatim: "\(index + 1)")
                            .foregroundStyle(index == 0 ? Theme.accent : Theme.secondaryText)
                            .frame(width: 32, alignment: .leading)
                        Text(verbatim: "\(player?.emoji ?? "") \(player?.name ?? "")")
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer()
                        Text("\(standing.points) points")
                            .monospacedDigit()
                    }
                    .font(.title3.weight(.heavy))
                    .padding(16)
                    .background(
                        standing.playerID == me ? Theme.accent.opacity(0.25) : Theme.surface,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .opacity(standing.isEliminated ? 0.5 : 1)
                }

                Text(isFinal ? LocalizedStringKey("The host can start a rematch.") : LocalizedStringKey("The next round starts soon."))
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
                if isFinal {
                    Button("Leave session", action: leave)
                        .buttonStyle(.secondary)
                }
            }
            .padding(20)
        }
    }
}
