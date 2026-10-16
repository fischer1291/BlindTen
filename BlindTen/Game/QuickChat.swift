import Foundation

/// Preset phrases for online play (SPEC.md: no free-text chat). Only a
/// phrase ID travels over the network; every phone shows the phrase in its
/// own language and ignores IDs it does not know, so no free text can ever
/// reach another player.
enum QuickChat {
    enum Category: String, CaseIterable, Sendable {
        case greeting, hype, praise, sympathy, selfTalk, taunt, end, emoji
    }

    struct Phrase: Identifiable, Equatable, Sendable {
        let id: String
        let category: Category
        /// Emoji-only phrases are shown as they are; the rest come from the
        /// string catalog as "chat.<id>" (edited in Tools/chat_phrases.json).
        let emoji: String?
    }

    /// The game moment a phrase is suggested for.
    enum Context: Sendable {
        case lobby
        case waiting
        case goodResult
        case badResult
        case roundOver
        case won
        case lost
        case draw
    }

    static let phrases: [Phrase] = {
        let text: [(Category, [String])] = [
            (.greeting, ["hi", "goodLuck", "letsGo", "readyWhenYouAre"]),
            (.hype, ["bringIt", "noPressure", "canYouFeelIt", "focus"]),
            (.praise, ["niceOne", "wow", "deadOnQuestion", "howDidYou", "respect", "machine", "impressive"]),
            (.sympathy, ["soClose", "unlucky", "nextTime", "almost"]),
            (.selfTalk, ["oops", "tooEager", "brainLag", "pureLuck", "nailedIt", "warmingUp"]),
            (.taunt, ["beatThat", "tooEasy", "yourMove", "catchMe"]),
            (.end, ["gg", "wellPlayed", "rematch", "thanks", "whatAGame", "oneMore"]),
        ]
        let emoji: [(String, String)] = [
            ("wave", "👋"), ("fire", "🔥🔥🔥"), ("laugh", "😂😂"), ("shock", "😱"), ("clap", "👏👏"),
            ("target", "🎯"), ("timerQuestion", "⏱️❓"), ("heart", "❤️"), ("sweat", "😅"), ("crown", "👑"),
            ("muscle", "💪"), ("eyes", "👀"), ("party", "🎉"), ("ghost", "👻"), ("snail", "🐌"),
            ("rocket", "🚀"), ("handshake", "🤝"), ("skull", "💀"), ("sob", "😭"), ("cool", "😎👌"),
        ]
        return text.flatMap { category, ids in ids.map { Phrase(id: $0, category: category, emoji: nil) } }
            + emoji.map { Phrase(id: $0.0, category: .emoji, emoji: $0.1) }
    }()

    private static let byID = Dictionary(uniqueKeysWithValues: phrases.map { ($0.id, $0) })

    static func phrase(_ id: String) -> Phrase? {
        byID[id]
    }

    /// The localized phrase, or nil for an unknown ID.
    static func text(for id: String, bundle: Bundle = .main) -> String? {
        guard let phrase = byID[id] else { return nil }
        return phrase.emoji ?? bundle.localizedString(forKey: "chat.\(id)", value: nil, table: nil)
    }

    /// What fits the moment, best first.
    static func suggestions(for context: Context) -> [String] {
        switch context {
        case .lobby: ["hi", "goodLuck", "letsGo", "bringIt", "wave", "canYouFeelIt", "focus", "handshake"]
        case .waiting: ["noPressure", "focus", "yourMove", "eyes", "sweat", "bringIt", "timerQuestion", "snail"]
        case .goodResult: ["nailedIt", "beatThat", "tooEasy", "fire", "target", "crown", "pureLuck", "cool"]
        case .badResult: ["oops", "brainLag", "tooEager", "soClose", "sob", "skull", "sweat", "warmingUp"]
        case .roundOver: ["niceOne", "wow", "soClose", "nextTime", "catchMe", "clap", "fire", "muscle"]
        case .won: ["gg", "wellPlayed", "thanks", "rematch", "party", "crown", "pureLuck", "handshake"]
        case .lost: ["gg", "wellPlayed", "respect", "rematch", "oneMore", "clap", "machine", "sob"]
        case .draw: ["gg", "whatAGame", "oneMore", "rematch", "handshake", "shock", "clap", "wellPlayed"]
        }
    }
}

/// One phrase someone sent.
struct QuickChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    /// The sender's player ID.
    let senderID: String
    let phraseID: String
    /// System uptime when it arrived.
    let receivedAt: TimeInterval
}

/// Recent phrases in a live match, with a cooldown per sender against spam.
struct QuickChatFeed: Equatable, Sendable {
    /// Minimum time between two phrases from the same player.
    static let cooldown: TimeInterval = 1.5
    /// How long a phrase stays on screen.
    static let lifetime: TimeInterval = 4
    static let maxMessages = 4

    private(set) var messages: [QuickChatMessage] = []
    private var lastFrom: [String: TimeInterval] = [:]

    /// Adds a phrase. Returns nil for an unknown phrase or a sender still in
    /// their cooldown.
    @discardableResult
    mutating func receive(phraseID: String, from sender: String, at now: TimeInterval) -> QuickChatMessage? {
        guard QuickChat.phrase(phraseID) != nil else { return nil }
        if let last = lastFrom[sender], now - last < Self.cooldown { return nil }
        lastFrom[sender] = now
        let message = QuickChatMessage(id: UUID(), senderID: sender, phraseID: phraseID, receivedAt: now)
        messages.append(message)
        messages.removeAll { now - $0.receivedAt >= Self.lifetime }
        if messages.count > Self.maxMessages {
            messages.removeFirst(messages.count - Self.maxMessages)
        }
        return message
    }

    func canSend(from sender: String, at now: TimeInterval) -> Bool {
        lastFrom[sender].map { now - $0 >= Self.cooldown } ?? true
    }

    func visible(at now: TimeInterval) -> [QuickChatMessage] {
        messages.filter { now - $0.receivedAt < Self.lifetime }
    }
}
