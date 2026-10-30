# Consolidated develop integration and test run

Coordinator: “Fix tvOS Top Shelf loading” (`01a1769e-4105-7932-88dc-aae0f28ab9ce`).
The user requested coordination, preservation of Claude's edits, cleanup/merge readiness, and one consolidated test build after parallel work is integrated. This document records current readiness; previous green CI does not certify the final combined tree.

## Integration ledger

| Scope / owner chat | State | Integration action |
| --- | --- | --- |
| Controller remaps — `01a17895-8112-77e1-a6ec-5908d02edfdc` | Merged: `d167e46f8b`, `9e799425d7`, `eb1949fd29`; isolated runtime probe 80/80 | No cherry-pick. Owner completed evidence archival and removed only its own temporary clone/build/simulator; owner note committed as `9c134b8e3b` (local). |
| Crash triage — `01a16b57-40fd-7360-981d-d38b3283f3db` | PR #3762 merged as `dd631b7c2c`; old branch/worktree already removed | No cherry-pick or cleanup needed. Hardware/telemetry checks remain below. |
| Core maintenance / Top Shelf registry — `01a1568b-dcc2-7c13-a927-0170e6469db8` | PR #3775 merged as `623070d35f`; hosted Maintenance green | Do not reapply source `40850343dc`. Needed ignored evidence preserved under `.git/ci-evidence/topshelf-maint-3775/`. Archive was refused because this is that chat's primary checkout; retain until the app safely detaches it. |
| Themes — `01a160ea-5e66-7880-90a9-85ba20676cf2` | Exclusive module/test changes committed locally as `06cf5e7826`; 13 shared UI files checkpointed as `143c0758ac` | Owner note is [themes](integration/themes.md). Shared checkpoint verified against owner blobs plus exact netplay additions; Claude source/index preserved. Never cherry-pick mixed WIP `c6ad62e60f`. |
| Netplay — coordinator | Checkpointed as `69646627f5`; both real simulator hub and exact-ROM context-entry flows passed | TV focus/selection contrast and toolbar follow-up is `9522cdeac8`; grid focus section is `d8c1c7a899`. Final builds and 2 UI tests per platform passed; screenshots reviewed. Full-core gameplay deferred below. |
| Claude UIKit/settings/alerts cleanup | Complete: `c6193f2770`; remote source integrated as `094e7e0fc4` | Committed and pushed. Source quiescent; old alert shims intentionally remain for remaining Home/TV paths. Dolphin inputs stay preserved separately. |
| Debug API — `feature/debug-api`, `Provenance-debug-api` | Clean source branch; PR #3773 already merged remotely as `d064efa221` | No duplicate PR/cherry-pick. Preserve evidence and let owner retire the source worktree. |
| Realm/SwiftData planning worktree | Docs-only PR #3772 merged remotely as `b68323ff71`; owner handoff complete | No migration code or runtime-test dependency. Source worktree can be reviewed for owner cleanup after confirming preservation. |

## Build slot and integration fixes

The completed combined run below supersedes the earlier Coreless-only checkpoint. Both shipping CI platforms passed; the standard tvOS simulator app also built and ran. The coordinator has released the local build slot; iFly validation remains owned by its separate chat.

The prior shipping tvOS retry stopped in `PVUI/Sources/PVUIBase/UIViewController+Alerts.swift`: `Bundle.module.localized` has no definition after cleanup removed its original extension. The new retry is `build/netplay-validation/hub-tvos-retry.log`. The coordinator restored the two unchanged helpers/comments from HEAD in a separate `PVUIBase/Localization/Bundle+Localized.swift`; Claude's alert source is untouched. The restored helper passed lookup/variadic-format probes and is committed as `93ca0b4d06`. Follow-up `81bc5be3e4` removes only the old extension from committed HEAD, avoiding duplicate definitions independently of Claude's still-uncommitted alert rewrite. Claude's working source and unrelated staged deletions were preserved.

The first Coreless tvOS retry compiled PVUIBase/PVSwiftUI, then failed on a stale generated reference to the removed `ProvenanceTV/Story Boards/en.lproj/SaveStates.storyboard`. Regeneration preserves the deletion; it also required widening `Tuist.swift` from Xcode-26-only to explicit Xcode 26 and 27 support. `mise exec -- tuist generate --no-open` now succeeds; Xcode compatibility fix committed as `f198acd52f`. The regenerated app retry is `build/netplay-validation/hub-coreless-tvos-regenerated.log`.

The regenerated tvOS Coreless app built successfully and the first real-hub simulator smoke passed on `33B9E85A-3815-4D71-90C6-976E90FF1601` (tvOS 27). This exposed a runtime UI issue: native tvOS `.searchable` opened its full-screen keyboard and hid toolbar actions. The hub now uses an inline plain TextField on TV; expanded Settings/Unverified/Back smoke passed in `tvos-20261030-003453`. Selecting search opens the keyboard only on request, and Menu returns to the hub with toolbar access. Final tvOS build including themed filters/Settings toolbar/grid focus passed in `hub-coreless-tvos-focus-final.log`. The original native picker and interim icon toolbar were superseded by the reviewed controls. iOS uses native `.searchable` unchanged.

## Real hub runtime scope

The real installed Coreless app contains shared PVUI/PVSwiftUI and Realm. Both platforms have passed opening from the library and from an exact ROM's context menu, Settings, opt-in Unverified artwork, game details without Host for an unknown game, Back without reopening, and exclusion of that game from Suggested. iOS rooms-tab navigation and TV search-keyboard/Menu behavior are covered. These are actual app UI checks; earlier focused form hosts are separate evidence.

The synthetic Atari `Theme Preview` ROM is deliberately unverified and Coreless installs no native netplay cores. Empty recommendations are expected. Positive eligibility and compatibility rules are covered by domain tests, not proof of a rendered multiplayer game. The Realm query unit suite and full-core/two-device flows remain in the consolidated run. Final iOS build `build/netplay-validation/hub-coreless-ios-final.log` succeeded; both real-app smoke tests passed in `build/netplay-hub-smoke/ios-20261030-004534/Results.xcresult` (2 tests, 0 failures).

Final runtime evidence (source checkpoint `d8c1c7a899` plus preserved Claude working edits):

| Platform | Actual app build | Real app UI tests |
| --- | --- | --- |
| iOS 27 / iPhone 18 Pro | `build/netplay-validation/hub-coreless-ios-final.log` — passed | `build/netplay-hub-smoke/ios-20261030-004534/Results.xcresult` — 2 passed |
| tvOS 27 / Apple TV | `build/netplay-validation/hub-coreless-tvos-focus-final.log` — passed | `build/netplay-hub-smoke/tvos-20261030-005651/Results.xcresult` — 2 passed |

Final screenshots are exported beside each result under `attachments/`. TV-only focus/toolbar follow-ups do not change the iOS layout. The coordinator's build slot is released. Repeat the consolidated checklist after recording the final clean merged source SHA.

## Prior remote/local gap — resolved 2026-10-30

Claude committed its alert/storyboard cleanup as `c6193f2770` and merged the three fetched remote commits in `094e7e0fc4`. The source gap is resolved; debug API (#3773), skin screen geometry (#3776), and SwiftData planning docs (#3772) are all included.

The final combined app-source checkpoint is `68d1fb56a8`, adding the new Top Shelf artwork/cache fix `efdb839bfb` and stable upstream SkinKit game-screen-selection pin. The first combined unit run exposed one invalid dynamic-Color identity assertion; `bb7a45198d` replaces it with resolved-color checks across Green/Cyan and is pushed to `origin/develop`.

[Branch consolidation audit](integration/branch-audit-2026-10-30.md) records all merged PRs, retained snapshots/worktrees, and six inactive ancestor branches removed locally. Never reapply the mixed WIP `c6ad62e60f`.

Dolphin's upstream checkout/generated native artifacts remain untouched outside the committed source. Three package-level lockfiles rewritten by standalone test resolution were archived under `build/consolidated-validation/resolved-inputs/` and restored after their runs; the production workspace lockfile is checkpointed. Clean CI validates committed inputs.

## Combined run — 2026-10-30

- Origin app source: `68d1fb56a8`; regression-test checkpoint: `bb7a45198d`.
- PVUI iOS unit run: **644 passed** (PVUIBase: 74 XCTest + 444 Swift Testing; PVSwiftUI: 20 XCTest + 106 Swift Testing). `build/consolidated-validation/PVUI-iOS-fixed.xcresult`, `pvui-ios-fixed-tests.log`.
- PVNetplay: **128 passed**; catalog ingestion: **5 passed**. `netplay-tests.log`, `catalog-tests.log`.
- Top Shelf snapshot config/artwork/cache: **17 passed**. `topshelf-snapshot-tests.log`.
- PVThemes iOS package suite: **2 passed**, including palette-role/contrast loops. `PVThemes-iOS-package.xcresult`, `themes-ios-package-tests.log`.
- PVLibrary: **795 passed** (667 XCTest + 128 Swift Testing), `PVLibrary-iOS-package.xcresult`. PVCoreBridge: **249 passed**, `PVCoreBridge-iOS.xcresult`. PVCoreBridgeRetro: **177 passed**, `PVCoreBridgeRetro-iOS.xcresult`. MoltenVK was ad-hoc signed only in processed test build products, matching CI. **2,017 automated package tests passed in these suites.**
- Standard shipping tvOS simulator app build: **passed**, `standard-tvos-build.log`. Uses existing native artifact inputs and an explicit Realm Clang warning workaround from the prior build. No CodeSigning.xcconfig change. Real standard-app netplay UI tests: **2 passed**, `build/netplay-hub-smoke/tvos-20261030-024826/Results.xcresult`. Rebuilt iOS Coreless app: **passed** with production SkinKit revision; real UI tests: **2 passed**, `ios-20261030-023811/Results.xcresult`. The test driver now accepts `--game-title` for controlled synthetic fixtures.
- Combined shipping CI on `bb7a45198d`: **SUCCESS**, [run 41011559807](https://github.com/Provenance-Emu/Provenance/actions/runs/41011559807), both iOS/tvOS build-and-upload jobs and Alpha Release update succeeded. Earlier run `41010717193` on the same app source was superseded by the test-fix push. Previous TestFlight `41007949653` on `094e7e0fc4` has tvOS success and iOS active; it predates the new artwork/cache fix.
- Focused debug API auth/registry tests: **7 passed**, `DebugAPI-iOS.xcresult`, `debug-api-ios-tests.log`. Total automated package tests: **2,024 passed**.
- Actual standard-app Home shelf: **appearance check passed and screenshot reviewed**, `Standard-App-Shelf.xcresult`, `shelf-attachments/B82E78D4-502B-4BCA-B613-5AB3780E9F34.png`. App Group snapshot points to `cover_C500F8D72DDBE516251C843CE77D1F85_v2_be53223e9aaec1d6_59be0b72de2ac6ab.jpg`; the real provider logged `loaded`, one section and one cover (41.4ms). Snapshot/cover saved under `build/consolidated-validation/actual-shelf/`.
- Cold external-URL/game launch is **not certified**. Old A/B fixture apps also registered `provenance://`; both owned fixtures were uninstalled from the dedicated shelf simulator. The OS URL-confirmation service subsequently kept the app inactive (`UIApplication.applicationState == 1`, confirmed by LLDB), so extra launch tests timed out before reaching the library. No app startup deadlock was established and no production workaround was added. `starting-app-sample.txt`, `startup-application-state-lldb.log`, `Standard-Shelf-Launch*.xcresult` retain evidence. Recheck actual shelf selection/game boot with an active simulator/device UI; this does not invalidate the earlier passing app/hub/shelf-render checks.
- The final checklist below distinguishes completed automated checks from device, gameplay and telemetry work still requiring a later run.

## Final source checkpoint

Before the consolidated run, record develop SHA, PR/source SHAs, dirty status and intended build variants. Commit each owner's exclusive files separately. For files shared by themes/netplay/Claude, preserve all reviewed changes and record joint ownership rather than silently folding other work into one feature. Do not remove a branch/worktree until all unique changes and evidence have been preserved and integration is proven by ancestry or patch equivalence.

## One consolidated validation run

- [x] Full shipping iOS and tvOS compile on final integrated source: CI run41011559807 on `bb7a45198d` succeeded for both platforms. Standard tvOS simulator Debug/ad-hoc build also passed. Lite remains an internal compile smoke, not a release gate.
- [x] Run PVUI unit tests via `PVUI-UnitTests`, plus PVLibrary and PVCoreBridge/thin suites: 644 + 795 + 249 + 177 passed on iOS Simulator. The tvOS app/UI compile and runtime checks remain separate below.
- [x] Run PVNetplay package tests, core-compatibility tests and catalog ingestion tests: 128 + 4 (inside the PVUI run) + 5 passed on combined source.
- [ ] Netplay full runtime sweep (menu/context entry, Settings, artwork, opt-in Unverified, no Host for unknown game, Back, TV focus/search and rooms UI **passed on both**; remaining sort/positive-compatible-host/live-room checks need the full game/session matrix): open from menu and game context; artwork/search; deterministic Suggested/All supported/Recent/Favorites; separate opt-in Unverified; no single-player/unsupported suggestions; details and Back without reopening loops; nearby rooms survive TV child covers; host limits and incompatible room explanations.
- [ ] Complete actual tvOS Top Shelf launch verification: final-source artwork and `_v2_` cache regeneration **passed**; cold URL/game boot remains unverified due the simulator OS-confirmation/activation issue above. Prior registration A/B evidence is in `build/topshelf-validation/STATUS.md`.
- [ ] Themes (2 standalone palette tests pass; full visual sweep remains): Green, light Cyan, RetroWave in populated library and Settings on iOS/tvOS; search/chips/banner/shelf headings/View All, focus borders/sidebar edge; persist RetroWave across relaunch. Full PVThemes XCTest and remaining variants were not all run previously.
- [ ] Alerts/settings cleanup: opaque themed alerts, destructive/cancel actions, text input, Back/focus, settings navigation and replacement of deleted storyboard routes, on iOS/tvOS.
- [ ] Netplay two-device gameplay: same-ROM/core/version handshake, host/join/password/full room, disconnect/reconnect; native mGBA two-seat link and supported shared-console integration; spectators only where implemented. Simulator UI tests do not certify gameplay.
- [ ] Physical Apple TV: start virtualjaguar, quit, start another game; check stale perf-counter teardown regression.
- [ ] iOS next MetricKit crash delivery creates a fatal Sentry event with `callStackTree.json`; verify actual dSYM upload (upload failures currently warn). tvOS has no MetricKit.
- [ ] Investigate unresolved RUNNINGBOARD `0xdead10cc` background kills with cloud-sync owner; do not mark root cause proven. Other older crash signatures still need downloadable evidence.

## Owner-specific evidence / deferred checks

- Controller remaps: [owner checklist](integration/controller-remaps.md). Runtime proof is synthetic GCController + input-boundary probes, not physical controller/Settings/hotplug verification.
- Themes: `build/theme-review/validation/README.md`, `final-theme.patch`, screenshots and palette checks are ignored artifacts; retain required evidence before cleaning build outputs.
- Netplay: [implementation spec](../superpowers/specs/2026-10-29-netplay-library-redesign.md), `build/netplay-validation/STATUS.md`, `.xcresult` bundles/screenshots. Real Coreless builds succeeded for both platforms. iOS `ios-20261030-002838` passed both real hub and exact-ROM context-menu tests; TV `tvos-20261030-003029` passed context-menu details/Back, and `tvos-20261030-003453` passed expanded hub remote navigation, Settings, opt-in Unverified artwork, detail/Back, exclusion from Suggested, and rooms. Visual review found pale focused-filter text, weak unfocused contrast and a clipped toolbar title. Follow-up `9522cdeac8` uses themed TV filter buttons with separate focus/selection colors and a plain Settings toolbar title. Final TV build `hub-coreless-tvos-focus-final.log` and `tvos-20261030-005651/Results.xcresult` passed (2 tests, 0 failures), including Down from the rightmost filter into the game grid. Final iOS build `hub-coreless-ios-final.log` and `ios-20261030-004534/Results.xcresult` passed (2 tests, 0 failures). Both final screenshot sets were reviewed.
- Debug API: owner confirms clean `feature/debug-api` at `2fa3c426a3`, merged remotely via #3773. Earlier API/auth/pause/save/load/boot/exit checks and simulator compiles passed; captured gameplay was flat gray/black even with normal manual launch, so it does not certify rendering. Defer physical-device gameplay PNG/shader visuals, populated cover mosaic, first-run/existing-save prompt handling, Release hidden-setting gate and PVDebugAPI tests. Preserve worktree/evidence until owner cleanup checkpoint. Preserve the clean worktree until consolidated device/gameplay evidence is secured. Owner-reported evidence: `/private/tmp/claude-501/-Users-jmattiello-Workspace-personal-os/25e06c85-2b89-430e-8188-2d86c49a415b/scratchpad/` (`shots2`, `shots3`, `build-ios.log`, `build-tvos-pkg.log`, if still present). Shared handoff: `/Users/jmattiello/Library/Application Support/Claude/side-session-notes/local_363335a9-43e6-43f7-84db-97d32b2b19a6/provenance-debug-api.md`. Preserve required temporary evidence before cleanup. Skin-switch investigation produced no source changes and stays a separate follow-up.
- Crashes: shared side-session note `crash-triage-findings.md`; dSYM upload source `7af72cb040`. Preserve owner notes before removing temporary artifacts.

## Worktree inventory cautions

- `maint/auto-local` is fully behind local develop (zero unique commits at inventory). Confirm no active maintenance job and preserve ignored job evidence before cleanup.
- `.claude/worktrees/dazzling-poitras-851dbb` has three source commits squash-merged through PR #3771; preserve worktree/evidence pending its owner's cleanup checkpoint.
- The detached Claude scratch worktree is reserved for Claude; preserve it.
- The maintenance registry source branch is patch-merged through PR #3775, not an ancestor after squash. Its one unique source commit is not an unmerged feature.
- Do not fast-forward/reset main to an older test branch. Main contains shared uncommitted source and staged cleanup deletions.

## Reproducible real-hub smoke

After building and installing the app, run:

```sh
python3 Scripts/dev/run_netplay_hub_smoke.py --platform tvos --udid <TV-UDID>
python3 Scripts/dev/run_netplay_hub_smoke.py --platform ios --udid <PHONE-UDID>
```

The smoke expects an imported synthetic game named `Theme Preview` with artwork; keep it unverified. `--test testRealLibraryHub` or `--test testGameContextMenuOpensDetailsOnce` runs one flow.

The default bundle is `org.provenance-emu.provenance.dev.coreless`; use `--app-bundle org.provenance-emu.provenance` for a shipping app. The runner builds only a small UI-test bundle and drives the real installed app. It retains `.xcresult`, exported screenshots and AX tree under `build/netplay-hub-smoke/`. It never substitutes the old Settings/room-only fixture for the library hub.

## Other project coordination

Keep iFly's integration/build run separate from Provenance. PR #875 merged as `3b3373bf2`, #876 as `707f67e73`; their worktrees/branch names were archived by the owner, and main was fast-forwarded cleanly. Evidence and backups: `../iFly-worktree-archives/2026-10-30/PR-INTEGRATION.md`.

The iFly owner is now handling test-only integration fixes on `codex/combined-validation-fixes` and a separately authorized shared SkinKit asset-fallback regression from SkinKit #39. Preserve that active work and DreamPicoPort PR #877. No new shared SkinKit source or pin changes were made by this Provenance run; Provenance stays on its validated `f394638` pin. iFly's fresh simulator cores, Continuity/keychain behavior, physical-controller checks and VoiceOver belong to that owner's own final run.
