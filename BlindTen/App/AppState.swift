import Foundation
import Observation

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
    func startGame(players: [Player], rounds: Int, remember: Bool) throws {
        engine = try GameEngine(players: players, mode: selectedMode.mode, rounds: rounds)
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

    /// The localized reaction line for a finished turn.
    func reactionText(for result: TurnResult) -> String? {
        reactionKeys[result.id].map { ReactionText.text(forKey: $0) }
    }

    private func assignReaction(to result: TurnResult) {
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
            isCloseFinal: ReviewPrompt.isCloseFinal(engine.standings()),
            finishedGames: finishedGames,
            lastPromptedVersion: defaults.string(forKey: ReviewPromptStorage.lastPromptedVersionKey),
            currentVersion: ReviewPromptStorage.currentVersion
        )
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
