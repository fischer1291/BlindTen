import Foundation
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
        }
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
