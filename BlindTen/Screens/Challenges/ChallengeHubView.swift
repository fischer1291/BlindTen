import SwiftUI

/// Solo challenges: the Daily Challenge, four streaks, personal statistics
/// and Game Center (SPEC.md "Version 2", M7). Free for everyone.
struct ChallengeHubView: View {
    @Environment(AppState.self) private var state
    @State private var activeSession: ChallengeSession?
    @State private var today = DailyChallenge(date: .now)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dailyCard

                SectionTitle(title: "Streaks")
                Text("Hit after hit until the first miss. Pro is tight, Close is forgiving.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                ForEach(ChallengeKind.allCases, id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(kind.title, systemImage: kind.symbol)
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
                }

                SectionTitle(title: "Statistics")
                ChallengeStatsView(records: state.challengeRecords)

                SectionTitle(title: "Game Center")
                gameCenterSection
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Challenges")
        .fullScreenCover(item: $activeSession) { session in
            ChallengeRunView(session: session) {
                start(session.mode)
            }
        }
        .onAppear {
            state.gameCenter.authenticate()
            today = DailyChallenge(date: .now)
        }
    }

    private func start(_ mode: ChallengeMode) {
        activeSession = state.makeChallengeSession(mode)
    }

    // MARK: - Daily

    private var dailyCard: some View {
        let result = state.challengeRecords.dailyResult(for: today.day)
        let attemptsLeft = state.challengeRecords.attemptsLeft(for: today.day)
        return VStack(alignment: .leading, spacing: 12) {
            Label("Daily Challenge", systemImage: "calendar")
                .font(.title2.weight(.heavy))
            Text("Same target and twist for everyone today. \(DailyChallenge.attempts) attempts, your best one counts.")
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline) {
                Text("Stop at \(TimeFormat.seconds(today.target))")
                    .font(Theme.display(40))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer()
                Text(today.effect.modeTitle)
                    .font(.headline.weight(.heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.onAccent.opacity(0.15), in: Capsule())
            }
            HStack {
                Text("Attempts left: \(attemptsLeft)")
                Spacer()
                if let best = result.best {
                    Text("Best today: \(TimeFormat.signedDeviation(best)) s")
                        .monospacedDigit()
                }
            }
            .font(.headline)
            Button {
                start(.daily(today))
            } label: {
                Text(attemptsLeft > 0 ? LocalizedStringKey("Play Daily") : LocalizedStringKey("Come back tomorrow"))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.onAccent, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(attemptsLeft == 0)
            .opacity(attemptsLeft == 0 ? 0.5 : 1)
        }
        .foregroundStyle(Theme.onAccent)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Game Center

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

private struct SectionTitle: View {
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
        .buttonStyle(.plain)
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
