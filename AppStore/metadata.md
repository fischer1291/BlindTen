# App Store listing (en-US)

Copy each block into App Store Connect. Character limits are checked by
`python3 Tools/check_metadata.py`.

## Name (max 30)

```
Blind Ten
```

Fallbacks from SPEC.md if the name is taken: `Blind Ten: Party Timer`, `Dead On`, `Gut Clock`, `Ten Blind`.

## Subtitle (max 30)

```
Stop at exactly 10 seconds
```

## Promotional text (max 170)

```
New: Daily Challenge, streaks with weekly seasons, online duels and live matches with friends. Tap START, the timer vanishes. Stop at exactly 10 seconds.
```

## Description (max 4000)

```
Everyone thinks they have a perfect inner clock. Blind Ten proves who really does.

Tap START and the timer disappears. Tap anywhere to STOP when you think exactly 10 seconds have passed. A drumroll, a spinning number, and the truth: 10.03 s. DEAD ON. Or 12.41 s and a sad trombone.

Explained in 10 seconds, playable in 15. One phone, 2 to 10 players, no accounts, no setup. Pass the phone around the table and let the roasting begin.

HOW IT WORKS
• Pass the phone to the next player
• Tap START, the screen goes dark
• Tap STOP when your gut says ten
• See how close you were, with a one-liner to match

FREE MODES
• Classic: stop at exactly 10.00 seconds
• Random Target: a new target every turn, from 4 to 20 seconds
• Showdown: two players at once on a split screen, closest wins the duel

PARTY PACK (one-time purchase)
• Distraction: random beeps try to throw you off
• Liar's Clock: a countdown that runs too fast or too slow
• Heartbeat: the phone pulses at a slightly wrong tempo
• Elimination: the worst player each round is out
• Teams: two teams, lowest combined deviation wins
• Live Match online with 2 to 8 players
• Unlimited players and your own house-rule cards
• TV mode: leaderboard and big reveals on the TV via AirPlay

CHALLENGES AND LEADERBOARDS
• Daily Challenge: the same target for everyone, three attempts a day
• Streaks: hit after hit until the first miss, in Pro and Close
• Weekly seasons and all-time leaderboards in Game Center
• Achievements and personal statistics, free for everyone

PLAY ONLINE
• Online Duel: best of 3 against a friend or a random opponent, whenever you like
• Live Match (Party Pack): 2 to 8 players at the same time, one shared reveal
• The timer starts by itself at a random moment, so a second stopwatch won't help
• Cheer and tease with preset phrases and emoji, never free text

PLAY TOGETHER ON THE TV
• Host a session and put your phone on the TV with AirPlay
• Friends join with their own iPhones, no internet or account needed
• Everyone plays their turn on their own phone, the host too
• The big reveal lands on the TV and on your phone at the same moment

MADE FOR THE TABLE
• Dark, high-contrast screens readable from across the table
• Precise timing from the moment your finger touches the glass
• Haptics and sounds that make every reveal a moment
• Funny awards like The Impatient One and Dead Eye
• Remembers your group and keeps all-time stats on your phone
• Optional house rules: the round loser draws a card

No ads during play. No subscription. No account. Everything stays on your phone.
```

## Keywords (max 100, comma separated, no spaces after commas)

```
party game,friends,timer,stopwatch,reaction,daily challenge,online duel,ten seconds,bar game,guess
```

## What's New in 1.1 (max 4000)

```
The biggest update yet:

• Daily Challenge: the same target for everyone, three attempts a day
• Streaks in Pro and Close, with weekly seasons and Game Center leaderboards
• Online Duel: best of 3 against a friend or a random opponent, whenever you like
• Live Match (Party Pack): 2 to 8 players online at the same time
• The timer starts by itself in challenges and online play, so no stopwatch can help
• Quick chat with preset phrases and emoji
• Pick your avatar from Apple's emoji
• A new Home screen sorted by how you play, smoother animations everywhere
• The result now stays on screen until you tap
```

## Support URL

```
https://www.blindten.com/contact.html
```

## Marketing URL (optional)

```
https://www.blindten.com/
```

## Privacy Policy URL

```
https://www.blindten.com/privacy.html
```

The pages live in `website/` and are published by the Website workflow
(GitHub Pages). The app links to them from Settings.

## Category

Primary: Games > Party (Info.plist already says party games). Secondary: Games > Casual.

## Copyright

```
2026 Leroy Fischer
```

## In-app purchase: Party Pack

- Type: Non-Consumable
- Reference name: `Party Pack`
- Product ID: `com.leroyfischer.blindtengame.partypack` (the app derives it from the bundle ID)
- Price: USD 2.99 tier
- Display name (max 35): `Party Pack`
- Description (max 55): `All modes, live online matches, unlimited players`

## App Review notes

```
Blind Ten is a pass-the-phone party game. Add two names (or use Quick play), tap PLAY, then tap START and tap anywhere to STOP near 10 seconds.

The Party Pack (non-consumable) unlocks five extra modes, Live Match, unlimited players and custom house-rule cards. To see the purchase screen, tap PLAY and then any mode card marked with a lock, or open Online > Live on the Home screen. Restore Purchases is in Settings (gear icon, top right).

Game Center: the Daily Challenge, streaks, leaderboards, achievements, Online Duel (turn-based) and Live Match (real-time) use Game Center. Challenges also work without signing in. Online players can only exchange preset phrases and emoji avatars chosen from a fixed list; there is no free-text chat and no user-generated content. Testing online play needs two devices with different Game Center accounts.

Local network: "Host" / "Join" under "Together in the room" on the Home screen connect nearby iPhones directly (MultipeerConnectivity) so each player plays on their own phone while the host's screen shows the game on a TV. Only the player name, emoji and turn events are exchanged between the devices; nothing is sent to a server. Testing it needs two devices; the rest of the app works on one.

The app collects no data. Everything is stored on the device. No account is needed.
```
