import Foundation

/// Anti-cheat stage 2 (SPEC.md): before a score goes to a leaderboard, the
/// run is checked for results no human produces. Personal bests are kept
/// either way; only the leaderboard submission is skipped.
enum Plausibility {
    /// A stop this close to the target (raw, before rounding) happens to a
    /// good player maybe once in 80 turns.
    static let nearPerfect: TimeInterval = 0.005

    enum Verdict: Equatable, Sendable {
        case plausible
        /// Too many stops within a few milliseconds of the target.
        case tooPerfect
        /// The same deviation again and again, like a script.
        case repeated
    }

    /// Checks the deviations (stopped − target, in seconds) of one run.
    static func check(deviations: [TimeInterval]) -> Verdict {
        let nearPerfectCount = deviations.filter { abs($0) < nearPerfect }.count
        if nearPerfectCount >= 3 || (deviations.count <= 5 && nearPerfectCount >= 2) {
            return .tooPerfect
        }
        // Timestamps are precise to well under a millisecond; a human never
        // lands on the same deviation four times.
        let rounded = deviations.map { Int(($0 * 2_000).rounded()) }
        let counts = Dictionary(rounded.map { ($0, 1) }, uniquingKeysWith: +)
        if counts.values.contains(where: { $0 >= 4 }) {
            return .repeated
        }
        if deviations.count >= 10 {
            let average = deviations.reduce(0) { $0 + abs($1) } / Double(deviations.count)
            if average < 0.02 {
                return .tooPerfect
            }
        }
        return .plausible
    }
}
