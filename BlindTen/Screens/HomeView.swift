import SwiftUI

/// SPEC.md Home: big PLAY button, mode picker cards, settings gear.
/// No onboarding; each card carries its one-line rules.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showingSettings = false

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

                Text("Modes")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.top, 8)

                ForEach(ModeKind.allCases) { kind in
                    ModeCard(kind: kind, isSelected: state.selectedMode == kind) {
                        state.selectedMode = kind
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
    }
}

private struct ModeCard: View {
    let kind: ModeKind
    let isSelected: Bool
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
                            Text("Party Pack")
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

/// Settings sheet behind the gear.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SoundSettings.enabledKey) private var soundEnabled = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Sound", isOn: $soundEnabled)
                        .font(.title3)
                } footer: {
                    Text("Sounds follow the silent switch.")
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
