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
