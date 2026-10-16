import SwiftUI

/// Entry to Live Match: quick match with random players or invite friends.
/// Part of the Party Pack; an invited friend can join without it.
struct LiveMatchMenuView: View {
    @Environment(AppState.self) private var state
    @State private var showsPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("2 to 8 players online at the same time. Everyone gets the same target, the timer starts by itself, and all results land together.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !state.isPartyPackUnlocked {
                    Label("Party Pack", systemImage: "lock.fill")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.accent)
                    Text("Starting a live match needs the Party Pack. Friends you invite can join for free.")
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Get the Party Pack") {
                        showsPaywall = true
                    }
                    .buttonStyle(.primary)
                } else if state.gameCenter.isAuthenticated {
                    Button {
                        state.live.findMatch(inviteFriends: false)
                    } label: {
                        Label("Quick match", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.primary)
                    Button {
                        state.live.findMatch(inviteFriends: true)
                    } label: {
                        Label("Invite friends", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.secondary)
                } else {
                    Text(state.gameCenter.hasAnswered
                         ? LocalizedStringKey("Live matches use Game Center. Sign in to Game Center in the Settings app to play.")
                         : LocalizedStringKey("Connecting to Game Center…"))
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let error = state.live.lastError {
                    Text(verbatim: error)
                        .font(.footnote)
                        .foregroundStyle(Theme.late)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Live Match")
        .onAppear {
            state.gameCenter.authenticate()
        }
        .sheet(isPresented: $showsPaywall) {
            PaywallView(mode: .liarsClock)
        }
    }
}
