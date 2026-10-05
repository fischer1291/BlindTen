# Blind Ten

Pass-the-phone party game for iPhone: tap START, the timer disappears, tap STOP when you think exactly 10 seconds have passed. Closest wins.

## Source of truth

- Read `SPEC.md` before every task. If a request conflicts with SPEC.md, ask before deviating.
- Work milestone by milestone (see "Build plan for Claude Code" in SPEC.md). Don't build features from later milestones early.

## Tech rules

- Swift 6, SwiftUI, iOS 17+, `@Observable` (Observation framework). No third-party dependencies.
- `GameEngine` and `Scoring` must not import SwiftUI. Keep them pure and unit-tested (Swift Testing).
- Timing: measure START/STOP with `UITouch.timestamp` inside a `UIViewRepresentable` (`TouchTimerView`). Never use `Date()` for measurement.
- No UI element or sound may tick at a regular 1-second rhythm during the blind phase.
- All user-facing strings in English via String Catalogs (`Localizable.xcstrings`). No hard-coded UI strings.
- Persistence: SwiftData, local only. Purchases: StoreKit 2.
- Dark, high-contrast UI, readable from 1 m. Large tap targets during gameplay.

## Workflow

- After every change: build, run all tests, fix failures before finishing.
- Keep commits small, one logical change each, with a clear message.
- When something can only be verified on a real device (haptics, timing feel, AirPlay), say so explicitly at the end of your summary.

## Repo notes

- Every file inside `BlindTen/` is added to the app target automatically (synchronized folder). Never put an `Info.plist` there; the custom keys live in `Config/Info.plist`.
- Reaction lines and built-in house rules are edited in `Tools/*.json`, then merged with `python3 Tools/update_catalog.py` (CI checks the catalog is up to date).
- App Store screenshots are JPEG without an alpha channel, produced by the "App Store Screenshots" workflow; see `AppStore/Screenshots/README.md`.
- Local multiplayer lives in `Session/`: keep `SessionHostLogic` and `ClientTurn` free of networking and UI, and unit-test them.
