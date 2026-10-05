import Foundation
import Testing
@testable import BlindTen

@MainActor
struct SoundTests {
    @Test("Every sound effect ships in the app bundle", arguments: SoundPlayer.Effect.allCases)
    func effectIsBundled(effect: SoundPlayer.Effect) {
        #expect(Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") != nil)
    }

    @Test func soundIsOnByDefault() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: SoundSettings.enabledKey)
        defaults.removeObject(forKey: SoundSettings.enabledKey)
        #expect(SoundSettings.isEnabled)
        defaults.set(saved, forKey: SoundSettings.enabledKey)
    }
}
