import Foundation

/// What the one-time Party Pack purchase unlocks (SPEC.md Monetization).
enum PartyPack {
    /// "<bundle ID>.partypack". Create the in-app purchase in App Store Connect
    /// with exactly this ID; changing the bundle ID in Xcode changes it too.
    static let productID = makeProductID(bundleID: Bundle.main.bundleIdentifier)

    static func makeProductID(bundleID: String?) -> String {
        "\(bundleID ?? "com.leroyfischer.blindtengame").partypack"
    }
    /// SPEC.md: min 2, max 10 players free, unlimited with the Party Pack.
    static let freePlayerLimit = 10
    /// A practical cap so the roster stays usable even when unlocked.
    static let unlockedPlayerLimit = 30

    static func canPlay(_ mode: ModeKind, unlocked: Bool) -> Bool {
        mode.isFree || unlocked
    }

    static func maxPlayers(unlocked: Bool) -> Int {
        unlocked ? unlockedPlayerLimit : freePlayerLimit
    }

    static func canAddCustomHouseRules(unlocked: Bool) -> Bool {
        unlocked
    }

    /// SPEC.md: the dedicated TV scene is a Party Pack feature; without it
    /// the system simply mirrors the phone.
    static func canUseTVScene(unlocked: Bool) -> Bool {
        unlocked
    }
}

/// Picks at random without repeating until every option has been used.
struct NoRepeatPicker: Sendable {
    private var used: Set<String> = []

    mutating func draw<G: RandomNumberGenerator>(from options: [String], using generator: inout G) -> String? {
        guard !options.isEmpty else { return nil }
        var available = options.filter { !used.contains($0) }
        if available.isEmpty {
            used.subtract(options)
            available = options
        }
        guard let pick = available.randomElement(using: &generator) else { return nil }
        used.insert(pick)
        return pick
    }

    mutating func draw(from options: [String]) -> String? {
        var generator = SystemRandomNumberGenerator()
        return draw(from: options, using: &generator)
    }

    mutating func reset() {
        used = []
    }
}

/// The built-in house-rule cards. Neutral and alcohol-free (SPEC.md App Store notes).
enum HouseRuleCatalog {
    static let defaultCount = 12

    /// String Catalog keys of the built-in cards.
    static let defaultKeys: [String] = (1...defaultCount).map { "houseRule.default.\($0)" }

    /// Card text: custom cards store their text; built-in cards store a catalog key.
    static func text(stored: String, isCustom: Bool, bundle: Bundle = .main) -> String {
        isCustom ? stored : bundle.localizedString(forKey: stored, value: nil, table: nil)
    }
}
