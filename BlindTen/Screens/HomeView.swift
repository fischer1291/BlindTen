import SwiftUI

/// SPEC.md Home: sorted by who you play with, not by technology.
/// "Up next" (only when something is waiting), Party on one phone, together
/// in the room on everyone's phone, Solo, Online. No onboarding; every tile
/// explains itself in one line. Modes are picked when setting up a game.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showingSettings = false
    /// Opens the duels when a "your turn" notification or "Up next" was tapped.
    @State private var showingDuels = false
    @State private var dailySession: ChallengeSession?
    @State private var today = DailyChallenge(date: .now)
    @State private var paywallMode: ModeKind? = ScreenshotMode.scene == .paywall ? .liarsClock : nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                upNext
                partyCard

                HomeSection(title: "Together in the room", symbol: "iphone.gen3.radiowaves.left.and.right")
                HStack(spacing: 12) {
                    Button {
                        state.hostSession()
                    } label: {
                        HomeTile(symbol: "tv", title: "Host", subtitle: "Show the game on the TV")
                    }
                    NavigationLink {
                        JoinSessionView()
                    } label: {
                        HomeTile(symbol: "iphone.radiowaves.left.and.right", title: "Join", subtitle: "Play on your own iPhone")
                    }
                }

                HomeSection(title: "Solo", symbol: "person.fill")
                HStack(spacing: 12) {
                    Button {
                        startDaily()
                    } label: {
                        HomeTile(
                            symbol: "calendar",
                            title: "Daily",
                            subtitle: dailySubtitle,
                            badge: dailyAttemptsLeft > 0 ? .count(dailyAttemptsLeft) : nil
                        )
                    }
                    .disabled(dailyAttemptsLeft == 0)
                    NavigationLink {
                        StreaksView()
                    } label: {
                        HomeTile(symbol: "flame.fill", title: "Streaks", subtitle: streakSubtitle)
                    }
                }

                HomeSection(title: "Online", symbol: "globe")
                HStack(spacing: 12) {
                    NavigationLink {
                        DuelListView()
                    } label: {
                        HomeTile(
                            symbol: "person.2.wave.2.fill",
                            title: "Duel",
                            subtitle: "Best of 3, whenever you like",
                            badge: yourTurnCount > 0 ? .count(yourTurnCount) : nil
                        )
                    }
                    NavigationLink {
                        LiveMatchMenuView()
                    } label: {
                        HomeTile(
                            symbol: "bolt.horizontal.fill",
                            title: "Live",
                            subtitle: "2 to 8 players at once",
                            badge: state.isPartyPackUnlocked ? nil : .locked
                        )
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(20)
        }
        .defaultScrollAnchor(ScreenshotMode.scene == .homeBottom ? .bottom : .top)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Blind Ten")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel(Text("Profile"))
            }
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
        .navigationDestination(isPresented: $showingDuels) {
            DuelListView()
        }
        .onChange(of: state.duels.pendingMatchID) { _, id in
            if id != nil, !state.duels.isListVisible { showingDuels = true }
        }
        .fullScreenCover(item: $dailySession) { session in
            ChallengeRunView(session: session) {}
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $paywallMode) { kind in
            PaywallView(mode: kind)
        }
        .onAppear {
            today = DailyChallenge(date: .now)
            if state.duels.pendingMatchID != nil, !state.duels.isListVisible { showingDuels = true }
        }
    }

    // MARK: - Party

    private var partyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Party", systemImage: "iphone")
                .font(.title2.weight(.heavy))
            Text("One phone, pass it around. Tap START, the timer vanishes. Stop at exactly the target. Closest wins.")
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                PlayersView()
            } label: {
                Text("PLAY")
                    .font(Theme.display(40))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(Theme.onAccent, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .foregroundStyle(Theme.onAccent)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Up next

    /// Only for returning players: today's Daily if they play challenges,
    /// and duels waiting for their turn.
    @ViewBuilder
    private var upNext: some View {
        let duels = state.duels.duels.filter { $0.status == .yourTurn }.prefix(2)
        let showsDaily = isReturningPlayer && dailyAttemptsLeft > 0
        if showsDaily || !duels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Up next")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.secondaryText)
                    .textCase(.uppercase)
                if showsDaily {
                    Button {
                        startDaily()
                    } label: {
                        UpNextRow(symbol: "calendar", text: Text("Daily Challenge: stop at \(TimeFormat.seconds(today.target)) s"))
                    }
                }
                ForEach(Array(duels)) { duel in
                    Button {
                        state.duels.pendingMatchID = duel.id
                    } label: {
                        UpNextRow(
                            symbol: "person.2.wave.2.fill",
                            text: Text("Your turn against \(duel.opponentName ?? String(localized: "Opponent"))")
                        )
                    }
                }
            }
        }
    }

    // MARK: - Solo

    private var dailyAttemptsLeft: Int {
        state.challengeRecords.attemptsLeft(for: today.day)
    }

    private var dailySubtitle: LocalizedStringKey {
        dailyAttemptsLeft > 0 ? "Today: stop at \(TimeFormat.seconds(today.target)) s" : "Done for today"
    }

    private var streakSubtitle: LocalizedStringKey {
        let best = ChallengeKind.allCases.flatMap { kind in
            ChallengeDifficulty.allCases.map { state.challengeRecords.stats(kind, $0).best }
        }.max() ?? 0
        return best > 0 ? "Your best: \(best) in a row" : "Hit after hit until a miss"
    }

    private var isReturningPlayer: Bool {
        let records = state.challengeRecords
        return records.totalRuns > 0 || records.dailyDaysPlayed > 0
            || records.duelWins + records.duelLosses + records.duelDraws > 0
    }

    private var yourTurnCount: Int {
        state.duels.duels.filter { $0.status == .yourTurn }.count
    }

    private func startDaily() {
        today = DailyChallenge(date: .now)
        guard dailyAttemptsLeft > 0 else { return }
        state.gameCenter.authenticate()
        dailySession = state.makeChallengeSession(.daily(today))
    }
}

// MARK: - Building blocks

/// A section heading with the symbol of how you play.
private struct HomeSection: View {
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.title3.weight(.heavy))
            .foregroundStyle(Theme.primaryText)
            .padding(.top, 10)
    }
}

/// One of two tiles in a row: symbol, title, one line, optional badge.
private struct HomeTile: View {
    enum Badge {
        case count(Int)
        case locked
    }

    let symbol: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var badge: Badge?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Spacer()
                switch badge {
                case .count(let count):
                    Text(verbatim: "\(count)")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Theme.onAccent)
                        .frame(minWidth: 26, minHeight: 26)
                        .background(Theme.accent, in: Capsule())
                case .locked:
                    Image(systemName: "lock.fill")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Theme.secondaryText)
                case nil:
                    EmptyView()
                }
            }
            Text(title)
                .font(.title3.weight(.heavy))
                .foregroundStyle(Theme.primaryText)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct UpNextRow: View {
    let symbol: String
    let text: Text

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
            text
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(14)
        .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
