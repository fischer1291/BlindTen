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
Tap START, the timer vanishes. Tap STOP when you think exactly 10 seconds have passed. Closest wins. The perfect pass-the-phone game for your next night out.
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
• Unlimited players and your own house-rule cards

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
party game,friends,group game,timer,stopwatch,reaction,time challenge,guess,ten seconds,bar game
```

## Support URL

Any page where players can reach you (a simple contact page is enough).

## Privacy Policy URL

Publish `AppStore/privacy-policy.md` on any public web page and paste that URL.

## Category

Primary: Games > Party (Info.plist already says party games). Secondary: Games > Casual.

## Copyright

```
2026 <your name>
```

## In-app purchase: Party Pack

- Type: Non-Consumable
- Reference name: `Party Pack`
- Product ID: `<your bundle ID>.partypack` (the app derives it from the bundle ID)
- Price: USD 2.99 tier
- Display name (max 35): `Party Pack`
- Description (max 55): `All modes, unlimited players, custom house rules`

## App Review notes

```
Blind Ten is a pass-the-phone party game. Add two names (or use Quick play), tap PLAY, then tap START and tap anywhere to STOP near 10 seconds.

The Party Pack (non-consumable) unlocks five extra modes, unlimited players and custom house-rule cards. To see the purchase screen, tap any mode card marked with a lock on the Home screen. Restore Purchases is in Settings (gear icon, top right).

The app collects no data. Everything is stored on the device. No account is needed.
```
