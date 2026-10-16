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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.selectedMode = kind
                        }
                    } else {
                        paywallMode = kind
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: state.selectedMode)
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
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Image(systemName: kind.symbol)
                    .font(.title2)
                    .frame(width: 44)
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.accent)
                    .symbolEffect(.bounce, value: isSelected)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(kind.title)
                            .font(.title2.weight(.heavy))
                        if !kind.isFree {
                            HStack(spacing: 4) {
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                }
                                Text("Party Pack")
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
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.primaryText)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.accent : Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

