# Settings UI pass — 2026-10-15

Follow-up to the Oct 14 pass (advanced-settings promotions, UIKit mode removal, iFly-style sidebar).
Audit of `PVUI/Sources/PVSwiftUI/Settings/` on iOS and tvOS. Ordered by priority: bugs and App Review
risk first, then findability, then visual consistency. Items marked **[batch]** are in this branch.

Sibling sessions edit nearby code (`netplay-lan`: the Netplay row in `AdvancedTogglesView`;
`shared-libs-ui`: `LibrarySection2` and the library search entries), so this batch keeps its edits there
line-local and leaves restructuring those blocks for later.

## P1 — bugs

1. **[done 18c6284ef9] tvOS: Menu leaves Settings from two subpages.** `PendingPatchesView` (Library Management ›
   Patches / ROM Tools) and `PVLogSessionBrowserView` (Advanced › Session Logs) never register with the
   settings subpage refcount, so `SettingsWrapperView.canPop` stays false and Menu exits Settings instead of
   going back. Every other tvOS destination tracks. Fix: `.settingsSubpageTracking()` on both link
   destinations.
   Files: `SettingsSwiftUI.swift`.

2. **[done ea5ac90c60] Search finds rows that no longer exist, three of them labelled "(Beta)".** The Oct 14 pass
   removed the SRAM Import / Export, Tap to Remap and Reposition Skin Buttons toggles. Their index entries
   remain, so a search opens Advanced and shows nothing. "Programmatic Touch Overlay" is now the Overlay Style
   picker in Delta Skins. Gameplay Clips has no entry. Companion Controller still says "(Beta)", which App
   Review rejects. The OpenGL subtitle is the pre-Oct 14 wording. Fix: entries match the rows, plus a test
   that no displayed index text says "beta".
   Files: `SettingsSearchIndex+Entries.swift`, `SettingsSearchIndexTests.swift`.

3. **[done 2b9184e1ab] Two "Haptic Feedback" rows, and one of them does nothing.** Controllers › Haptics & Rumble and
   Touch Controls › On-Screen Controls both show "Haptic Feedback — Vibrate when pressing on-screen
   buttons." The first writes `Defaults[.hapticFeedback]`, which nothing reads. Every touch path reads
   `buttonVibration`. The pause-menu **Rumble** tile and the skin `toggleHaptics` button also flip the dead
   key, so neither does anything. Fix:
   - Drop the dead row and the key.
   - The Rumble tile toggles `rumbleEnabled`, the master switch `GCControllerHapticsManager` honours.
   - The skin button toggles `buttonVibration`.

   Files: `SettingsSwiftUI.swift`, `PauseTileMenuView(Model).swift`, `DeltaSkinInputHandler.swift`,
   `PVSettingsModel.swift`, `GCControllerHapticsManager.swift` (comments), search entries.

4. **[done 24c5fb0370] tvOS can't set the timed auto-save interval** (`// TODO: TVOS Selection of autosave time`). On
   iOS the caption reads "5.0 minutes between timed auto saves." and the slider shows even when Timed Auto
   Saves is off. Fix:
   - tvOS gets a selection list of presets, following the `CoreLanguageSelectionView` pattern, because the
     default Picker clips on tvOS.
   - The caption is formatted by a pure helper with tests.
   - As built: the interval controls dim and disable while Timed Auto Saves is off rather than hiding, so
     a search result still lands on a row. Core Language moved onto the same generic
     `TVOSSettingsChoiceView`.

   Files: `SettingsSwiftUI.swift`, new `SettingsValueFormatting.swift`, new test.

## P2 — findability and duplication

5. **[done 2fdc102ce7] Advanced has a second title.** On iOS the pane shows "Advanced" and then a gradient
   "ADVANCED OPTIONS" heading; on tvOS, "ADVANCED" and then "ADVANCED OPTIONS". The developer tools (file
   browser, Spotlight debug, logs) run straight on from the user toggles. Fix: drop the extra heading and
   head the debug rows with "Developer Tools".
   Files: `AdvancedTogglesView.swift` (heading only), `SettingsSwiftUI.swift`.

6. **[done bbc25e28f3] Gameplay features live under Advanced.** Netplay, N64 Transfer Pak, Light Gun Crosshair, Gameplay
   Clips, Live Broadcast, AirPlay Audio Menu, Companion Controller and Case Companion Skins are user
   features, not advanced settings. Proposal: a "Gameplay Features" section in the Emulation pane (and a
   tvOS section). That needs a new `SettingsSectionTitle`, a pane mapping, a tvOS section, search entries
   and test updates in one commit. As built: `GameplayFeaturesSection` (Emulation pane, tvOS section after
   Saves), search ids renamed `play.*`, Netplay text mentions the library Network Play lobby.

7. **[done a9b38c2b5e] Library Management is 16 rows in one card.** Storage, cloud, backup, import, nearby, NFC, artwork,
   patches, two toggles, four maintenance actions and Reset all sit together. Proposal: sub-headings
   (Storage & Sync / Library Tools / Import Options / Maintenance), with Reset Library last and set apart.
   As built: "Library Options" instead of "Import Options" (Show Unsupported Cores is not an import option);
   Reset Library is the last Maintenance row.

8. **[done 70f1fd76c5, dropped] Advanced › iCloud Sync duplicates Cloud Sync Settings** (non-App Store builds only). Drop it, or turn
   it into a link to the Cloud Sync page.

9. **[done f60c34a8ca] The Version row says "AppStore" on App Store builds made off master** (`PVSettingsViewModel.versionText`;
   sideloads say "Beta"). Also, `??` binds looser than `+`, so the build-number suffix is dead code. Decide
   what the row should show. As built: "3.4.0 (build)" everywhere (Settings and side menu), no channel
   suffix; the Settings check was really `ALTDeviceID`, so AltStore installs said "AppStore".

## P3 — visual consistency

10. **[done 96b88447d3] On-Screen Controls sliders are a bare `Text` plus slider** (opacity, scale), unlike the
    deadzone and rumble rows, which put a `SettingsRow` (icon, title, description) above the slider. The
    section also has unused `buttonSound` / `buttonPressEffect` / `playButtonSound`, a nested
    `#if !os(tvOS)` inside an `#if !os(tvOS)`, and inconsistent title case ("On-Screen Joypad with
    keyboard"). Same for Saves (auto-save slider) and Audio (volume slider). Other dead code: the
    commented-out Volume HUD and a no-op `rotationEffect`. The commented-out Web Server and
    feature-flag blocks in the Library sections are left for the `shared-libs-ui` session's area.
    Files: `SettingsSwiftUI.swift`.

11. **[done 43157ab5f6, tvOS focus f6803307d0] Pickers without `SettingsRow` labels.** Skin Mode is a 100pt wheel with uppercased raw
    values. Overlay Style and Core Deadzone Mode are bare pickers. The Core Compatibility row is a hand-built
    `HStack` with `accentColor`. Fix: `SettingsRow` labels, menu style on iOS.
    Files: `SettingsSwiftUI.swift`.

12. **[done 4b932c6212] iCloud Sync UI still isn't on retrowave tiles.** `CloudSyncSettingsView` (1,959 lines),
    `SyncLogViewer` (995) and `CloudSyncStatusView` use their own row types (`CloudSyncToggleRow`,
    `CloudSyncStepperRow`, `CloudSyncSelectionRow`) on flat `retroBlack.opacity(0.3)` cards. The target is
    the pause-menu tile look (see `ImportStatusView`). As built: an April pass had already styled the rows,
    headers and `SyncLogViewer`; the 26 flat panels left now use `cloudSyncCard()` / new `cloudSyncTile()`,
    and iOS gets the tvOS grid background. `CloudSyncStatusView` is unreachable (only its preview creates
    it) and was left alone; delete it in a follow-up.

13. **[done a3af5d4f78] DualSense Mic Button Action uses raw string tags** (`"muteAudio"` / `"none"`). The view now keeps
    them in one table (43157ab5f6); the key itself is still a `String`. Back it with an enum.

14. **[done 0f5a77beda] Two different `isAppStore` checks** (`AppState.shared.isAppStore` vs `PVAppType` in
    `AdvancedTogglesView`). Use one.

## Found during the batch

15. **[done a5dc4efdd0, dropped] `HapticFeedbackService` has its own key with no UI.** `@AppStorage("hapticFeedbackEnabled")` gates
    the success/error/selection taps in menus, and nothing in Settings writes it. Either add it as a "UI
    Haptics" row in Haptics & Rumble, or drop the check. Dropped: it only gates taps in the Cloud Sync
    screens and the support prompt, which iOS System Haptics already covers.

16. **[done ce4e854f24, restored] Volume HUD (`Defaults[.volumeHUD]`) is still read** by `PVControllerViewController`, but its
    Settings row was commented out (the dead comment is now removed). Decide whether it comes back.

17. **[done 92462068b9] The pause menu and Settings offer different auto-save presets.** The pause-menu long-press menu has
    2/5/10/15/30 min; Settings on tvOS has 1/2/5/10/15/20/30 (`AutoSaveIntervalRules.presets`). PVUIBase
    can't import PVSwiftUI, so sharing them means moving the rules down a tier. As built:
    `AutoSaveIntervalRules` lives in PVSettings; the tile lists the presets plus the stored value.

18. **Device pass needed for this batch:**
    - tvOS: Menu from Patches / ROM Tools and from Session Logs goes back one level.
    - tvOS: Saves › Auto-save Time opens the list, a pick sticks, and the row dims while Timed Auto
      Saves is off.
    - iPhone and iPad: the Skin Mode, Overlay Style, Core Deadzone Mode and Mic Button menus show their
      row text and the selected value.
    - In game: the pause-menu Rumble tile silences controller and device rumble, and the skin
      "toggle haptics" button silences on-screen button taps.
    - In game (batch 2): the Timed Auto Save tile's long-press lists 1-30 min; Volume HUD off shows the
      system volume overlay in the next game; the DualSense mic button still mutes after the enum change.
    - Settings (batch 2): Emulation › Gameplay Features on iPhone, iPad and tvOS (tvOS focus into and out
      of the new section); Library Management subheadings; Cloud Sync Settings cards on iPhone and tvOS.
