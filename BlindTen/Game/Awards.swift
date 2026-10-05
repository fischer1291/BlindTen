import Foundation

/// The stats a turn contributes to awards. Built from a live `TurnResult`
/// or from a stored turn.
struct TurnStat: Equatable, Sendable {
    let playerID: UUID
    /// Signed deviation in seconds (negative = too early).
    let deviation: TimeInterval
    let outcome: TurnOutcome

    init(playerID: UUID, deviation: TimeInterval, outcome: TurnOutcome) {
        self.playerID = playerID
        self.deviation = deviation
        self.outcome = outcome
    }

    init(_ result: TurnResult) {
        self.init(playerID: result.playerID, deviation: result.deviation, outcome: result.outcome)
    }

    var isEarly: Bool { Scoring.roundedToHundredths(deviation) < 0 }
    var isLate: Bool { Scoring.roundedToHundredths(deviation) > 0 }
}

/// SPEC.md "Streaks & stats": funny awards on the results screen.
enum AwardKind: String, CaseIterable, Sendable {
    /// Closest single turn ever.
    case bestEver
    /// Most DEAD ONs.
    case deadEye
    /// Almost always too early ("The Impatient One").
    case impatient
    /// Almost always too late.
    case dawdler
    /// Most misfires.
    case hairTrigger
}

struct Award: Equatable, Sendable {
    let kind: AwardKind
    let playerID: UUID
    /// Best ever: deviation in seconds. Dead eye / hair trigger: a count.
    /// Impatient / dawdler: a share between 0 and 1.
    let value: Double
}

enum Awards {
    /// A tendency award needs at least this many turns from a player.
    static let minimumTurnsForTendency = 3
    /// …and at least this share of early (or late) stops.
    static let tendencyThreshold = 0.6
    static let minimumMisfires = 2

    /// Awards in `AwardKind` order. Ties go to the player who played first.
    static func compute(from turns: [TurnStat]) -> [Award] {
        var order: [UUID] = []
        for turn in turns where !order.contains(turn.playerID) {
            order.append(turn.playerID)
        }
        func turnsOf(_ id: UUID) -> [TurnStat] { turns.filter { $0.playerID == id } }

        var awards: [Award] = []

        let timed = turns.filter { turn in
            if case .scored = turn.outcome { return true }
            return false
        }
        if let best = timed.min(by: { abs($0.deviation) < abs($1.deviation) }) {
            awards.append(Award(kind: .bestEver, playerID: best.playerID, value: abs(best.deviation)))
        }

        if let top = leader(order, metric: { id in
            Double(turnsOf(id).filter { $0.outcome == .scored(.deadOn) }.count)
        }), top.value >= 1 {
            awards.append(Award(kind: .deadEye, playerID: top.id, value: top.value))
        }

        for (kind, isMatch) in [(AwardKind.impatient, \TurnStat.isEarly), (.dawdler, \TurnStat.isLate)] {
            if let top = leader(order, metric: { id in
                let mine = turnsOf(id)
                guard mine.count >= minimumTurnsForTendency else { return nil }
                return Double(mine.filter { $0[keyPath: isMatch] }.count) / Double(mine.count)
            }), top.value >= tendencyThreshold {
                awards.append(Award(kind: kind, playerID: top.id, value: top.value))
            }
        }

        if let top = leader(order, metric: { id in
            Double(turnsOf(id).filter { $0.outcome == .misfire }.count)
        }), top.value >= Double(minimumMisfires) {
            awards.append(Award(kind: .hairTrigger, playerID: top.id, value: top.value))
        }

        return awards
    }

    /// The player with the highest metric; earlier players win ties.
    private static func leader(_ order: [UUID], metric: (UUID) -> Double?) -> (id: UUID, value: Double)? {
        var best: (id: UUID, value: Double)?
        for id in order {
            guard let value = metric(id) else { continue }
            if let current = best, value <= current.value { continue }
            best = (id, value)
        }
        return best
    }
}
