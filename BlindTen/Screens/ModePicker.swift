import SwiftUI

/// The mode cards, step 2 of setting up a party game. Each card carries its
/// one-line rules; tapping a locked card opens the paywall (SPEC.md).
struct ModePicker: View {
    @Environment(AppState.self) private var state
    @State private var paywallMode: ModeKind?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(ModeKind.allCases) { kind in
                ModeCard(
                    kind: kind,
                    isSelected: state.selectedMode == kind,
                    isLocked: !PartyPack.canPlay(kind, unlocked: state.isPartyPackUnlocked)
                ) {
                    if PartyPack.canPlay(kind, unlocked: state.isPartyPackUnlocked) {
                        state.selectedMode = kind
                    } else {
                        paywallMode = kind
                    }
                }
            }
        }
        .sheet(item: $paywallMode) { kind in
            PaywallView(mode: kind)
        }
        .onAppear {
            // A refunded or revoked Party Pack must not leave a locked mode selected.
            if !PartyPack.canPlay(state.selectedMode, unlocked: state.isPartyPackUnlocked) {
                state.selectedMode = .classic
            }
        }
    }
}

private struct ModeCard: View {
    let kind: ModeKind
    let isSelected: Bool
    let isLocked: Bool
    let select: () -> Void

    var body: some View {
        Button {
            select()
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: kind.symbol)
                    .font(.title)
                    .frame(width: 40)
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.accent)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(kind.title)
                            .font(.title2.weight(.heavy))
                        if !kind.isFree {
                            Label {
                                Text("Party Pack")
                            } icon: {
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                }
                            }
                                .font(.caption.weight(.heavy))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    isSelected ? Theme.onAccent.opacity(0.15) : Theme.accent.opacity(0.2),
                                    in: Capsule()
                                )
                        }
                    }
                    Text(kind.rules)
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                }
            }
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.primaryText)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.accent : Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

