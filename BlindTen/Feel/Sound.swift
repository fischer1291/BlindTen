@preconcurrency import AVFoundation

enum SoundSettings {
    /// UserDefaults key for the in-app sound toggle. Defaults to on.
    static let enabledKey = "soundEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }
}

/// Preloaded short sound effects on an ambient audio session: they mix with
/// the bar's music, never stop the user's own playback, and follow the
/// ringer/silent switch.
@MainActor
final class SoundPlayer {
    enum Effect: String, CaseIterable {
        case drumroll
        case cymbal
        case trombone
        case beep1
        case beep2
        case beep3

        static let beeps: [Effect] = [.beep1, .beep2, .beep3]
    }

    private var players: [Effect: AVAudioPlayer] = [:]
    private var isPrepared = false

    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
        for effect in Effect.allCases {
            guard
                let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
                let player = try? AVAudioPlayer(contentsOf: url)
            else { continue }
            player.prepareToPlay()
            players[effect] = player
        }
    }

    func play(_ effect: Effect) {
        guard SoundSettings.isEnabled, let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    func stop(_ effect: Effect) {
        guard let player = players[effect], player.isPlaying else { return }
        player.stop()
        player.currentTime = 0
    }
}
