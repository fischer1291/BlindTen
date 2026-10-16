import Foundation

/// The avatars players can pick: Apple's standard emoji only, chosen from a
/// grid (no keyboard), so an avatar can never carry text.
enum AvatarCatalog {
    enum Category: String, CaseIterable, Sendable {
        case animals, faces, food, fun, nature
    }

    static let emojis: [Category: [String]] = [
        .animals: [
            "🦊", "🐸", "🐙", "🦄", "🐯", "🐼", "🐵", "🦉", "🐢", "🦖", "🐝", "🐳",
            "🐶", "🐱", "🐭", "🐹", "🐰", "🐻", "🐨", "🦁", "🐮", "🐷", "🐔", "🐧",
            "🐤", "🦆", "🦅", "🐺", "🐗", "🐴", "🦓", "🦒", "🐘", "🦏", "🦛", "🐪",
            "🦘", "🦥", "🦦", "🦔", "🐊", "🐍", "🦎", "🦀", "🦞", "🦑", "🐡", "🐠",
            "🐬", "🦈", "🦩", "🦚", "🦜", "🐞", "🦋", "🐌", "🦕", "🐲",
        ],
        .faces: [
            "😀", "😎", "🤓", "🥳", "🤩", "😇", "🤠", "🤡", "👻", "💀", "👽", "🤖",
            "😺", "🙃", "😏", "🤔", "🤯", "😴", "🥶", "🥵", "😈", "👾", "🎃", "🙂",
        ],
        .food: [
            "🍕", "🍔", "🌮", "🍩", "🍪", "🍦", "🍉", "🍓", "🍒", "🍍", "🥑", "🍿",
            "🧁", "🍫", "🥨", "🍣", "🥐", "🍋", "🍇", "🥥",
        ],
        .fun: [
            "🏀", "🏈", "🎾", "🏐", "🎳", "🏓", "🥊", "🎯", "🎲", "🎮", "🛹", "🏆",
            "🥇", "🎸", "🎺", "🥁", "🎧", "🎨", "🚀", "🛸",
        ],
        .nature: [
            "🌈", "🔥", "🌟", "⭐", "🌙", "🌵", "🌻", "🍀", "🌊", "💎", "👑", "🎩",
            "🧢", "💡", "🔮", "🧲", "⚡", "🌋",
        ],
    ]

    static let all: [String] = Category.allCases.flatMap { emojis[$0] ?? [] }
    private static let allSet = Set(all)

    /// Shown instead of anything that is not in the catalog.
    static let fallback = "🙂"

    static func isValid(_ emoji: String) -> Bool {
        allSet.contains(emoji)
    }

    static func sanitized(_ emoji: String) -> String {
        isValid(emoji) ? emoji : fallback
    }
}
