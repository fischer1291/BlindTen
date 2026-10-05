import Foundation

/// One entry point for haptics and sound during a game.
@MainActor
final class GameFeel {
    private let haptics = Haptics()
    private let sound = SoundPlayer()
    private var isPrepared = false

    /// Starts the haptic engine and preloads sounds. Safe to call repeatedly.
    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        haptics.prepare()
        sound.prepare()
    }

    /// Call when a turn screen appears, so START responds instantly.
    func warmUp() {
        prepare()
        haptics.warmUp()
    }

    /// Sharp tap on START and STOP.
    func touch() {
        haptics.tap()
    }

    func beginDrumroll(duration: TimeInterval) {
        haptics.startDrumroll(duration: duration)
        sound.play(.drumroll)
    }

    func endDrumroll() {
        haptics.stopDrumroll()
        sound.stop(.drumroll)
    }

    /// Heartbeat mode pulse during the blind phase.
    func startHeartbeat(interval: TimeInterval) {
        haptics.startHeartbeat(interval: interval)
    }

    func stopHeartbeat() {
        haptics.stopHeartbeat()
    }

    /// One Distraction beep, in a random pitch.
    func beep() {
        sound.play(SoundPlayer.Effect.beeps.randomElement() ?? .beep1)
    }

    /// Stops everything that may still run when a screen goes away.
    func stopAll() {
        endDrumroll()
        stopHeartbeat()
    }

    /// The moment the result lands.
    func land(_ cue: LandingCue) {
        endDrumroll()
        switch cue {
        case .deadOn:
            haptics.deadOn()
            sound.play(.cymbal)
        case .fail:
            haptics.fail()
            sound.play(.trombone)
        case .neutral:
            haptics.land()
        }
    }
}
