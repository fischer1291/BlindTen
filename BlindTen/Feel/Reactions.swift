import Foundation

/// Which pool of one-liners a turn draws from.
enum ReactionCategory: String, CaseIterable, Sendable {
    case deadOn
    case sharp
    case close
    case meh
    case off
    case lostInTime
    case misfire
    case timeout

    init(_ tier: Tier) {
        switch tier {
        case .deadOn: self = .deadOn
        case .sharp: self = .sharp
        case .close: self = .close
        case .meh: self = .meh
        case .off: self = .off
        case .lostInTime: self = .lostInTime
        }
    }

    init(_ outcome: TurnOutcome) {
        switch outcome {
        case .scored(let tier): self.init(tier)
        case .misfire: self = .misfire
        case .timeout: self = .timeout
        }
    }

    /// Number of lines in Localizable.xcstrings for this category.
    var lineCount: Int {
        switch self {
        case .misfire, .timeout: 10
        case .deadOn, .sharp, .close, .meh, .off, .lostInTime: 30
        }
    }

    /// String Catalog key, e.g. "reaction.deadOn.1". `line` is 1-based.
    func key(forLine line: Int) -> String {
        "reaction.\(rawValue).\(line)"
    }

    var allKeys: [String] {
        (1...lineCount).map(key(forLine:))
    }
}

/// Draws reaction lines at random without repeating one within a game.
struct ReactionDeck: Sendable {
    private var used: [ReactionCategory: Set<Int>] = [:]

    /// Returns a String Catalog key. A category only repeats a line once all
    /// of its lines have been used.
    mutating func draw<G: RandomNumberGenerator>(
        for category: ReactionCategory,
        using generator: inout G
    ) -> String {
        var usedLines = used[category, default: []]
        if usedLines.count >= category.lineCount {
            usedLines = []
        }
        let available = (1...category.lineCount).filter { !usedLines.contains($0) }
        let line = available.randomElement(using: &generator) ?? 1
        usedLines.insert(line)
        used[category] = usedLines
        return category.key(forLine: line)
    }

    mutating func draw(for category: ReactionCategory) -> String {
        var generator = SystemRandomNumberGenerator()
        return draw(for: category, using: &generator)
    }

    /// Call when a new game starts.
    mutating func reset() {
        used = [:]
    }
}

enum ReactionText {
    /// The localized line for a key from `ReactionCategory`.
    static func text(forKey key: String, bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
