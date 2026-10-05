import SwiftUI
import Testing
@testable import BlindTen

@MainActor
struct BrandTests {
    @Test func handHidesOnlyInTheGap() {
        #expect(!LogoMark.handIsInGap(.degrees(0)))      // 12 o'clock
        #expect(!LogoMark.handIsInGap(.degrees(90)))     // 3 o'clock
        #expect(!LogoMark.handIsInGap(.degrees(180)))    // 6 o'clock
        #expect(LogoMark.handIsInGap(.degrees(215)))     // bottom left, in the gap
        #expect(!LogoMark.handIsInGap(.degrees(270)))    // 9 o'clock
        #expect(LogoMark.handIsInGap(.degrees(215 + 360)))
        #expect(LogoMark.handIsInGap(.degrees(215 - 360)))
    }

    @Test func splashSweepsOnceAndLandsOnTwelve() {
        #expect(SplashView.handAngle(elapsed: 0, reduceMotion: false).degrees == 0)
        #expect(SplashView.handAngle(elapsed: SplashView.sweepDuration, reduceMotion: false).degrees == 360)
        #expect(SplashView.handAngle(elapsed: 10, reduceMotion: false).degrees == 360)
        #expect(SplashView.handAngle(elapsed: 0.3, reduceMotion: true).degrees == 0)
    }

    @Test func pulseFollowsTheSweep() {
        #expect(SplashView.pulseProgress(elapsed: 0.5, reduceMotion: false) == nil)
        let mid = SplashView.sweepDuration + SplashView.pulseDuration / 2
        #expect(SplashView.pulseProgress(elapsed: mid, reduceMotion: false) != nil)
        #expect(SplashView.pulseProgress(elapsed: 5, reduceMotion: false) == nil)
        #expect(SplashView.pulseProgress(elapsed: mid, reduceMotion: true) == nil)
    }

    @Test func launchAssetsShipInTheBundle() {
        #expect(UIImage(named: "LaunchLogo") != nil)
        #expect(UIColor(named: "LaunchBackground") != nil)
    }
}
