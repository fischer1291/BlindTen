import Foundation
import SwiftUI
import UIKit

/// App Store screenshot mode. Debug builds only: launched with
/// `-screenshotScene <scene>`, the app loads demo players and opens the
/// requested scene directly (see .github/workflows/screenshots.yml).
/// Release builds never enter it.
enum ScreenshotMode {
    enum Scene: String, CaseIterable, Sendable {
        case home
        case handoff
        case turn
        case reveal
        case showdown
        case results
        case paywall
        /// Renders the Party Pack promotional image to Documents.
        case partyPackArt
        // UI previews (Preview workflow), not App Store screenshots.
        case homeReturning
        /// Home scrolled to the bottom.
        case homeBottom
        case players
        case streaks
        case profile
        case challengeIntro
        case challengeGetReady
        case challengeResult
        case challengeSummary
        case duels
        case liveMenu
        case liveLobby
        case avatarPicker
        case quickChatSheet

        /// Scenes that replace the Home screen with another root view.
        var isPreviewRoot: Bool {
            switch self {
            case .players, .streaks, .profile, .challengeIntro, .challengeGetReady,
                 .challengeResult, .challengeSummary, .duels, .liveMenu, .avatarPicker, .quickChatSheet:
                true
            default:
                false
            }
        }
    }

    static let scene: Scene? = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshotScene"), index + 1 < arguments.count else { return nil }
        return Scene(rawValue: arguments[index + 1])
        #else
        return nil
        #endif
    }()

    static var isActive: Bool { scene != nil }
}

#if DEBUG
/// Demo data for the screenshot scenes.
@MainActor
enum ScreenshotFixtures {
    static let players = [
        Player(name: "Mia", emoji: "🦊"),
        Player(name: "Ben", emoji: "🐸"),
        Player(name: "Zoe", emoji: "🐙"),
        Player(name: "Ali", emoji: "🦉"),
    ]

    static func apply(_ scene: ScreenshotMode.Scene, to state: AppState) {
        state.roster = players
        switch scene {
        case .home, .paywall:
            break
        case .handoff:
            try? state.startGame(players: players, rounds: 3, remember: false)
        case .turn:
            try? state.startGame(players: players, rounds: 3, remember: false)
            state.engine?.beginTurn()
        case .reveal:
            try? state.startGame(players: players, rounds: 3, remember: false)
            state.engine?.beginTurn()
            state.engine?.start(at: 0)
            state.stop(at: 10.02)
        case .showdown:
            state.selectedMode = .showdown
            try? state.startGame(players: Array(players.prefix(2)), rounds: 3, remember: false)
            state.engine?.beginTurn()
        case .results:
            // Mia wins with a DEAD ON; Ben is always early, Zoe always late,
            // Ali misfires twice, so every award shows up.
            try? state.startGame(players: players, rounds: 3, remember: true)
            let rounds: [[TimeInterval]] = [[10.02, 9.4, 11.2, 10.1], [9.8, 9.6, 10.9, 0.4], [10.3, 9.7, 12.5, 0.6]]
            for times in rounds {
                for elapsed in times {
                    state.engine?.beginTurn()
                    state.engine?.start(at: 0)
                    state.stop(at: elapsed)
                    state.advance()
                }
                state.advance()
            }
        case .partyPackArt:
            writePartyPackArt()
        case .homeReturning, .homeBottom, .profile, .streaks:
            state.setChallengeRecordsForPreview(previewRecords())
        case .players, .duels, .liveMenu, .avatarPicker, .quickChatSheet:
            break
        case .challengeIntro:
            session = state.makeChallengeSession(.daily(DailyChallenge(date: .now)))
        case .challengeGetReady:
            let session = ChallengeSession(mode: .streak(.classic, .pro), records: ChallengeRecords(), seed: 1, delay: { 1_000 })
            session.getReady(now: ProcessInfo.processInfo.systemUptime)
            self.session = session
        case .challengeResult:
            let session = ChallengeSession(mode: .streak(.classic, .close), records: ChallengeRecords(), seed: 1, delay: { 0 })
            let now = ProcessInfo.processInfo.systemUptime
            session.getReady(now: now)
            session.go(at: now)
            session.stop(at: now + 10.12)
            self.session = session
        case .challengeSummary:
            let session = ChallengeSession(mode: .streak(.classic, .close), records: ChallengeRecords(), seed: 1, delay: { 0 })
            var now = ProcessInfo.processInfo.systemUptime
            for stop in [10.12, 9.81, 10.03, 10.31, 11.2] {
                session.getReady(now: now)
                session.go(at: now)
                session.stop(at: now + stop)
                now += 20
                session.continueAfterResult(now: now)
            }
            self.session = session
        case .liveLobby:
            let host = SessionHost(state: state)
            host.playsAllAtOnce = true
            host.playerLimit = LiveMatchRules.maxPlayers
            host.setLocalPlayer(players[0])
            state.setLiveMatchForPreview(.host(host))
        }
    }

    /// The challenge run shown by the challenge preview scenes.
    static var session: ChallengeSession?

    /// A player who has played a few streaks, Dailies and duels.
    private static func previewRecords() -> ChallengeRecords {
        var records = ChallengeRecords()
        for stops in [[10.1, 9.9, 10.2, 11.0], [10.05, 9.8, 10.3, 10.1, 9.95, 10.2, 10.6]] {
            var run = StreakRun(kind: .classic, difficulty: .close, seed: 1)
            for stop in stops {
                run.record(stopped: stop)
            }
            records.record(run)
        }
        records.recordDuel(id: "a", result: .win)
        records.recordDuel(id: "b", result: .win)
        records.recordDuel(id: "c", result: .loss)
        return records
    }

    /// 1024 × 1024 JPEG without transparency, as App Store Connect requires
    /// for in-app purchase promotional images.
    private static func writePartyPackArt() {
        guard let image = PartyPackArtRenderer.image(),
              let data = image.jpegData(compressionQuality: 0.95),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        try? data.write(to: documents.appendingPathComponent("PartyPackPromo.jpg"))
    }
}
#endif

#if DEBUG
/// The root view of a UI preview scene.
struct ScreenshotPreviewRoot: View {
    let scene: ScreenshotMode.Scene

    var body: some View {
        switch scene {
        case .players: PlayersView()
        case .streaks: StreaksView()
        case .profile: ProfileView()
        case .duels: DuelListView()
        case .liveMenu: LiveMatchMenuView()
        case .avatarPicker: AvatarPicker(selection: .constant("🦊"))
        case .quickChatSheet: QuickChatSheet { _ in }
        case .challengeIntro, .challengeGetReady, .challengeResult, .challengeSummary:
            if let session = ScreenshotFixtures.session {
                ChallengeRunView(session: session) {}
            }
        default:
            HomeView()
        }
    }
}
#endif
