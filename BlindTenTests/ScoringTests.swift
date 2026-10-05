import Foundation
import Testing
@testable import BlindTen

struct ScoringTests {
    @Test("Tier boundaries from the spec table", arguments: [
        (0.00, Tier.deadOn),
        (0.05, Tier.deadOn),
        (0.0549, Tier.deadOn),
        (0.06, Tier.sharp),
        (0.25, Tier.sharp),
        (0.26, Tier.close),
        (0.50, Tier.close),
        (0.51, Tier.meh),
        (1.00, Tier.meh),
        (1.01, Tier.off),
        (2.00, Tier.off),
        (2.01, Tier.lostInTime),
        (7.50, Tier.lostInTime),
    ])
    func tierBoundaries(deviation: Double, expected: Tier) {
        #expect(Scoring.tier(forDeviation: deviation) == expected)
        #expect(Scoring.tier(forDeviation: -deviation) == expected)
    }

    @Test("Points per tier", arguments: [
        (Tier.deadOn, 10),
        (Tier.sharp, 7),
        (Tier.close, 5),
        (Tier.meh, 3),
        (Tier.off, 1),
        (Tier.lostInTime, 0),
    ])
    func pointsPerTier(tier: Tier, points: Int) {
        #expect(tier.points == points)
    }

    @Test("Boundary values give the spec points", arguments: [
        (0.05, 10),
        (0.25, 7),
        (0.5, 5),
        (1.0, 3),
        (2.0, 1),
    ])
    func boundaryPoints(deviation: Double, points: Int) {
        #expect(Scoring.points(forDeviation: deviation) == points)
    }

    @Test("Deviation computed from real stop times is not hurt by floating-point noise")
    func floatingPointNoise() {
        #expect(Scoring.tier(forDeviation: 10.05 - 10.0) == .deadOn)
        #expect(Scoring.tier(forDeviation: 9.95 - 10.0) == .deadOn)
        #expect(Scoring.tier(forDeviation: 10.25 - 10.0) == .sharp)
        #expect(Scoring.tier(forDeviation: 12.0 - 10.0) == .off)
    }

    @Test("Non-finite deviations are lost in time")
    func nonFinite() {
        #expect(Scoring.tier(forDeviation: .nan) == .lostInTime)
        #expect(Scoring.tier(forDeviation: .infinity) == .lostInTime)
        #expect(Scoring.tier(forDeviation: 1e300) == .lostInTime)
    }

    @Test("Stopping before 1.0 s is a misfire worth 0 points")
    func misfire() {
        #expect(Scoring.outcome(elapsed: 0.0, target: 10) == .misfire)
        #expect(Scoring.outcome(elapsed: 0.99, target: 10) == .misfire)
        #expect(Scoring.outcome(elapsed: 0.99, target: 10).points == 0)
        #expect(Scoring.outcome(elapsed: 1.0, target: 10) == .scored(.lostInTime))
    }

    @Test("No stop after target × 3 is a timeout worth 0 points")
    func timeout() {
        #expect(Scoring.timeoutDuration(for: 10) == 30)
        #expect(Scoring.outcome(elapsed: 29.99, target: 10) == .scored(.lostInTime))
        #expect(Scoring.outcome(elapsed: 30.0, target: 10) == .timeout)
        #expect(Scoring.outcome(elapsed: 30.0, target: 10).points == 0)
    }

    @Test("A normal stop is scored by its deviation")
    func scored() {
        #expect(Scoring.outcome(elapsed: 10.27, target: 10) == .scored(.close))
        #expect(Scoring.outcome(elapsed: 10.0, target: 10) == .scored(.deadOn))
        #expect(Scoring.outcome(elapsed: 10.27, target: 10).points == 5)
    }

    @Test("Rounding to hundredths normalizes negative zero")
    func rounding() {
        #expect(Scoring.roundedToHundredths(0.274) == 0.27)
        #expect(Scoring.roundedToHundredths(-1.034) == -1.03)
        #expect(Scoring.roundedToHundredths(-0.001) == 0)
        #expect(Scoring.roundedToHundredths(-0.001).sign == .plus)
    }
}

struct TimeFormatTests {
    let english = Locale(identifier: "en_US")

    @Test func secondsUseTwoDecimals() {
        #expect(TimeFormat.seconds(10, locale: english) == "10.00")
        #expect(TimeFormat.seconds(10.274, locale: english) == "10.27")
        #expect(TimeFormat.seconds(10.27, locale: Locale(identifier: "de_DE")) == "10,27")
    }

    @Test func deviationsAreAlwaysSigned() {
        #expect(TimeFormat.signedDeviation(0.27, locale: english) == "+0.27")
        #expect(TimeFormat.signedDeviation(-1.034, locale: english) == "-1.03")
        #expect(TimeFormat.signedDeviation(-0.001, locale: english) == "+0.00")
    }
}
