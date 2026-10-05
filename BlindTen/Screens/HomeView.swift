import SwiftUI

/// SPEC.md Home: big PLAY button, mode picker cards, settings gear.
/// No onboarding; each card carries its one-line rules.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showingSettings = false
    @State private var paywallMode: ModeKind? = ScreenshotMode.scene == .paywall ? .liarsClock : nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tap START, the timer vanishes. Stop at exactly the target. Closest wins.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)

                NavigationLink {
                    PlayersView()
                } label: {
                    Text("PLAY")
                        .font(Theme.display(40))
                }
                .buttonStyle(.primary)

                VStack(spacing: 12) {
                    Button {
                        state.hostSession()
                    } label: {
                        Label("Host a session", systemImage: "tv")
                    }
                    NavigationLink {
                        JoinSessionView()
                    } label: {
                        Label("Join a session", systemImage: "iphone.radiowaves.left.and.right")
                    }
                }
                .buttonStyle(.secondary)
                Text("Everyone plays on their own iPhone; the host's screen shows the game on the TV.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)

                Text("Modes")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.top, 8)

                ForEach(ModeKind.allCases) { kind in
                    ModeCard(
                        kind: kind,
                        isSelected: state.selectedMode == kind,
                        isLocked: !PartyPack.canPlay(kind, unlocked: state.isPartyPackUnlocked)
                    ) {
                        // SPEC.md: the paywall appears only when tapping a locked mode card.
                        if PartyPack.canPlay(kind, unlocked: state.isPartyPackUnlocked) {
                            state.selectedMode = kind
                        } else {
                            paywallMode = kind
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Blind Ten")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                }
                .accessibilityLabel(Text("Settings"))
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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

