import Foundation

/// Accuracy tiers from the SPEC.md "Scoring" table.
enum Tier: Int, CaseIterable, Sendable {
    case deadOn
    case sharp
    case close
    case meh
    case off
    case lostInTime

    var points: Int {
        switch self {
        case .deadOn: 10
        case .sharp: 7
        case .close: 5
        case .meh: 3
        case .off: 1
        case .lostInTime: 0
        }
    }

    /// Inclusive upper bound of the absolute deviation, in hundredths of a second.
    /// `nil` means unbounded.
    var maxHundredths: Int? {
        switch self {
        case .deadOn: 5
        case .sharp: 25
        case .close: 50
        case .meh: 100
        case .off: 200
        case .lostInTime: nil
        }
    }
}

/// How a single turn ended.
enum TurnOutcome: Hashable, Sendable {
    case scored(Tier)
    /// Stopped before `Scoring.misfireThreshold` ("Too eager!").
    case misfire
    /// No stop before `target × Scoring.timeoutMultiplier` ("Still waiting...").
    case timeout

    var points: Int {
        switch self {
        case .scored(let tier): tier.points
        case .misfire, .timeout: 0
        }
    }
}

/// Pure scoring rules. No UI, no clocks.
enum Scoring {
    /// Stopping before this many seconds is a misfire.
    static let misfireThreshold: TimeInterval = 1.0
    /// A turn auto-stops after `target × timeoutMultiplier` seconds.
    static let timeoutMultiplier: Double = 3.0

    static func timeoutDuration(for target: TimeInterval) -> TimeInterval {
        target * timeoutMultiplier
    }

    /// Absolute value rounded to whole hundredths of a second, or `nil` if it is
    /// not a usable number.
    ///
    /// Tiers are decided on the same two-decimal value the player sees, so a
    /// displayed "+0.05" is always DEAD ON. This also removes floating-point
    /// noise such as `10.05 - 10.0 = 0.0500000000000007`.
    static func hundredths(_ value: Double) -> Int? {
        guard value.isFinite, abs(value) < 1_000_000 else { return nil }
        return Int((abs(value) * 100).rounded(.toNearestOrAwayFromZero))
    }

    /// Value rounded to two decimals, with negative zero normalized to zero.
    static func roundedToHundredths(_ value: Double) -> Double {
        guard value.isFinite else { return value }
        let rounded = (value * 100).rounded(.toNearestOrAwayFromZero) / 100
        return rounded == 0 ? 0 : rounded
    }

    static func tier(forDeviation deviation: TimeInterval) -> Tier {
        guard let hundredths = hundredths(deviation) else { return .lostInTime }
        for tier in Tier.allCases {
            guard let limit = tier.maxHundredths else { return tier }
            if hundredths <= limit { return tier }
        }
        return .lostInTime
    }

    static func points(forDeviation deviation: TimeInterval) -> Int {
        tier(forDeviation: deviation).points
    }

    /// Applies the misfire, timeout and tier rules to a measured duration.
    static func outcome(elapsed: TimeInterval, target: TimeInterval) -> TurnOutcome {
        if elapsed < misfireThreshold { return .misfire }
        if elapsed >= timeoutDuration(for: target) { return .timeout }
        return .scored(tier(forDeviation: elapsed - target))
    }
}
