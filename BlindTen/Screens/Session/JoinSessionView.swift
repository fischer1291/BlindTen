import SwiftUI

/// Pick a name and avatar, then a session nearby. The name, avatar and
/// player ID are remembered, so a dropped phone rejoins as the same player.
struct JoinSessionView: View {
    @Environment(AppState.self) private var state
    @AppStorage(SessionIdentity.nameKey) private var name = ""
    @AppStorage(SessionIdentity.emojiKey) private var emoji = Avatar.pool[0]
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Play on your own iPhone while the host's screen shows the game.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)

                TextField("Your name", text: $name)
                    .font(.title2.weight(.bold))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .padding(16)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .disabled(state.sessionClient != nil)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Avatar.pool, id: \.self) { option in
                            Button {
                                emoji = option
                            } label: {
                                Text(verbatim: option)
                                    .font(.system(size: 36))
                                    .frame(width: 60, height: 60)
                                    .background(
                                        option == emoji ? Theme.accent : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: 14)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(option == emoji ? .isSelected : [])
                        }
                    }
                }
                .disabled(state.sessionClient != nil)

                if let client = state.sessionClient {
                    sessions(client)
                } else {
                    Button("Find sessions") {
                        nameFocused = false
                        if let player = SessionIdentity.player(name: name, emoji: emoji) {
                            state.joinSession(as: player)
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(trimmedName.isEmpty)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Join a session")
        .onDisappear {
            // Leaving this screen without getting in stops the search.
            if state.sessionClient?.isInSession == false {
                state.leaveSession()
            }
        }
    }

    @ViewBuilder
    private func sessions(_ client: SessionClient) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Looking for sessions nearby…")
                .font(.headline)
        }
        .foregroundStyle(Theme.secondaryText)

        switch client.status {
        case .rejected(let reason):
            Text(reason.message)
                .font(.headline)
                .foregroundStyle(Theme.late)
        case .connecting(let hostName):
            Text("Joining \(hostName)…")
                .font(.headline)
        case .browsing, .connected, .reconnecting:
            EmptyView()
        }

        ForEach(client.hosts) { host in
            Button {
                client.join(host)
            } label: {
                HStack {
                    Text(verbatim: host.name)
                        .font(.system(size: 40))
                    Spacer()
                    Text("Join")
                        .font(.title3.weight(.heavy))
                }
                .padding(18)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
        }

        if client.hosts.isEmpty {
            Text("Ask the host to tap \"Host a session\". Both phones need Wi-Fi or Bluetooth turned on.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }

        Button("Cancel") {
            state.leaveSession()
        }
        .buttonStyle(.secondary)
    }
}

extension SessionRejection {
    var message: LocalizedStringKey {
        switch self {
        case .full: "This session is full."
        case .gameInProgress: "A game is running. Join when it is back in the lobby."
        case .incompatibleVersion: "Update Blind Ten on both phones to play together."
        }
    }
}
