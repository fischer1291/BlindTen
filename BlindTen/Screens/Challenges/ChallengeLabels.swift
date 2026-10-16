import SwiftUI

extension ChallengeSession: Identifiable {}

extension ChallengeKind {
    var title: LocalizedStringKey {
        switch self {
        case .classic: "Classic"
        case .randomTarget: "Random Target"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .classic: "Always 10 seconds."
        case .randomTarget: "A new target every turn, from 4 to 20 seconds."
        }
    }

    var symbol: String {
        switch self {
        case .classic: "timer"
        case .randomTarget: "dice.fill"
        }
    }
}

extension ChallengeDifficulty {
    var title: LocalizedStringKey {
        switch self {
        case .pro: "Pro"
        case .close: "Close"
        }
    }

    /// "within 0.25 s" or "within 2.5% of the target".
    func toleranceText(for kind: ChallengeKind) -> Text {
        switch kind {
        case .classic:
            let seconds = StreakRules.tolerance(kind: kind, difficulty: self, target: GameEngine.classicTarget)
            return Text("within \(TimeFormat.seconds(seconds)) s")
        case .randomTarget:
            let share = StreakRules.tolerance(kind: kind, difficulty: self, target: 1)
            return Text("within \(share.formatted(.percent)) of the target")
        }
    }
}

extension BlindEffect {
    /// The mode this effect comes from, for the Daily Challenge card.
    var modeTitle: LocalizedStringKey {
        switch self {
        case .dark: ModeKind.classic.title
        case .distraction: ModeKind.distraction.title
        case .liarsClock: ModeKind.liarsClock.title
        case .heartbeat: ModeKind.heartbeat.title
        }
    }
}

extension ChallengeMode {
    var title: Text {
        switch self {
        case .streak(let kind, let difficulty):
            Text("\(Text(kind.title)) · \(Text(difficulty.title))")
        case .daily:
            Text("Daily Challenge")
        }
    }
}
