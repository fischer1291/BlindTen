import Foundation
import Testing
@testable import BlindTen

struct QuickChatTests {
    @Test func catalogHasAboutFiftyUniquePhrases() {
        let ids = QuickChat.phrases.map(\.id)
        #expect(ids.count >= 50)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyTextPhraseIsInTheStringCatalog() {
        for phrase in QuickChat.phrases where phrase.emoji == nil {
            let text = QuickChat.text(for: phrase.id)
            #expect(text != nil)
            #expect(text != "chat.\(phrase.id)")
        }
    }

    @Test func unknownPhrasesAreDropped() {
        #expect(QuickChat.text(for: "Hello, call me at 555") == nil)
        var feed = QuickChatFeed()
        let message = feed.receive(phraseID: "free text", from: "a", at: 0)
        #expect(message == nil)
        #expect(feed.messages.isEmpty)
    }

    @Test func suggestionsAreKnownPhrases() {
        let contexts: [QuickChat.Context] = [.lobby, .waiting, .goodResult, .badResult, .roundOver, .won, .lost, .draw]
        for context in contexts {
            let ids = QuickChat.suggestions(for: context)
            #expect(ids.count == 8)
            let unknown = ids.filter { QuickChat.phrase($0) == nil }
            #expect(unknown.isEmpty)
        }
    }

    @Test func feedThrottlesEachSender() {
        var feed = QuickChatFeed()
        let first = feed.receive(phraseID: "gg", from: "a", at: 10)
        let spam = feed.receive(phraseID: "fire", from: "a", at: 10.5)
        let other = feed.receive(phraseID: "fire", from: "b", at: 10.5)
        let later = feed.receive(phraseID: "fire", from: "a", at: 12)
        #expect(first != nil)
        #expect(spam == nil)
        #expect(other != nil)
        #expect(later != nil)
        #expect(!feed.canSend(from: "a", at: 12.5))
        #expect(feed.canSend(from: "a", at: 14))
    }

    @Test func messagesExpireAndStayFew() {
        var feed = QuickChatFeed()
        for index in 0..<6 {
            feed.receive(phraseID: "gg", from: "p\(index)", at: Double(index) * 0.1)
        }
        #expect(feed.messages.count == QuickChatFeed.maxMessages)
        #expect(feed.visible(at: 2).count == QuickChatFeed.maxMessages)
        #expect(feed.visible(at: 10).isEmpty)
    }
}

struct AvatarCatalogTests {
    @Test func autoAssignedAvatarsAreInTheCatalog() {
        let missing = Avatar.pool.filter { !AvatarCatalog.isValid($0) }
        #expect(missing.isEmpty)
    }

    @Test func catalogHasNoDuplicates() {
        #expect(Set(AvatarCatalog.all).count == AvatarCatalog.all.count)
        #expect(AvatarCatalog.all.count >= 100)
        #expect(AvatarCatalog.isValid(AvatarCatalog.fallback))
    }

    @Test func textIsNeverAnAvatar() {
        #expect(AvatarCatalog.sanitized("hello") == AvatarCatalog.fallback)
        #expect(AvatarCatalog.sanitized("🦊") == "🦊")
    }

    @Test func hostReplacesAvatarsOutsideTheCatalog() {
        var logic = SessionHostLogic()
        let player = Player(name: "Sam", emoji: "call me")
        let result = logic.join(player, protocolVersion: SessionProtocol.version, gameInProgress: false, maxPlayers: 8)
        #expect(result == .joined)
        #expect(logic.players.first?.emoji == AvatarCatalog.fallback)
    }
}

struct DuelMessageTests {
    @Test func onlyKnownPhrasesAreKept() {
        var duel = DuelState(kind: .classic, seed: 1)
        duel.say("gg", player: 0)
        duel.say("anything else", player: 1)
        #expect(duel.messages == [DuelState.Message(player: 0, phraseID: "gg")])
    }

    @Test func duelsSavedWithoutMessagesStillLoad() throws {
        let duel = DuelState(kind: .classic, seed: 5)
        var json = try #require(String(data: try #require(duel.encoded()), encoding: .utf8))
        json = json.replacingOccurrences(of: ",\"messages\":[]", with: "")
            .replacingOccurrences(of: "\"messages\":[],", with: "")
        let decoded = DuelState.decode(Data(json.utf8))
        #expect(decoded?.seed == 5)
        #expect(decoded?.messages.isEmpty == true)
    }

    @Test func tamperedMessagesAreFilteredOut() throws {
        let json = #"{"version":1,"kind":"classic","seed":1,"turns":[[null,null,null],[null,null,null]],"messages":[{"player":0,"phraseID":"gg"},{"player":1,"phraseID":"visit my site"}]}"#
        let decoded = try #require(DuelState.decode(Data(json.utf8)))
        let phraseIDs = decoded.messages.map(\.phraseID)
        #expect(phraseIDs == ["gg"])
    }
}
