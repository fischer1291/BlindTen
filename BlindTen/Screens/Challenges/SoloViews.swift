import SwiftUI

/// The four streaks with personal bests (SPEC.md "Version 2"). Free.
struct StreaksView: View {
    @Environment(AppState.self) private var state
    @State private var activeSession: ChallengeSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Hit after hit until the first miss. Pro is tight, Close is forgiving.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                SeasonCard(season: Season(date: .now))
                ForEach(ChallengeKind.allCases, id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: kind.symbol)
                                .frame(width: 30, alignment: .leading)
                            Text(kind.title)
                        }
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Theme.primaryText)
                        Text(kind.subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.secondaryText)
                        HStack(spacing: 12) {
                            ForEach(ChallengeDifficulty.allCases, id: \.self) { difficulty in
                                StreakCard(
                                    kind: kind,
                                    difficulty: difficulty,
                                    stats: state.challengeRecords.stats(kind, difficulty)
                                ) {
                                    start(.streak(kind, difficulty))
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Streaks")
        .fullScreenCover(item: $activeSession) { session in
            ChallengeRunView(session: session) {
                start(session.mode)
            }
        }
        .onAppear {
            state.gameCenter.authenticate()
        }
    }

    private func start(_ mode: ChallengeMode) {
        activeSession = state.makeChallengeSession(mode)
    }
}

/// Personal statistics, the duel record and Game Center leaderboards and
/// achievements. Not behind the paywall.
struct ProfileView: View {
    @Environment(AppState.self) private var state
    @AppStorage(SessionIdentity.nameKey) private var name = ""
    @AppStorage(SessionIdentity.emojiKey) private var emoji = Avatar.pool[0]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "You")
                HStack(spacing: 16) {
                    AvatarButton(emoji: $emoji, size: 72)
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Your name", text: $name)
                            .font(.title3.weight(.bold))
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                        Text("Shown when you host, join or play a live match.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SectionTitle(title: "Statistics")
                ChallengeStatsView(records: state.challengeRecords)

                SectionTitle(title: "Online Duel")
                HStack(spacing: 12) {
                    ProfileTile(title: "Won", value: state.challengeRecords.duelWins, color: Theme.accent)
                    ProfileTile(title: "Lost", value: state.challengeRecords.duelLosses, color: Theme.late)
                    ProfileTile(title: "Draw", value: state.challengeRecords.duelDraws, color: Theme.secondaryText)
                }

                SectionTitle(title: "Game Center")
                gameCenterSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Profile")
        .onAppear {
            state.gameCenter.authenticate()
        }
    }

    @ViewBuilder
    private var gameCenterSection: some View {
        let gameCenter = state.gameCenter
        if gameCenter.isAuthenticated {
            VStack(alignment: .leading, spacing: 12) {
                if let name = gameCenter.playerName {
                    Text("Signed in as \(name)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                }
                Button {
                    gameCenter.showLeaderboard()
                } label: {
                    Label("Leaderboards", systemImage: "list.number")
                }
                .buttonStyle(.secondary)
                Button {
                    gameCenter.showAchievements()
                } label: {
                    Label("Achievements", systemImage: "rosette")
                }
                .buttonStyle(.secondary)
            }
        } else {
            Text(gameCenter.hasAnswered
                 ? LocalizedStringKey("Sign in to Game Center in the Settings app to compete on the leaderboards. Your personal bests are saved either way.")
                 : LocalizedStringKey("Connecting to Game Center…"))
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProfileTile: View {
    let title: LocalizedStringKey
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(verbatim: "\(value)")
                .font(Theme.display(36))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// The running weekly season and its leaderboards.
private struct SeasonCard: View {
    @Environment(AppState.self) private var state
    let season: Season

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Season \(season.week)")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Group {
                    let days = season.daysLeft(from: .now)
                    if days == 0 {
                        Text("Last day")
                    } else {
                        Text("\(days) days left")
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.secondaryText)
            }
            Text("Weekly leaderboards start over every Monday. Your best streak of the week counts.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if state.gameCenter.isAuthenticated {
                Menu {
                    ForEach(ChallengeKind.allCases, id: \.self) { kind in
                        ForEach(ChallengeDifficulty.allCases, id: \.self) { difficulty in
                            Button {
                                state.gameCenter.showLeaderboard(LeaderboardID.weeklyStreak(kind, difficulty))
                            } label: {
                                Text("\(Text(kind.title)) · \(Text(difficulty.title))")
                            }
                        }
                    }
                } label: {
                    Label("This week's leaderboards", systemImage: "calendar")
                        .font(.headline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SectionTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.title2.weight(.heavy))
            .foregroundStyle(Theme.primaryText)
            .padding(.top, 8)
    }
}

private struct StreakCard: View {
    let kind: ChallengeKind
    let difficulty: ChallengeDifficulty
    let stats: ChallengeRecords.StreakStats
    let play: () -> Void

    var body: some View {
        Button(action: play) {
            VStack(alignment: .leading, spacing: 6) {
                Text(difficulty.title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                difficulty.toleranceText(for: kind)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text("Best streak")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.secondaryText)
                Text(verbatim: "\(stats.best)")
                    .font(Theme.display(40))
                    .monospacedDigit()
                    .foregroundStyle(Theme.primaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Starts a streak"))
    }
}

private struct ChallengeStatsView: View {
    let records: ChallengeRecords

    var body: some View {
        VStack(spacing: 0) {
            row("Streak runs", value: Text(verbatim: "\(records.totalRuns)"))
            row("Hit rate", value: Text(verbatim: records.hitRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–"))
            row("Average deviation of hits", value: records.averageHitDeviation.map { Text("±\(TimeFormat.seconds($0)) s") } ?? Text(verbatim: "–"))
            row("DEAD ONs", value: Text(verbatim: "\(records.deadOns)"))
            row("Daily Challenges played", value: Text(verbatim: "\(records.dailyDaysPlayed)"))
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private func row(_ title: LocalizedStringKey, value: Text) -> some View {
        HStack {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            value
                .font(.title3.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
