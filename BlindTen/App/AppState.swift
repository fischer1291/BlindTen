import Foundation
import Observation

/// When the current reveal's drumroll started and when it landed.
struct RevealPresentation: Equatable, Sendable {
    let firstResultID: UUID
    let drumrollStart: TimeInterval
    let drumrollDuration: TimeInterval
    var landedAt: TimeInterval?
}

enum HouseRuleSettings {
    /// UserDefaults key. SPEC.md: house rules are optional and off by default.
    static let enabledKey = "houseRulesEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }
}

/// App-wide state: the roster, the game in progress, purchases and persistence.
@MainActor
@Observable
final class AppState {
    var roster: [Player] = []
    /// Mode picked on the Home screen.
    var selectedMode: ModeKind = .classic
    /// The running game, or nil outside a game.
    var engine: GameEngine?
    /// Haptics and sound.
    let feel = GameFeel()
    let purchases = PurchaseManager()
    /// Nil only if local storage could not be opened.
    let store: GameStore?
    /// True while the TV scene shows the game on an external display.
    var isTVConnected = false
    /// Timing of the reveal on the phone, so the TV can spin in sync.
    var revealPresentation: RevealPresentation?
    /// The local session this phone hosts, if any.
    var sessionHost: SessionHost?
    /// The local session this phone joined, if any.
    var sessionClient: SessionClient?
    /// Game Center sign-in, leaderboards and achievements.
    let gameCenter = GameCenterManager()
    /// Online duels (Game Center turn-based matches).
    let duels = DuelCenter()
    /// Live Match matchmaking (Game Center real-time matches).
    let live = LiveMatchCenter()
    /// The Live Match in progress: this phone hosts it or joined it.
    private(set) var liveMatch: LiveMatch?
    /// Personal bests and statistics of the solo challenges and duels.
    private(set) var challengeRecords = ChallengeRecordsStorage.load()

    /// Reaction line key chosen for each finished turn.
    private(set) var reactionKeys: [TurnResult.ID: String] = [:]
    /// House-rule card drawn by the loser of each round.
    private(set) var houseRuleCards: [Int: String] = [:]
    /// Awards shown when the game is over.
    private(set) var awards: [Award] = []
    /// True when the awards cover the group's whole history, not just this game.
    private(set) var awardsCoverGroupHistory = false
    /// Set when a finished game qualifies for the rating prompt (SPEC.md growth).
    private(set) var wantsReviewPrompt = false

    @ObservationIgnored private var reactionDeck = ReactionDeck()
    @ObservationIgnored private var houseRulePicker = NoRepeatPicker()
    @ObservationIgnored private var groupID: UUID?
    @ObservationIgnored private var gameStartedAt = Date.now
    @ObservationIgnored private var gameSaved = false
    @ObservationIgnored private var loadedLastGroup = false

    init(store: GameStore?) {
        self.store = store
        gameCenter.onAuthenticated = { [weak self] in
            self?.duels.start()
            self?.live.start()
        }
        live.onConnection = { [weak self] connection in
            self?.beginLiveMatch(connection)
        }
        duels.onFinished = { [weak self] id, result in
            self?.recordDuel(id: id, result: result)
        }
    }

    var isPartyPackUnlocked: Bool { purchases.isPartyPackUnlocked }
    var maxPlayers: Int { PartyPack.maxPlayers(unlocked: isPartyPackUnlocked) }

    /// SPEC.md: "Last group is remembered." Fills an empty roster once per launch.
    func loadLastGroupIfNeeded() {
        guard !loadedLastGroup else { return }
        loadedLastGroup = true
        if roster.isEmpty, let players = store?.lastGroupPlayers() {
            roster = Array(players.prefix(maxPlayers))
        }
    }

    /// Starts a game. Named rosters are remembered as a group; quick play is not.
    /// `mode` replaces the selected mode's rules, e.g. Live Match plays it all at once.
    func startGame(players: [Player], rounds: Int, remember: Bool, mode: (any GameMode)? = nil) throws {
        engine = try GameEngine(players: players, mode: mode ?? selectedMode.mode, rounds: rounds)
        groupID = remember ? store?.rememberGroup(players) : nil
        resetGameExtras()
    }

    /// Same players and settings, back to the first handoff.
    func rematch() {
        engine?.restart()
        resetGameExtras()
    }

    /// Leaves the game and returns to the Home screen.
    func newGame() {
        engine = nil
        groupID = nil
        resetGameExtras()
    }

    /// Moves the game on and handles what happens at round and game end.
    func advance() {
        engine?.advance()
        guard let engine else { return }
        switch engine.phase {
        case .roundResults:
            drawHouseRuleCard(for: engine)
        case .finished:
            finishGame(engine)
        case .handoff, .ready, .running, .reveal:
            break
        }
    }

    /// STOP for one lane. Ends that player's turn and picks a reaction line.
    @discardableResult
    func stop(lane: Int = 0, at timestamp: TimeInterval) -> TurnResult? {
        guard let result = engine?.stop(lane: lane, at: timestamp) else { return nil }
        assignReaction(to: result)
        return result
    }

    /// Auto-stop at target × 3.
    func autoStopIfOverdue(now: TimeInterval) {
        guard let results = engine?.autoStopIfOverdue(now: now) else { return }
        for result in results {
            assignReaction(to: result)
        }
    }

    /// Replays the revealed turn ("wrong player tapped").
    func replayTurn() {
        forgetReactionsOfCurrentTurn()
        engine?.replayTurn()
    }

    /// Voids an unfinished turn, e.g. when the app leaves the foreground.
    func voidTurn() {
        forgetReactionsOfCurrentTurn()
        engine?.voidTurn()
    }

    private func forgetReactionsOfCurrentTurn() {
        for lane in engine?.lanes ?? [] {
            if let id = lane.result?.id {
                reactionKeys[id] = nil
            }
        }
    }

    /// The localized reaction line for a finished turn.
    func reactionText(for result: TurnResult) -> String? {
        reactionKeys[result.id].map { ReactionText.text(forKey: $0) }
    }

    func assignReaction(to result: TurnResult) {
        reactionKeys[result.id] = reactionDeck.draw(for: ReactionCategory(result.outcome))
    }

    /// SPEC.md: the round loser draws a card from the deck, if house rules are on.
    private func drawHouseRuleCard(for engine: GameEngine) {
        guard HouseRuleSettings.isEnabled,
              houseRuleCards[engine.round] == nil,
              engine.roundLoser(engine.round) != nil,
              let rules = store?.enabledHouseRules(), !rules.isEmpty
        else { return }
        let byID = Dictionary(rules.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
        guard let pick = houseRulePicker.draw(from: rules.map(\.id.uuidString)), let rule = byID[pick] else { return }
        houseRuleCards[engine.round] = rule.displayText
    }

    private func finishGame(_ engine: GameEngine) {
        guard !gameSaved else { return }
        gameSaved = true
        store?.saveFinishedGame(engine, groupID: groupID, startedAt: gameStartedAt)
        if let groupID, let history = store?.turnStats(groupID: groupID), !history.isEmpty {
            awards = Awards.compute(from: history)
            awardsCoverGroupHistory = true
        } else {
            awards = Awards.compute(from: engine.results.map(TurnStat.init))
            awardsCoverGroupHistory = false
        }

        let defaults = UserDefaults.standard
        let finishedGames = defaults.integer(forKey: ReviewPromptStorage.finishedGamesKey) + 1
        defaults.set(finishedGames, forKey: ReviewPromptStorage.finishedGamesKey)
        wantsReviewPrompt = ReviewPrompt.shouldAsk(
            hadDeadOn: ReviewPrompt.hadDeadOn(engine.results),
            // Points decide only the plain modes; the others rank by duels, survival or team.
            isCloseFinal: engine.mode.playersPerTurn == 1 && !engine.mode.eliminatesRoundLoser && !engine.mode.hasTeams
                && ReviewPrompt.isCloseFinal(engine.standings()),
            finishedGames: finishedGames,
            lastPromptedVersion: defaults.string(forKey: ReviewPromptStorage.lastPromptedVersionKey),
            currentVersion: ReviewPromptStorage.currentVersion
        )
    }

    // MARK: - Local sessions

    /// Opens a session that players can join from their own iPhones.
    func hostSession() {
        newGame()
        let host = SessionHost(state: self)
        host.open()
        sessionHost = host
    }

    func endHostedSession() {
        sessionHost?.close()
        sessionHost = nil
        newGame()
    }

    /// Starts looking for sessions nearby.
    func joinSession(as player: Player) {
        let client = SessionClient(player: player)
        client.open()
        sessionClient = client
    }

    func leaveSession() {
        sessionClient?.close()
        sessionClient = nil
    }

    // MARK: - Live Match

    enum LiveMatch {
        case host(SessionHost)
        case client(SessionClient)
    }

    /// A Live Match was found: the elected host runs the game on this phone
    /// and plays too; everyone else joins it.
    func beginLiveMatch(_ connection: LiveMatchConnection) {
        leaveLiveMatch()
        endHostedSession()
        leaveSession()
        let me = liveMatchPlayer(name: connection.localName)
        if connection.isHost {
            if !TogetherMode.supports(selectedMode) || !PartyPack.canPlay(selectedMode, unlocked: isPartyPackUnlocked) {
                selectedMode = .classic
            }
            let host = SessionHost(state: self) { _, handler in connection.makeTransport(handler) }
            host.playsAllAtOnce = true
            host.playerLimit = LiveMatchRules.maxPlayers
            host.open()
            host.setLocalPlayer(me)
            liveMatch = .host(host)
        } else {
            let client = SessionClient(player: me) { _, handler in connection.makeTransport(handler) }
            client.open()
            client.join(SessionClient.Host(peer: connection.hostPeer, name: connection.hostPeer.displayName))
            liveMatch = .client(client)
        }
    }

    func leaveLiveMatch() {
        switch liveMatch {
        case .host(let host):
            host.close()
            newGame()
        case .client(let client):
            client.close()
        case nil:
            return
        }
        liveMatch = nil
    }

    /// The Game Center name with the avatar picked for sessions.
    private func liveMatchPlayer(name: String) -> Player {
        let defaults = UserDefaults.standard
        let emoji = defaults.string(forKey: SessionIdentity.emojiKey) ?? Avatar.pool.randomElement() ?? "🙂"
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = trimmed.isEmpty ? String(localized: "Player") : String(trimmed.prefix(24))
        return Player(id: SessionIdentity.playerID(defaults: defaults), name: shown, emoji: emoji)
    }

    // MARK: - Challenges

    /// A new streak or Daily Challenge run. Records are saved as it goes.
    func makeChallengeSession(_ mode: ChallengeMode) -> ChallengeSession {
        ChallengeSession(mode: mode, records: challengeRecords, persist: { [weak self] records in
            self?.challengeRecords = records
            ChallengeRecordsStorage.save(records)
        })
    }

    /// A duel turn: saves each round as it is played and passes the turn on
    /// at the end.
    func makeDuelSession(_ plan: DuelPlan) -> ChallengeSession {
        ChallengeSession(mode: .duel(plan), records: challengeRecords, onDuelUpdate: { [weak self] state, isTurnComplete in
            self?.duels.update(plan.matchID, state: state, isTurnComplete: isTurnComplete)
        })
    }

    private func recordDuel(id: String, result: ChallengeRecords.DuelResult) {
        if challengeRecords.recordDuel(id: id, result: result) {
            ChallengeRecordsStorage.save(challengeRecords)
        }
    }

    /// Sends the run's score and achievements to Game Center.
    func reportChallenge(_ session: ChallengeSession) {
        guard case .finished = session.phase, !session.hasReported else { return }
        session.hasReported = true
        if case .duel = session.mode {
            let deadOns = session.duelTurns.filter { ChallengeRecords.isDeadOn(stopped: $0.stopped, target: $0.target) }.count
            if deadOns > 0 {
                challengeRecords.addDeadOns(deadOns)
                ChallengeRecordsStorage.save(challengeRecords)
            }
        }
        if let submission = session.leaderboardSubmission {
            gameCenter.submit(submission.score, to: submission.leaderboardID)
        }
        gameCenter.unlock(session.earnedAchievements)
    }

    /// Call right after asking for a rating.
    func didRequestReview() {
        wantsReviewPrompt = false
        UserDefaults.standard.set(ReviewPromptStorage.currentVersion, forKey: ReviewPromptStorage.lastPromptedVersionKey)
    }

    private func resetGameExtras() {
        reactionDeck.reset()
        reactionKeys = [:]
        houseRulePicker.reset()
        houseRuleCards = [:]
        awards = []
        awardsCoverGroupHistory = false
        wantsReviewPrompt = false
        gameSaved = false
        gameStartedAt = .now
    }
}
