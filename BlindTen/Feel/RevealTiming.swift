import Foundation

/// Which feedback a reveal lands with.
enum LandingCue: Equatable, Sendable {
    /// Confetti, flash, cymbal, success haptic.
    case deadOn
    /// Trombone and sad double-buzz: more than 2 s off, misfire or timeout.
    case fail
    /// A plain landing tap.
    case neutral

    init(_ outcome: TurnOutcome) {
        switch outcome {
        case .scored(.deadOn): self = .deadOn
        case .scored(.lostInTime), .misfire, .timeout: self = .fail
        case .scored: self = .neutral
        }
    }
}

extension LandingCue {
    /// One cue for a whole reveal: DEAD ON wins over everything; fail only
    /// when nobody did better.
    init(results: [TurnResult]) {
        let cues = results.map { LandingCue($0.outcome) }
        if cues.contains(.deadOn) {
            self = .deadOn
        } else if !cues.isEmpty, cues.allSatisfy({ $0 == .fail }) {
            self = .fail
        } else {
            self = .neutral
        }
    }
}

enum RevealTiming {
    /// SPEC.md: "a short drumroll (0.8–1.5 s)".
    static let drumrollRange: ClosedRange<TimeInterval> = 0.8...1.5
    /// SPEC.md: the reveal auto-advances 3 s after the result lands.
    static let autoAdvanceDelay: Duration = .seconds(3)

    static func randomDrumrollDuration<G: RandomNumberGenerator>(using generator: inout G) -> TimeInterval {
        TimeInterval.random(in: drumrollRange, using: &generator)
    }

    static func randomDrumrollDuration() -> TimeInterval {
        var generator = SystemRandomNumberGenerator()
        return randomDrumrollDuration(using: &generator)
    }
}

/// The slot-machine count-up shown during the drumroll.
enum SlotRoll {
    /// Counts up from 0, decelerates, and lands exactly on `target` at progress 1.
    static func value(progress: Double, target: Double) -> Double {
        guard progress.isFinite else { return target }
        let clamped = min(max(progress, 0), 1)
        let eased = 1 - pow(1 - clamped, 3)
        return target * eased
    }
}
