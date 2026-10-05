import Foundation

/// Target 10.00 s, dark screen.
struct ClassicMode: GameMode {
    let kind = ModeKind.classic
}

/// Each turn gets a new target between 4 and 20 s, e.g. 13.37.
struct RandomTargetMode: GameMode {
    let kind = ModeKind.randomTarget
    static let targetRange: ClosedRange<TimeInterval> = 4...20

    func makeTarget<G: RandomNumberGenerator>(using generator: inout G) -> TimeInterval {
        let raw = TimeInterval.random(in: Self.targetRange, using: &generator)
        return (raw * 100).rounded() / 100
    }
}

/// Two players at once on a split screen. Closest wins the duel.
struct ShowdownMode: GameMode {
    let kind = ModeKind.showdown
    var playersPerTurn: Int { 2 }

    func turns(round: Int, players: [Player.ID]) -> [[Player.ID]] {
        Showdown.pairings(round: round, players: players)
    }
}

/// Random beeps at irregular intervals during the blind phase.
struct DistractionMode: GameMode {
    let kind = ModeKind.distraction

    func makeBlindEffect<G: RandomNumberGenerator>(target: TimeInterval, using generator: inout G) -> BlindEffect {
        .distraction(beepTimes: Distraction.beepTimes(until: Scoring.timeoutDuration(for: target), using: &generator))
    }
}

/// A countdown that runs 10–30 % too fast or too slow.
struct LiarsClockMode: GameMode {
    let kind = ModeKind.liarsClock

    func makeBlindEffect<G: RandomNumberGenerator>(target: TimeInterval, using generator: inout G) -> BlindEffect {
        .liarsClock(rate: LiarsClock.randomRate(using: &generator))
    }
}

/// A steady haptic pulse that is slightly off, e.g. every 0.9 s.
struct HeartbeatMode: GameMode {
    let kind = ModeKind.heartbeat

    func makeBlindEffect<G: RandomNumberGenerator>(target: TimeInterval, using generator: inout G) -> BlindEffect {
        .heartbeat(interval: Heartbeat.randomInterval(using: &generator))
    }
}

/// The worst player each round is out until one is left.
struct EliminationMode: GameMode {
    let kind = ModeKind.elimination
    var eliminatesRoundLoser: Bool { true }

    func roundCount(requested: Int, playerCount: Int) -> Int {
        max(1, playerCount - 1)
    }
}

/// Two teams, summed deviation.
struct TeamsMode: GameMode {
    let kind = ModeKind.teams
    var hasTeams: Bool { true }
}

// MARK: - Rule helpers

enum Showdown {
    /// Round-robin duels (circle method), so opponents change every round.
    /// With an odd number of players one player sits out each round, in turn.
    static func pairings(round: Int, players: [Player.ID]) -> [[Player.ID]] {
        guard players.count >= 2 else { return players.map { [$0] } }
        var seats: [Player.ID?] = players
        if !seats.count.isMultiple(of: 2) {
            seats.append(nil)
        }
        let rest = Array(seats.dropFirst())
        let shift = (max(round, 1) - 1) % rest.count
        let rotated = [seats[0]] + Array(rest[(rest.count - shift)...]) + Array(rest[..<(rest.count - shift)])
        var duels: [[Player.ID]] = []
        for index in 0..<(rotated.count / 2) {
            if let first = rotated[index], let second = rotated[rotated.count - 1 - index] {
                duels.append([first, second])
            }
        }
        return duels
    }
}

enum Distraction {
    static let gapRange: ClosedRange<TimeInterval> = 0.35...2.6
    /// Gaps near one second would give the rhythm away, so they are skipped.
    static let forbiddenGaps: ClosedRange<TimeInterval> = 0.85...1.15
    /// Consecutive gaps differ at least this much, so no steady beat forms.
    static let minimumGapChange: TimeInterval = 0.2

    static func beepTimes<G: RandomNumberGenerator>(until end: TimeInterval, using generator: inout G) -> [TimeInterval] {
        var times: [TimeInterval] = []
        var time: TimeInterval = 0
        var lastGap: TimeInterval?
        while true {
            var gap: TimeInterval
            repeat {
                gap = TimeInterval.random(in: gapRange, using: &generator)
            } while forbiddenGaps.contains(gap) || (lastGap.map { abs($0 - gap) < minimumGapChange } ?? false)
            time += gap
            guard time < end else { break }
            times.append(time)
            lastGap = gap
        }
        return times
    }
}

enum LiarsClock {
    static let slowRates: ClosedRange<Double> = 0.7...0.9
    static let fastRates: ClosedRange<Double> = 1.1...1.3

    static func randomRate<G: RandomNumberGenerator>(using generator: inout G) -> Double {
        let fast = Bool.random(using: &generator)
        return Double.random(in: fast ? fastRates : slowRates, using: &generator)
    }

    /// Seconds left on the lying countdown.
    static func displayedRemaining(elapsed: TimeInterval, target: TimeInterval, rate: Double) -> TimeInterval {
        max(0, target - max(0, elapsed) * rate)
    }
}

enum Heartbeat {
    static let fastIntervals: ClosedRange<TimeInterval> = 0.75...0.92
    static let slowIntervals: ClosedRange<TimeInterval> = 1.08...1.25

    static func randomInterval<G: RandomNumberGenerator>(using generator: inout G) -> TimeInterval {
        let fast = Bool.random(using: &generator)
        return TimeInterval.random(in: fast ? fastIntervals : slowIntervals, using: &generator)
    }
}

enum Teams {
    static let count = 2

    /// Alternating by roster order: 1st, 3rd, 5th … in team 0.
    static func team(forPlayerAt index: Int) -> Int {
        index % count
    }
}
