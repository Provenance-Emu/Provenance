# macOS Desktop Polish — Manual Smoke Checklist

Branch: `feature/macos-desktop-polish` (14 commits off `develop`)
Automated status: iOS **BUILD SUCCEEDED**, tvOS **BUILD SUCCEEDED**, 0 errors, all 10 changed files
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

## Known deferred items (recorded, not bugs to file)

- `.hoverEffect(.lift)` block indentation is inconsistent with its neighbors (cosmetic).
- ⌘L / Save State / Pause menu items stay enabled and no-op when unavailable, matching the four
  pre-existing buttons in that same menu. Disabling them needs `@Observable` plumbing.
- Pre-existing: `handleKeyboardConnect` consults a `skipKeyBinding` guard that
  `handleKeyboardDisconnect` doesn't; the flag is never set true anywhere today.
- Pre-existing: `handleKeyboardConnect` reassigns `keyboardController` unconditionally, orphaning the
  previous virtual controller if a second keyboard connects.
