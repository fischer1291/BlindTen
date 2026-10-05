import SwiftData
import SwiftUI

/// Settings sheet behind the gear: sound, house rules, Party Pack.
struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SoundSettings.enabledKey) private var soundEnabled = true
    @AppStorage(HouseRuleSettings.enabledKey) private var houseRulesEnabled = false
    @State private var showingPaywall = false

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

                Section {
                    Toggle("House rules", isOn: $houseRulesEnabled)
                        .font(.title3)
                    NavigationLink("Edit cards") {
                        HouseRulesView()
                    }
                    .font(.title3)
                } footer: {
                    Text("The loser of each round draws a card.")
                }
                .listRowBackground(Theme.surface)

                Section {
                    if state.isPartyPackUnlocked {
                        Label("Party Pack unlocked", systemImage: "checkmark.seal.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    } else {
                        Button("Get the Party Pack") {
                            showingPaywall = true
                        }
                        .font(.title3.weight(.semibold))
                    }
                    Button("Restore Purchases") {
                        Task { await state.purchases.restore() }
                    }
                    .font(.title3)
                    if let issue = state.purchases.issue {
                        IssueText(issue: issue)
                    }
                } header: {
                    Text("Party Pack")
                }
                .listRowBackground(Theme.surface)

                Section {
                    Link("Privacy Policy", destination: WebLinks.privacy)
                    Link("Contact & Support", destination: WebLinks.support)
                    Link("Imprint", destination: WebLinks.imprint)
                }
                .font(.title3)
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
            .sheet(isPresented: $showingPaywall) {
                PaywallView(mode: nil)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// The house-rule deck: built-in cards can be switched off, custom cards
/// (Party Pack) can be added and deleted.
struct HouseRulesView: View {
    @Environment(AppState.self) private var state
    @Query(sort: \HouseRule.createdAt) private var rules: [HouseRule]
    @State private var newCard = ""

    private var canAddCustom: Bool {
        PartyPack.canAddCustomHouseRules(unlocked: state.isPartyPackUnlocked)
    }

    var body: some View {
        List {
            Section {
                ForEach(rules) { rule in
                    Toggle(isOn: Binding(
                        get: { rule.isEnabled },
                        set: { rule.isEnabled = $0; state.store?.save() }
                    )) {
                        Text(verbatim: rule.displayText)
                            .font(.body.weight(.semibold))
                    }
                    .deleteDisabled(!rule.isCustom)
                }
                .onDelete { offsets in
                    for index in offsets where rules[index].isCustom {
                        state.store?.delete(rules[index])
                    }
                }
            } footer: {
                Text("Switched-off cards are never drawn.")
            }
            .listRowBackground(Theme.surface)

            Section {
                if canAddCustom {
                    TextField("Write your own card", text: $newCard)
                        .submitLabel(.done)
                        .onSubmit { addCard() }
                } else {
                    Label("Your own cards come with the Party Pack.", systemImage: "lock.fill")
                        .foregroundStyle(Theme.secondaryText)
                }
            } header: {
                Text("Your own cards")
            } footer: {
                Text("Cards stay on this phone.")
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("House rules")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addCard() {
        guard canAddCustom, state.store?.addCustomHouseRule(newCard) != nil else { return }
        newCard = ""
    }
}
