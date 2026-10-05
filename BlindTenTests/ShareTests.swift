import Foundation
import Testing
@testable import BlindTen

@MainActor
struct ShareTests {
    let mia = Player(name: "Mia", emoji: "🦊")
    let ben = Player(name: "Ben", emoji: "🐸")

    private func finishedGame(_ times: [TimeInterval], mode: any GameMode = ClassicMode()) throws -> GameEngine {
        var engine = try GameEngine(players: [mia, ben], mode: mode, rounds: times.count / 2)
        for elapsed in times {
            engine.beginTurn()
            engine.start(at: 0)
            engine.stop(at: elapsed)
            engine.advance()
            if engine.phase == .roundResults { engine.advance() }
        }
        return engine
    }

    @Test func bestResultIsTheClosestTimedTurn() throws {
        let engine = try finishedGame([10.4, 0.5, 9.9, 10.2])   // Mia 10.4, 9.9; Ben misfire, 10.2
        #expect(engine.phase == .finished)
        let miaBest = try #require(engine.bestResult(for: mia.id))
        #expect(abs(miaBest.stopped - 9.9) < 1e-9)
        let benBest = try #require(engine.bestResult(for: ben.id))
        #expect(abs(benBest.stopped - 10.2) < 1e-9)
    }

    @Test func playersWithoutATimedTurnHaveNoBest() throws {
        let engine = try finishedGame([10.0, 0.4])
        #expect(engine.bestResult(for: ben.id) == nil)
    }

    @Test func summaryFollowsTheLeaderboard() throws {
        let engine = try finishedGame([11.0, 10.0])
        let summary = ShareSummary(engine: engine)
        #expect(summary.mode == .classic)
        #expect(summary.winner == ben)
        #expect(summary.rows.map(\.player) == [ben, mia])
        #expect(summary.rows.map(\.points) == [10, 3])
        #expect(!summary.isTeamGame)
    }

    @Test func cardRendersAtStorySize() throws {
        let image = try #require(ShareCardRenderer.image(for: ShareSummary(engine: try finishedGame([10.0, 10.3]))))
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1920)
    }
}

struct ReviewPromptTests {
    private func standing(_ points: Int) -> Standing {
        Standing(player: Player(name: "P", emoji: "🦊"), points: points, totalDeviation: 0, duelWins: 0, eliminatedInRound: nil, team: nil)
    }

    @Test func closeFinalMeansTwoPointsOrLess() {
        #expect(ReviewPrompt.isCloseFinal([standing(20), standing(18)]))
        #expect(!ReviewPrompt.isCloseFinal([standing(20), standing(17)]))
        #expect(!ReviewPrompt.isCloseFinal([standing(20)]))
    }

    @Test func asksOnlyAfterAFunGame() {
        #expect(ReviewPrompt.shouldAsk(hadDeadOn: true, isCloseFinal: false, finishedGames: 2, lastPromptedVersion: nil, currentVersion: "1.0"))
        #expect(ReviewPrompt.shouldAsk(hadDeadOn: false, isCloseFinal: true, finishedGames: 5, lastPromptedVersion: "0.9", currentVersion: "1.0"))
        #expect(!ReviewPrompt.shouldAsk(hadDeadOn: false, isCloseFinal: false, finishedGames: 5, lastPromptedVersion: nil, currentVersion: "1.0"))
    }

    @Test func notOnTheFirstGameAndOncePerVersion() {
        #expect(!ReviewPrompt.shouldAsk(hadDeadOn: true, isCloseFinal: true, finishedGames: 1, lastPromptedVersion: nil, currentVersion: "1.0"))
        #expect(!ReviewPrompt.shouldAsk(hadDeadOn: true, isCloseFinal: true, finishedGames: 9, lastPromptedVersion: "1.0", currentVersion: "1.0"))
    }

    @Test func deadOnDetection() {
        let deadOn = TurnResult(id: UUID(), turnID: UUID(), playerID: UUID(), round: 1, target: 10, stopped: 10.01, outcome: .scored(.deadOn))
        let close = TurnResult(id: UUID(), turnID: UUID(), playerID: UUID(), round: 1, target: 10, stopped: 10.4, outcome: .scored(.close))
        #expect(ReviewPrompt.hadDeadOn([close, deadOn]))
        #expect(!ReviewPrompt.hadDeadOn([close]))
    }
}
