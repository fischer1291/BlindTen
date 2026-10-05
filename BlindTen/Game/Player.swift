import Foundation

struct Player: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var emoji: String

    init(id: UUID = UUID(), name: String, emoji: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
    }
}

/// Auto-assigned emoji avatars.
enum Avatar {
    static let pool: [String] = [
        "🦊", "🐸", "🐙", "🦄", "🐯", "🐼", "🐵", "🦉", "🐢", "🦖", "🐝", "🐳",
    ]

    /// The first avatar nobody uses yet, cycling through the pool once it runs out.
    static func next(excluding used: [String]) -> String {
        pool.first { !used.contains($0) } ?? pool[used.count % pool.count]
    }
}
