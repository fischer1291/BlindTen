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
