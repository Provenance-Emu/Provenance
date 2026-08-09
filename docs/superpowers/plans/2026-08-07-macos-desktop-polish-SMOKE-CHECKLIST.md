# macOS Desktop Polish — Manual Smoke Checklist

Branch: `feature/macos-desktop-polish` (14 commits off `develop`)
Automated status: iOS **BUILD SUCCEEDED**, tvOS **BUILD SUCCEEDED**, 0 errors, all changed files
verified as freshly compiled on both platforms. Every task passed an independent code review.

**Everything below is runtime behavior that a build cannot prove.** None of it has been executed.
Nothing here is claimed as verified.

## Setup

Best target is an Apple Silicon Mac running the iOS build via "Designed for iPad", which is the actual
Mac product. An iPad simulator with **I/O → Input → Send Keyboard Input to Device** enabled (⇧⌘K)
reproduces most of it.

## A. Controller-style navigation (Tasks 7-9)

1. Launch with a hardware keyboard attached. Go to **Settings → Controller**. Confirm a
   **"Controller-Style Navigation"** toggle is present, is OFF by default, and is **not** showing a
   premium/Plus lock. (It was deliberately moved out of Advanced, which paywalls every row.)
2. Turn it ON. The library should switch to the TV-style (TVMedia) UI. Note there is a deliberate
   ~0.32s crossfade.
3. Navigate with the keyboard only: arrow keys move focus, **Space**/**Return** selects,
   **F**/**Esc** goes back. Launch a game this way.
4. Turn the toggle OFF → the library returns to the normal UI.
5. Regression check: with a **physical gamepad** (no keyboard) in landscape, the TVMedia UI must still
   activate exactly as before. This path was supposed to be untouched.
6. Portrait + keyboard + toggle ON now switches UI (no landscape requirement for the keyboard path).
   This is intentional — confirm it feels right rather than filing it as a bug.

## B. Menu bar / shortcuts (Task 10)

7. **⌘,** opens Settings. Test in **all three UI modes** — paged, single-page, and the TVMedia UI from
   step 2. Before this branch it only worked in paged mode; the other two were silently dead.
8. Bonus check of the same fix: trigger the cloud-sync-unavailable alert's **"Open Settings"** button
   while in single-page mode. It should now work (it silently did nothing before).
9. In a running game: **⌘S** saves a state, **⌘L** loads the most recent one, **⌘P** pauses/resumes,
   **⇧⌘S** screenshots, **⇧⌘Q** quits. ⌘L was an empty stub before this branch.
10. ⌘L with no save states present should do nothing gracefully — no crash, no error dialog.

## C. Pointer (Task 11)

11. With a trackpad/mouse, hover a game tile: the system pointer should "lift"/morph over the tile,
    in addition to the existing glow/scale effect.

## D. Keyboard remapping (Tasks 12-13)

12. **Settings → Controller → Keyboard Mapping** lists all 26 actions with their current keys.
13. Tap a row → it shows "Press a key…" → press a key → the row updates and persists.
14. Verify the rebind actually took effect in a game.
15. Press **Delete** while capturing → that action resets to its default.
16. **"Reset All to Defaults"** restores every binding.
17. Default behavior regression: with **no** remapping saved, in-game keyboard controls must behave
    exactly as before this branch (arrows = d-pad, WASD = left stick, Space/Return = A, F/Esc = B,
    Q = X, E = Y, Tab = L1, R = R1, `/` = Select, RightShift = Start).

### D-critical — the bug that was caught in review

18. Start capturing a key (row shows "Press a key…"), then **without finishing**, tap
    **"Reset All to Defaults"**. Then leave the screen. **Now verify keyboard input still works
    in a game.** Before the fix this silently killed all keyboard-as-controller input app-wide until
    the keyboard was physically reconnected.
19. Same test, but instead of Reset, **disconnect the keyboard mid-capture**, then reconnect it.
    Keyboard input must still work.
20. Same test, but connect a **second** keyboard mid-capture.

## E. Newly-live pause path (flagged during Task 8 review)

21. During gameplay, press **`** (backtick, = Menu) and **1**/**U** (= Options). These now fire the
    pause handler for keyboard input, which was previously dead code. Confirm the pause menu opens
    cleanly and does **not** double-toggle or race with the on-screen menu.

## F. tvOS regression

22. On tvOS: Settings screens show **no** new rows (both new controls are `#if !os(tvOS)`), and library
    navigation with the Siri Remote is unchanged.

## Added after the final whole-branch review (these caught real bugs — run them)

23. **C1 regression guard.** Keyboard + no gamepad, toggle ON: not just the library grid, but every
    modal opened from it must accept keyboard input — the **core picker**, **save-state picker**,
    **rename** dialog, and the **Imports** sheet. The original fix missed these six sites; the library
    was navigable while every dialog silently swallowed input.
24. **C2 regression guard.** With keyboard navigation working, open *Keyboard Mapping*, rebind a key
    (and separately hit *Reset All to Defaults*), leave Settings, and confirm **arrow keys / Space
    still navigate the library**. Before the fix, any rebind killed navigation until app relaunch.
    Step 14 does not cover this — it only checks the rebind took effect in-game.
25. **I1 regression guard.** iPad + Magic Keyboard, toggle **OFF**: type in the library search field
    and navigate normally. Space must NOT launch a game, Esc must NOT go back, Tab must NOT page.
    Then flip the toggle ON and OFF at runtime and confirm the bridge attaches/detaches without an
    app restart.
26. **tvOS**, `.tvosMedia` mode: drill into a system's games, trigger the cloud-sync "Open Settings"
    alert, and confirm the back-stack behaves. Both new observers are now `#if !os(tvOS)`, so this
    should behave exactly as it did before the branch.

## Follow-up tickets (identified in review, deliberately NOT fixed on this branch)

- **`HomeContinueSection.swift:874`** still hard-gates on `isControllerConnected`, so on **iOS 17**
  (where `MainView` never switches to the TVMedia UI) a keyboard user lands in Home with the Continue
  section swallowing keyboard events. iOS 18+ is the desktop target, so this is not a blocker.
- **`PauseTileMenuView.swift:1893`** — same gate in the in-game pause menu; keyboard navigation of the
  pause menu is dead. Out of scope for this branch.
- **`GamepadManager` `Defaults.publisher` fires an `.initial` emission**, so a detach runs once at
  launch even with the toggle off, nil-ing per-button handlers `PVRemappableController` had installed.
  Verified inert (gameplay dispatch uses the profile-level handler), but `options: []` would be tidier.
- **`rebuildKeyboardController()` can clobber an SDL core's live `keyChangedHandler`** (Flycast/Dolphin)
  if the user rebinds from the pause menu's Settings while that core is paused in the background.
- **`TVMediaMainView.swift` exceeds the 600-line `type_body_length` lint limit** (pre-existing, 649→651).
- **Pause-menu pointer polish** — spec Phase 1 promised `.hoverEffect` on game tiles *and* pause-menu
  tiles; only game tiles shipped.
- Pre-existing `handleKeyboardConnect` issues: the `skipKeyBinding` connect/disconnect asymmetry, and
  unconditional `keyboardController` reassignment orphaning the prior virtual controller.

## Known deferred items (recorded, not bugs to file)

- `.hoverEffect(.lift)` block indentation is inconsistent with its neighbors (cosmetic).
- ⌘L / Save State / Pause menu items stay enabled and no-op when unavailable, matching the four
  pre-existing buttons in that same menu. Disabling them needs `@Observable` plumbing.
- Pre-existing: `handleKeyboardConnect` consults a `skipKeyBinding` guard that
  `handleKeyboardDisconnect` doesn't; the flag is never set true anywhere today.
- Pre-existing: `handleKeyboardConnect` reassigns `keyboardController` unconditionally, orphaning the
  previous virtual controller if a second keyboard connects.
