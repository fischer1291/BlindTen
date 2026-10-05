import SwiftUI

extension Tier {
    /// Localized tier label from the SPEC.md scoring table.
    var label: LocalizedStringKey {
        switch self {
        case .deadOn: "DEAD ON"
        case .sharp: "Sharp"
        case .close: "Close"
        case .meh: "Meh"
        case .off: "Off"
        case .lostInTime: "Lost in time"
        }
    }
}

extension ModeKind {
    var title: LocalizedStringKey {
        switch self {
        case .classic: "Classic"
        case .randomTarget: "Random Target"
        case .showdown: "Showdown"
        case .distraction: "Distraction"
        case .liarsClock: "Liar's Clock"
        case .heartbeat: "Heartbeat"
        case .elimination: "Elimination"
        case .teams: "Teams"
        }
    }

    /// SPEC.md: rules are one line under the mode card.
    var rules: LocalizedStringKey {
        switch self {
        case .classic: "Stop at exactly 10 seconds. Dark screen."
        case .randomTarget: "A new target every turn, from 4 to 20 seconds."
        case .showdown: "Two players at once on a split screen. Closest wins the duel."
        case .distraction: "Random beeps try to throw you off. Heckling allowed."
        case .liarsClock: "A countdown runs too fast or too slow. Ignore it."
        case .heartbeat: "The phone pulses at a slightly wrong tempo."
        case .elimination: "The worst player each round is out until one is left."
        case .teams: "Two teams. The lowest combined deviation wins."
        }
    }

    var symbol: String {
        switch self {
        case .classic: "timer"
        case .randomTarget: "dice.fill"
        case .showdown: "person.2.fill"
        case .distraction: "speaker.wave.3.fill"
        case .liarsClock: "clock.badge.questionmark"
        case .heartbeat: "heart.fill"
        case .elimination: "person.fill.xmark"
        case .teams: "person.3.fill"
        }
    }
}

/// "Team 1" / "Team 2".
struct TeamName: View {
    let team: Int

    var body: some View {
        Text("Team \(team + 1)")
    }
}

extension Theme {
    static func color(forTeam team: Int) -> Color {
        team == 0 ? early : Color(red: 1.0, green: 0.55, blue: 0.2)
    }
}
