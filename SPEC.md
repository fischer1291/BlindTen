# Blind Ten – Game Spec

Oct 5, 2026 · @Leroy

## Pitch & vision

**Blind Ten** is a pass-the-phone party game: tap start, the timer vanishes, tap stop when you think exactly 10 seconds have passed. Closest wins, the loser gets roasted.

It is built for two settings:

- **The bar:** one iPhone, 2–10 players, zero setup, played between rounds of drinks. A full game takes 3–5 minutes.
- **Home / TV:** the same game, with the scoreboard and dramatic reveals mirrored to the TV via AirPlay while the phone stays the controller.

Why it works: the rules fit in one sentence, everyone thinks they have a perfect inner clock, and the gap between "I nailed it" and "you were 2.4 seconds off" is instantly funny. Rounds take 10 seconds each, so nobody waits long and the phone keeps moving.

**Working title alternatives:** Blind Ten, Dead On, Gut Clock, Ten Blind. Check App Store and trademark availability before committing; a name that does not hard-code "ten" leaves room for random-target modes.

**Design principles**

1. Explainable in 10 seconds, playable in 15.
2. One device is enough. Everything else is a bonus.
3. Every reveal is a mini event: suspense, then a number, then a reaction.
4. No accounts, no login, no onboarding screens.

## Core gameplay

A game is 3 rounds by default; in each round every player takes one turn, and the lowest total deviation wins.

**A single turn**

1. Handoff screen: big name of the current player, "Pass the phone to Mia". Tap anywhere when ready.
2. Target screen: "Stop at 10.00". One big START button.
3. Player taps START. Screen goes dark or shows the mode's visual (no clock, nothing ticking once per second).
4. Player taps anywhere to STOP. A whole-screen tap target, so nobody misses the button.
5. Reveal: a short drumroll (0.8–1.5 s), then the stopped time animates in, e.g. **10.27 s**, with the deviation **+0.27**.
6. A one-line reaction ("Surgical.", "Did you fall asleep?") and the next player.

After every player has had a turn: round leaderboard on screen, loser of the round highlighted, optional house-rule card (see modes).

**Scoring**

| Deviation from target | Label | Points |
| --- | --- | --- |
| ≤ 0.05 s | DEAD ON | 10 |
| ≤ 0.25 s | Sharp | 7 |
| ≤ 0.50 s | Close | 5 |
| ≤ 1.00 s | Meh | 3 |
| ≤ 2.00 s | Off | 1 |
| > 2.00 s | Lost in time | 0 |

The tiers keep the game readable for people who had a few drinks. The exact deviation in seconds (two decimals) is always shown and is the tiebreaker. A "Precision" setting can switch scoring to pure total deviation for competitive groups.

**Edge cases**

- Stopping before 1.0 s counts as a misfire: shown as "Too eager!", 0 points, no retry.
- No stop after target × 3: auto-stop, 0 points, "Still waiting...".
- App goes to background mid-turn: turn is voided and replayed.

## Game modes

The MVP ships with three free modes; the rest is the paid Party Pack and later updates.

| Mode | How it plays | Why it's fun | Tier |
| --- | --- | --- | --- |
| Classic | Target 10.00 s, dark screen. | The pure version, easy to explain. | MVP, free |
| Random Target | Each turn gets a new target between 4 and 20 s (e.g. 13.37). | Nobody can train one rhythm. | MVP, free |
| Showdown | Two players at once, split screen, each thumb on their own half. Closest wins the duel. | Face-to-face tension, great for settling arguments. | MVP, free |
| Distraction | Others may talk, count wrong numbers out loud, poke. The app also plays random beeps at irregular intervals. | Chaos at the table. | Party Pack |
| Liar's Clock | The screen shows a countdown, but it runs 10–30 % too fast or too slow. You must ignore it. | Feels unfair in the best way. | Party Pack |
| Heartbeat | The phone vibrates in a steady pulse that is slightly off (e.g. every 0.9 s). | Your body syncs to it before you notice. | Party Pack |
| Elimination | Worst player each round is out until one is left. | Clear winner, drama at the end. | Party Pack |
| Teams | 2 teams, summed deviation. | Works for big groups, builds rivalries. | Party Pack |
| Blind Bet | Before stopping, the player bets how close they will be (±0.1 / ±0.5 / ±1 s). Higher bet, more points or bigger loss. | Adds bluffing and trash talk. | Later |
| Daily Challenge | One target per day (same worldwide), one attempt, Game Center leaderboard, shareable result. | Solo retention between bar nights; Wordle-style sharing. | Later, free |

**House rules (optional, off by default):** the round loser draws a card from a configurable deck, e.g. "Buy the next round", "Speak in an accent until your next turn", "You choose the next song". Groups can add their own cards. Keep the default deck non-alcoholic and neutral (see App Store notes).

## Screens & UX flow

The app has six screens, and a first game must start within 15 seconds of the first launch.

| Screen | Content | Notes |
| --- | --- | --- |
| Home | Big "PLAY" button, mode picker (cards), Daily Challenge tile, settings gear | No onboarding. Rules are one line under the mode card. |
| Players | Add names with one text field + Return, emoji avatar auto-assigned, drag to reorder | Last group is remembered. "Quick play" skips names (Player 1, 2...). Min 2, max 10 free (unlimited in Party Pack). |
| Handoff | "Pass to Mia" in huge type, avatar, tap to continue | Prevents the wrong person from playing. |
| Turn | Target, START, then the mode's blind state, whole-screen STOP | Max brightness, idle timer disabled. |
| Reveal | Drumroll, time, deviation, tier label, reaction line | Auto-advances after 3 s or on tap. |
| Round / Game results | Leaderboard, round loser, house-rule card, "Rematch" and "New game" | Share button on the final screen. |

The loop is Handoff → Turn → Reveal for every player, then Round results, then the next round or Game results. "Rematch" goes straight back to the first Handoff with the same players and mode.

**UX rules**

- Everything readable from 1 m away: big type, high contrast, dark theme by default (bars are dark).
- One-handed play; no small buttons during a game.
- Undo for "wrong player tapped" on the reveal screen (replay the turn).

## Game feel

The reveal is the product: most of the polish budget goes into the 3 seconds after STOP.

- **Haptics:** sharp tap on START and STOP; rising rumble during the drumroll; a strong "success" pattern on DEAD ON; a sad double-buzz on "Lost in time". Use Core Haptics for custom patterns.
- **Sound:** short drumroll, cymbal hit for DEAD ON, trombone fail for > 2 s. A mute switch respects the ringer, plus an in-app sound toggle.
- **Reveal animation:** the number spins up like a slot machine and lands on the result. Over/under shown with a colored arrow (blue = too early, red = too late).
- **DEAD ON moment:** full-screen confetti, screen flash, the player's name in huge type. This is the clip people will film.
- **Reaction lines:** \~30 English one-liners per tier, picked at random, never the same twice in a game. Written to be localizable later.
- **Share card:** at game end, a 1080×1920 image (Instagram story size): winner, everyone's best time, mode, app name and a small App Store hint. Generated with ImageRenderer, shared via the system share sheet.
- **Streaks & stats:** per-group local stats such as "best ever", "most DEAD ONs", "always too early". Shown as funny awards on the results screen ("The Impatient One").

## Technical spec

Native iOS app in Swift and SwiftUI, iOS 17+, fully offline, no backend for the MVP.

**Stack**

| Area | Choice | Reason |
| --- | --- | --- |
| UI | SwiftUI, Observation framework (@Observable) | Fast to build, Claude Code handles it well. |
| Persistence | SwiftData (players, groups, stats, custom house rules) | Local only, no account. |
| Haptics | Core Haptics, fallback UIImpactFeedbackGenerator | Custom patterns for the reveal. |
| Audio | AVAudioPlayer with preloaded short files, AVAudioSession category .ambient | Plays over the bar's music without stopping the user's own playback. |
| Purchases | StoreKit 2 | One non-consumable IAP, no server needed. |
| Leaderboards | GameKit / Game Center (Daily Challenge, later) | Free, no backend. |
| Localization | String Catalogs (.xcstrings), English as base | Adding DE, ES, FR, PT later is a translation job, not a code change. |
| Analytics | TelemetryDeck or none at MVP | Privacy-friendly; keeps the App Store privacy label simple. |

**Timing precision (critical)**

- Measure with UITouch.timestamp (system uptime of the actual touch), not with the moment the SwiftUI action fires. That removes 10–30 ms of UI latency jitter.
- Implement the START/STOP surface as a small UIViewRepresentable with touchesBegan, so both timestamps come from the same clock.
- Compare against ProcessInfo.processInfo.systemUptime for timeouts. Never use Date() for measurement.
- Display with 2 decimals; store the raw Double.
- Unit-test the scoring function with boundary values (0.05, 0.25, 0.5, 1.0, 2.0).

**Anti-cheat (light)**

- No visual or audio element may change at a regular 1-second rhythm during the blind phase.
- Disable the idle timer so the screen never dims mid-turn.
- Liar's Clock and Heartbeat use randomized tempo per turn.

**TV / second screen**

- MVP: screen mirroring via AirPlay just works, so design for 16:9 and portrait both.
- v1.1: dedicated external display scene (UIWindowSceneSessionRoleExternalDisplay). The TV shows the leaderboard and big reveals; the phone shows only the START/STOP surface. This is a Party Pack feature.

**Local session (multi-phone)**

- One phone hosts ("Host a session"); it becomes the main screen and is put on the TV with AirPlay (mirroring, or the TV scene with the Party Pack). Other players tap "Join a session", enter a name and emoji, and pick the host's three-emoji code.
- Transport: MultipeerConnectivity (service type `blindten`, encryption required), so it works over Wi-Fi or Bluetooth without internet or accounts. Info.plist declares `NSLocalNetworkUsageDescription` and `NSBonjourServices`.
- The host is authoritative: it runs the GameEngine and sends every phone a full snapshot after each change. Phones send only events (ready, started, stopped with the elapsed seconds, voided).
- Each player's phone measures its own START and STOP with UITouch.timestamp; only the elapsed time travels, so network latency never affects a result. The host stops a turn itself 5 s after its timeout in case a phone never reports back, and can skip a player whose phone dropped out.
- Players take turns as in pass-the-phone play (two at once in Showdown). While others play, a phone shows an animated waiting screen whose motion never follows a 1-second rhythm. Results land on the TV and on the player's phone at the same moment.
- Mode access and the player limit follow the host's Party Pack.

**Data model**

```
Player      id, name, emoji, colorIndex, createdAt
Group       id, name, players[], lastPlayedAt
Game        id, mode, rounds, targetSeconds?, startedAt, groupId
Turn        id, gameId, playerId, round, target, stopped, deviation, points, misfire
HouseRule   id, text, isCustom, isEnabled
```

**Project structure**

```
BlindTen/
  App/            BlindTenApp.swift, AppState.swift
  Game/           GameEngine.swift, Scoring.swift, Modes/
  Timing/         TouchTimerView.swift (UIViewRepresentable)
  Feel/           Haptics.swift, Sound.swift, Reactions.swift
  Screens/        Home, Players, Handoff, Turn, Reveal, Results, Settings
  Screens/Session HostSessionView, JoinSessionView, ClientSessionView, SessionBoard
  Session/        SessionProtocol, SessionHostLogic, ClientTurn (pure), PeerTransport, SessionHost, SessionClient
  Store/          PurchaseManager.swift (StoreKit 2), PaywallView
  Persistence/    SwiftData models, GameStore
  TV/             ExternalDisplay (scene delegate), TVView
  Brand/          LogoMark, SplashView
  Share/          ShareCardView.swift
  Resources/      Localizable.xcstrings, InfoPlist.xcstrings, Sounds/, Assets
BlindTenTests/    one Swift Testing file per area (Scoring, GameEngine, Modes, Session, …)
Config/           Info.plist (launch screen, local network keys; merged into the generated one)
AppStore/         listing texts, privacy policy, screenshots (JPEG, no alpha)
Tools/            catalog, icon, sound and metadata scripts
```

Keep GameEngine free of SwiftUI so modes can be unit-tested and a second-screen view can render the same state.

## Monetization

Recommended model: free download plus a one-time **Party Pack** unlock at $2.99, no subscription and no ads during play.

Party games are played in bursts with friends watching. Ads mid-game kill the mood in front of the whole table, and subscriptions feel wrong for something used twice a month. A one-time unlock is the model the genre's best-known hit, Heads Up!, made familiar.

| Option | How | Pros | Cons | Verdict |
| --- | --- | --- | --- | --- |
| Freemium + one-time unlock | 3 free modes, Party Pack unlocks all modes, unlimited players, TV scene, custom house rules, themes | Free = easy viral spread at the table; one purchase per group often enough | Only one payer per group | **Primary** |
| Paid upfront ($0.99–$1.99) | Whole app paid | Simple, no IAP code | Kills the "just download it, it's free" moment | No |
| Ads | Interstitial only after a full game; rewarded ad to unlock one Party mode for 24 h | Revenue from non-payers | Low eCPM at small scale, hurts the vibe | Optional, after launch |
| Subscription | Weekly/yearly | Recurring revenue | Users hate it for party games, review risk | No |
| Extra packs (later) | Themed packs: new modes, reaction-line packs, visual themes, $0.99–$1.99 each | Monetizes engaged groups | Needs content production | v1.2+ |
| Sponsored / venue (later) | Bar tournament mode, branded Daily Challenges | Bigger deals | Sales effort, alcohol brand rules | Only with traction |

**Implementation (StoreKit 2)**

- One non-consumable product: com.leroyfischer.blindtengame.partypack.
- PurchaseManager listens to Transaction.updates, checks currentEntitlements on launch, and exposes isPartyPackUnlocked.
- Paywall appears only when tapping a locked mode card, never on launch. Show a 5-second looping preview of the mode.
- "Restore Purchases" in settings (required by App Review).
- Local StoreKit configuration file for testing in Xcode.
- Use regional price tiers; Apple handles currency conversion for \~175 storefronts.

**App Store notes**

- Guideline 1.4.3 discourages encouraging excessive alcohol consumption. Keep drinking out of the default house rules, screenshots and description; frame it as a "party game". Groups can add their own rules.
- Age rating: likely 4+ or 9+ with neutral content; user-generated house rules stay on-device only, so no moderation is needed.
- Apple takes 15 % of revenue under the Small Business Program (below $1M/year), so enroll before launch.
- App Store keywords to target: party game, drinking game alternatives, friends game, reaction game, time challenge.

**Growth is the real lever.** Revenue here scales with installs, and installs come from people seeing it at a table. Priorities: the share card, TikTok/Reels clips of DEAD ON moments, and a "Played Blind Ten?" prompt to rate after a fun game (SKStoreReviewController, only after a DEAD ON or a close final).

## Build plan for Claude Code

Build in five milestones; the game is playable at the bar after milestone 2.

**Setup:** create an empty iOS App project in Xcode (SwiftUI, Swift Testing, iOS 17), export this doc as Markdown into the repo as SPEC.md, and add a CLAUDE.md with: "Read SPEC.md before every task. Swift 6, SwiftUI, @Observable, no third-party dependencies. All user-facing strings go through String Catalogs in English. Keep GameEngine UI-free and unit-tested. Build and run tests after every change."

1. **Core loop** — Prompt: "Implement milestone 1 from SPEC.md: Scoring.swift with the tier table and unit tests, GameEngine for Classic mode (players, rounds, turns, misfire and timeout rules), and TouchTimerView using UITouch.timestamp. Plain UI for Players, Handoff, Turn, Reveal, Results. No styling yet."
2. **Feel** — Prompt: "Implement the Game feel section of SPEC.md: Core Haptics patterns, preloaded sounds with .ambient audio session, slot-machine reveal, DEAD ON confetti, randomized reaction lines (30 per tier) in the String Catalog. Dark, high-contrast theme readable from 1 m."
3. **Modes** — Prompt: "Add Random Target and Showdown (split-screen, two independent touch surfaces, both timed from UITouch.timestamp), then Distraction, Liar's Clock, Heartbeat, Elimination and Teams behind a mode protocol. Unit-test each mode's rules."
4. **Monetization & persistence** — Prompt: "Add SwiftData models from SPEC.md, remembered groups and stats awards, house-rule cards with custom rules, and StoreKit 2 PurchaseManager with one non-consumable Party Pack, paywall on locked mode tap, restore button, and a local StoreKit configuration file."
5. **Launch polish** — Prompt: "Add the share card (1080×1920, ImageRenderer, share sheet), the review prompt rule, app icon placeholder, and an external display scene that shows leaderboard and reveals on the TV while the phone shows only the touch surface."

After launch: Daily Challenge with Game Center, more languages (German first, since you can check it yourself), extra packs.

**Testing tips:** precise timing only behaves on a real device, so run every milestone on your iPhone, not just the simulator. Test the reveal with real friends at milestone 2; their reactions decide what gets polished.

**Out of scope for v1:** online multiplayer over the internet (the local session above stays on the local network), accounts, Android, a backend, user-generated content shared between devices.
