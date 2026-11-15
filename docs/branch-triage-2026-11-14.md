# Remote branch triage, 2026-11-14

Covers the 125 branches on `origin` other than `develop` (after `git fetch --prune`). Earlier pass:
[branch-triage-2026-10-11.md](branch-triage-2026-10-11.md) (local branches and worktrees).

How each branch was checked:

- commits ahead of and behind `develop`;
- whether the branch tip matches the head of its merged PR (if so, GitHub keeps it at `refs/pull/N/head`);
- for 2026 branches, the share of added lines already present in develop's copy of the same file. Lines in files that
  no longer exist on develop (thick RetroArch, pruned cores, pre-SkinKit skin views, the old side menu) count as
  obsolete, not missing;
- a manual look at every commit made after its PR merged.

Every tip listed for deletion is saved locally as `refs/archive/<branch>`. `pr/issue-3188` is the exception: an
older local tip already uses that name, so it is saved as `refs/archive/remote-tips/pr/issue-3188`. Restore a branch
with `git branch X refs/archive/X`.

## Keep

| Branch | Why |
|---|---|
| `master` | Release branch. It is in the 3.3.1 tag and 0 ahead, but CI and releases target it. |
| `backup/develop-pre-linearize-20261007` | Deliberate backup from before the Oct 7 linearize. It is 0 ahead (fully in develop), so deleting it loses nothing; your call. |

## Needs attention

| Branch | State | What to do |
|---|---|---|
| `agent/issue-3072` | Open draft [#3518](https://github.com/Provenance-Emu/Provenance/pull/3518): Cloudflare Worker cheat proxy for GameHacking.org. 7 ahead, 920 behind. | Decide: rebase and merge (then `wrangler deploy` and wire the URL into `GameHackingOrgLookup`), or close. |
| `codex/shared-library-metadata` | No PR. Its first 6 commits (nearby iCube mirroring) landed as [#3753](https://github.com/Provenance-Emu/Provenance/pull/3753). The last 4 (Oct 21–22, `81ad5a8136`..`b1456e31b5`) are not on develop: read-only Dolphin disc identity plus verified library identity bindings, 20 files, +1288 lines (`LibraryDiscIdentity.h`, `PVDolphinCore+LibraryIdentity.*`, `LibraryDiscIdentityReading`, `CoreLoader+LibraryIdentity`, `LibraryMetadataIdentityBinding` with tests). | Codex-owned. Ask whether it still wants this. If so, rebase only those 4 commits onto develop and open a PR. |
| `agent/issue-76` | [#2702](https://github.com/Provenance-Emu/Provenance/pull/2702) merged before its last commit `f87776a94a`, "save/restore AVAudioSession on Famicom mic start/stop". Develop's `Cores/FCEU/PVFCEUEmulatorCore.mm` still switches the session to PlayAndRecord and never restores it. | Real bug in an active core. Cherry-pick `f87776a94a`, which applies cleanly. |
| `cursor/save-state-versioning-386f` | No PR. "Warn before loading mismatched save states" plus dynamic PicoDrive state size. Nothing like it is on develop. Most of its target code has changed since. | Worth having, but rewrite it rather than merge it. File an issue, then archive the branch. |

Optional, small: `agent/issue-3087-netplay-fixes` commit `355cce88c9` adds a `deinit` to the Game Center netplay
view that clears `activeMatch.delegate` and disconnects. Develop has no such cleanup.

## Archive (delete from origin)

Rules:

- **0 ahead:** fully in develop or a tag, including `release/*`. Only `release/2.2.0` has one commit beyond its tag
  (a 2022 Catalyst build fix).
- **Content on develop:** `feature/pvwebserver-followups`, `ci/explicit-workflow-permissions`, `pr/issue-3188`,
  `patch-1` and `mrjschulte-arfix-sega` are already present in full. `codex/library-overlay-clearance` has nothing
  after its merged PR head.
- **Leftovers after merge, checked and obsolete:**
  - `fix/icloud-sim-entitlement-crash`: the plist fix landed separately in #3720, `CloudSyncStatusView` no longer
    exists, and `createSyncProvider` has no callers.
  - `agent/issue-2624-hw-render-fbo-resize`: a flag refactor of a resize path that works.
  - `agent/skin-scale-opacity` and `fix/revert-overlay-opacity`: the revert PR #3178 was closed, and
    `controllerOpacity` now drives PVTouchOverlay.
  - `agent/issue-2553-swiftdata-cloudkit`: a CI-only commit.
- **March 2026 agent, cursor and copilot branches:** Copilot-fix branches and closed or rejected PRs (#3176 l10n, #3608
  side menu, #3232 Hatari TOS, #3172 DOOM labels and others). Their code has since been rewritten or removed: thick
  RetroArch, skins moved to SkinKit, cheat DB lookup moved to PVLookup, shader settings replaced, `SideNavigationController` gone.
- **2018–2025 feature and core branches:** 2,600–10,000 commits behind, superseded by later core work (the SwiftPM
  conversion, the thin wrapper, the Oct core prune).

| Branch | Last commit | Ahead | Behind | PR |
|---|---|---|---|---|
| `feature/pvwebserver-followups` | 2026-11-09 | 1 | 116 | no PR |
| `ci/explicit-workflow-permissions` | 2026-11-08 | 1 | 127 | #3806 MERGED chore(ci): declare least-privilege workflow token permission |
| `codex/library-overlay-clearance` | 2026-11-03 | 6 | 196 | #3792 MERGED fix: compact library controls and keep filtering on the curr |
| `agent/issue-3601` | 2026-10-01 | 2 | 920 | #3608 CLOSED/draft [Agent] Replace SideNavigationController with SwiftUI side m |
| `fix/icloud-sim-entitlement-crash` | 2026-08-05 | 6 | 1200 | #3646 MERGED fix(icloud): simulator entitlement check crashed unentitled  |
| `agent/issue-3087-netplay-fixes` | 2026-03-28 | 14 | 2061 | #3559 MERGED [Agent] feat(netplay): relay default, deep link handler, Gam |
| `agent/issue-2624-hw-render-fbo-resize` | 2026-03-21 | 1 | 2325 | #3358 MERGED [Agent] feat(thin-libretro): HW FBO resize + context negotia |
| `agent/hatari-tos-fix-3223` | 2026-03-16 | 2 | 2584 | #3232 CLOSED [Agent] fix(hatari): detect word-swapped TOS ROMs; prevent D |
| `pr/issue-3188` | 2026-03-16 | 6 | 2620 | #3199 CLOSED [Agent] fix(skins): show downloaded skins as installed in ca |
| `agent/contentless-core-setup-guide` | 2026-03-15 | 0 | 2654 | #3171 CLOSED [Agent] feat(UX): in-app setup guide for contentless cores ( |
| `agent/fix-doom-button-labels` | 2026-03-15 | 1 | 2650 | #3172 CLOSED [Agent] fix(doom): correct default skin button labels for FP |
| `agent/localization-baseline` | 2026-03-15 | 2 | 2631 | #3176 CLOSED [Agent] chore(l10n): wrap hardcoded SwiftUI strings with Loc |
| `agent/skin-scale-opacity` | 2026-03-15 | 6 | 2632 | #3167 MERGED [Agent] feat(skins): global controller overlay scale and opa |
| `fix/revert-overlay-opacity` | 2026-03-15 | 2 | 2626 | #3178 CLOSED [Agent] revert(skins): remove controller overlay opacity fea |
| `pr/issue-3187` | 2026-03-15 | 1 | 2625 | no PR |
| `agent/fix-atarist-crash` | 2026-03-14 | 0 | 2740 | #3119 CLOSED [Agent] fix(hatari): fix Atari ST crash after TOS byte-patch |
| `agent/issue-2982-fix-hangs` | 2026-03-14 | 0 | 2740 | #3125 CLOSED [Agent] fix(stability): resolve threading deadlocks causing  |
| `agent/issue-2983-crabemu-input` | 2026-03-14 | 0 | 2740 | #3122 CLOSED [Agent] fix(input): correct CrabEMU input mappings for Colec |
| `agent/refactor-virtual-input-cleanup` | 2026-03-14 | 0 | 2740 | #3120 CLOSED [Agent] refactor(overlay): clean up virtual keyboard/mouse o |
| `cursor/skin-screens-download-access-6f2f` | 2026-03-11 | 4 | 2898 | no PR |
| `cursor/cloud-agent-1773187939958-a3uh9` | 2026-03-10 | 0 | 2896 | #2946 CLOSED Cursor: Apply local changes for cloud agent |
| `cursor/cloud-agent-1773198000484-3dnld` | 2026-03-10 | 0 | 2886 | no PR |
| `cursor/development-environment-setup-bf09` | 2026-03-10 | 1 | 2925 | no PR |
| `patch-1` | 2026-03-07 | 2 | 3040 | #2433 CLOSED Fix Simulator crash with empty library |
| `agent/cheat-db-md5-lookup` | 2026-03-05 | 12 | 3281 | no PR |
| `agent/issue-2509-copilot-fixes` | 2026-03-05 | 2 | 3196 | no PR |
| `agent/issue-2550-copilot-fixes` | 2026-03-05 | 2 | 3138 | no PR |
| `agent/issue-2553-swiftdata-cloudkit` | 2026-03-05 | 10 | 3101 | #2563 MERGED [Agent] SwiftData Task 4: Update CloudKit sync for SwiftData |
| `agent/issue-2560-copilot-fixes` | 2026-03-05 | 3 | 3138 | no PR |
| `agent/issue-2562-swiftdata-fixes` | 2026-03-05 | 6 | 3121 | #2569 CLOSED [Agent] fix: address Copilot review issues in SwiftDataDatab |
| `agent/issue-2564-copilot-fixes` | 2026-03-05 | 3 | 3138 | no PR |
| `copilot/sub-pr-2508` | 2026-03-05 | 12 | 3145 | #2537 CLOSED/draft [WIP] Update tvOS type mapping and multi-line input support |
| `agent/issue-2501-copilot-fixes` | 2026-03-04 | 3 | 3213 | no PR |
| `agent/issue-2475-cheat-types-native-cores` | 2026-03-03 | 1 | 3227 | #2496 CLOSED [Agent] feat: add PVSupportedCheatTypes to native core plist |
| `agent/issue-2480` | 2026-03-03 | 1 | 3270 | no PR |
| `agent/issue-2484-mgba-cheats` | 2026-03-03 | 2 | 3269 | no PR |
| `agent/issue-2451-crt-shader-params` | 2026-03-02 | 3 | 3284 | no PR |
| `agent/issue-2452-copilot-fixes` | 2026-03-02 | 3 | 3283 | no PR |
| `agent/issue-2452` | 2026-03-02 | 9 | 3281 | no PR |
| `agent/issue-2454-copilot-fixes` | 2026-03-02 | 1 | 3287 | #2464 CLOSED [Agent] fix(PVFeatureFlags): address Copilot review feedback |
| `agent/issue-2468` | 2026-03-02 | 7 | 3283 | no PR |
| `copilot/sub-pr-2450` | 2026-03-02 | 8 | 3292 | #2460 CLOSED Re-review PR #2450: All copilot feedback addressed |
| `agent/issue-2441` | 2026-03-01 | 1 | 3285 | #2456 CLOSED [Agent] Refactor Share/Create/Capture button detection into  |
| `release/3.0.6` | 2025-03-18 | 0 | 4779 | no PR |
| `feature/MupenGlidenEtcUpdate` | 2025-03-14 | 28 | 4849 | no PR |
| `feature/DeltaSkins` | 2025-02-07 | 0 | 5259 | no PR |
| `feature/new-cores/libretrogles` | 2025-01-22 | 92 | 5335 | #2373 CLOSED/draft Feature/new cores/libretrogles |
| `bugfix/SegaCDGenesisPlus` | 2025-01-20 | 1 | 5342 | no PR |
| `release/3.0.2` | 2025-01-15 | 0 | 5377 | no PR |
| `release/3.0.1` | 2025-01-09 | 0 | 5400 | no PR |
| `feature/CorePVBeetlePSX` | 2024-12-31 | 23 | 5460 | #2368 CLOSED/draft [Core] Beetle PSX |
| `feature/desmume2015` | 2024-12-30 | 10 | 5460 | #2371 CLOSED/draft [Core] Desmume2015 [WIP]  |
| `feature/flycastRedo2` | 2024-12-30 | 7 | 5460 | no PR |
| `feature/flycastRedo` | 2024-12-30 | 14 | 5460 | #2369 CLOSED/draft [Core] Flycast Redo 1 |
| `release/3.0.0` | 2024-12-29 | 0 | 5475 | no PR |
| `bugfix/deleterom` | 2024-12-23 | 1 | 5524 | #2365 CLOSED Fixes delete roms and a few other various menu actions |
| `feature/gameMoreInfoSwiftUI` | 2024-12-10 | 0 | 5671 | no PR |
| `bugfix/gearColoecoButtons` | 2024-12-02 | 0 | 5753 | no PR |
| `feature/SaveStateReimport` | 2024-12-02 | 0 | 5772 | no PR |
| `codesignchanges` | 2024-11-20 | 1 | 5982 | no PR |
| `feature/resetUserPreferredCore` | 2024-11-19 | 0 | 5973 | no PR |
| `bugfix/gameimportcrash` | 2024-11-17 | 2 | 5988 | #2359 CLOSED Game Importer System Logic Update |
| `feature/gameimporterstatus` | 2024-11-14 | 48 | 6097 | no PR |
| `develop-rf2222222-emuthreeRebirth` | 2024-11-10 | 16 | 6688 | no PR |
| `develop-testflight` | 2024-10-09 | 12 | 6660 | no PR |
| `pullrequests/rf2222222/rf2222222-emuthreeRebirth` | 2024-05-12 | 1 | 6663 | no PR |
| `feature/AppStoreDesmume2015` | 2024-05-05 | 1 | 6695 | #2335 CLOSED/draft [WIP] Desmume2015 into appstore builds |
| `rf2222222-emuthreeRebirth` | 2024-05-05 | 6 | 6695 | #2337 CLOSED/draft Build: PS2 / PPSSPP / AppIcon Fixes to pass all compile work |
| `feature/AppStoreTarget` | 2024-04-30 | 60 | 6782 | #2327 CLOSED/draft [WIP] AppStore target |
| `feature/MultiPlatformTargets` | 2024-04-29 | 34 | 6782 | #2278 CLOSED AllowMultiplePlatforms=1 various cores,frameworks, pre app s |
| `develop-spm2` | 2023-04-04 | 12 | 6931 | #2155 CLOSED/draft [WIP] Swift modules |
| `develop-spm` | 2023-01-17 | 6 | 6944 | no PR |
| `pullrequests/rf2222222/retroarch_features` | 2023-01-16 | 26 | 6981 | #2140 CLOSED Rebase and additions to #2138 |
| `sgc/metal-rebase` | 2022-12-27 | 18 | 7044 | no PR |
| `feature/core_dolphin_rebase` | 2022-12-26 | 0 | 7060 | no PR |
| `feature/core_dolphin` | 2022-12-25 | 20 | 7089 | #2075 CLOSED Dolphin support |
| `feature/AppSingleTarget` | 2022-12-24 | 7 | 7097 | #2100 CLOSED Single App Target |
| `mrjschulte-arfix-sega` | 2022-12-21 | 1 | 7097 | #2094 MERGED PVGenesis - Fix Genesis Aspect Ratio |
| `feature/patreon` | 2022-12-17 | 2 | 7108 | no PR |
| `feature/beetle_psx_gles` | 2022-12-16 | 7 | 7109 | #2074 CLOSED/draft [WIP] Beetle PSX |
| `pullrequests/rf2222222/play_features_2` | 2022-12-14 | 0 | 7115 | #2072 MERGED Pullrequests/rf2222222/play features 2 |
| `feature/VisualBoyAdvance-Enable-GameBoy` | 2022-12-11 | 3 | 7157 | #2060 CLOSED/draft [WIP] VisualBoyAdvanced enable GameBoy mode |
| `release/2.2.0` | 2022-12-09 | 0 | 7188 | no PR |
| `feature/desmume2015CoreOptions` | 2022-11-26 | 4 | 7301 | #2023 CLOSED/draft [WIP] Desmume2015 Core Options |
| `feature/OpenEMUShaders` | 2022-11-24 | 2 | 7301 | #2022 CLOSED/draft [WIP] OpenEMU Shaders |
| `feature/RetroInputs-oct23` | 2022-10-23 | 61 | 7449 | no PR |
| `feature/RetroInputs` | 2022-10-23 | 63 | 7449 | no PR |
| `feature/dos-box` | 2022-10-23 | 0 | 7439 | #1919 MERGED [Feature] librettro cores |
| `feature/new-cores/mednafenPce` | 2022-06-15 | 2 | 7620 | no PR |
| `release/2.1.1` | 2022-06-15 | 0 | 7618 | #1921 MERGED [Release] 2.1.1 |
| `feature/SwiftPackages` | 2022-05-16 | 5 | 7626 | no PR |
| `feature/PSX_Controller_Layout` | 2022-04-29 | 0 | 7626 | no PR |
| `feature/fceuxUpdate` | 2022-02-19 | 0 | 7643 | #1810 MERGED fceux update |
| `feature/doublebuffer` | 2022-02-16 | 1 | 7658 | no PR |
| `release/2.1.0` | 2022-02-15 | 0 | 7662 | #1750 MERGED [Release] 2.1.0 |
| `feature/mupenoptions` | 2022-01-16 | 0 | 7862 | no PR |
| `feature/metal` | 2022-01-13 | 0 | 7903 | no PR |
| `feature/UpdateMupen` | 2022-01-03 | 25 | 7971 | no PR |
| `release/2.0.4` | 2021-12-24 | 0 | 7997 | no PR |
| `release/2.0.3` | 2021-12-22 | 0 | 8008 | no PR |
| `feature/OECores` | 2021-12-16 | 0 | 8038 | no PR |
| `feature/GitHubActionsBuild` | 2021-12-02 | 1 | 8050 | no PR |
| `feature/new-cores/Dolphin` | 2021-11-21 | 0 | 8095 | no PR |
| `feature/new-cores/DuckStation` | 2021-11-21 | 0 | 8130 | no PR |
| `feature/new-cores/PSP-ppsspp` | 2021-11-21 | 0 | 8105 | no PR |
| `feature/new-cores/flycast` | 2021-11-21 | 0 | 8090 | no PR |
| `feature/SwiftCores` | 2021-09-14 | 6 | 8219 | no PR |
| `release/2.0.2` | 2021-09-14 | 0 | 8197 | no PR |
| `release/2.0.1` | 2021-09-09 | 0 | 8224 | no PR |
| `release/2.0.0` | 2021-08-03 | 0 | 8330 | no PR |
| `feature/reicast_move` | 2021-06-23 | 0 | 8389 | no PR |
| `feature/GitHubAutomation` | 2019-11-24 | 3 | 8636 | no PR |
| `feature/new-cores/Dreamcast-Reicast` | 2018-11-01 | 22 | 9865 | no PR |
| `feature/1004-8bitdo_2nd_player` | 2018-10-30 | 0 | 8924 | no PR |
| `feature/VirtualGameController` | 2018-10-19 | 3 | 9000 | no PR |
| `feature/new-cores/Saturn-yabause` | 2018-10-17 | 0 | 9034 | no PR |
| `feature/new-cores/PSX-Beetle` | 2018-10-14 | 1 | 9058 | no PR |
| `feature/MIDIController` | 2018-10-06 | 4 | 9093 | no PR |
| `feature/DocumentBrowserPreviews` | 2018-03-26 | 3 | 9991 | no PR |

### Commands (run by hand)

```bash
# 1. Optional: back up the archive refs to origin, so the only copy isn't on this Mac
git push origin 'refs/archive/*:refs/archive/*'
```

```bash
# 2. Delete the archived branches from origin
git push origin --delete agent/cheat-db-md5-lookup agent/contentless-core-setup-guide agent/fix-atarist-crash agent/fix-doom-button-labels agent/hatari-tos-fix-3223 agent/issue-2441 agent/issue-2451-crt-shader-params agent/issue-2452 agent/issue-2452-copilot-fixes agent/issue-2454-copilot-fixes agent/issue-2468 agent/issue-2475-cheat-types-native-cores agent/issue-2480 agent/issue-2484-mgba-cheats agent/issue-2501-copilot-fixes agent/issue-2509-copilot-fixes agent/issue-2550-copilot-fixes agent/issue-2553-swiftdata-cloudkit agent/issue-2560-copilot-fixes agent/issue-2562-swiftdata-fixes agent/issue-2564-copilot-fixes agent/issue-2624-hw-render-fbo-resize agent/issue-2982-fix-hangs agent/issue-2983-crabemu-input agent/issue-3087-netplay-fixes agent/issue-3601 agent/localization-baseline agent/refactor-virtual-input-cleanup agent/skin-scale-opacity bugfix/SegaCDGenesisPlus bugfix/deleterom bugfix/gameimportcrash bugfix/gearColoecoButtons ci/explicit-workflow-permissions codesignchanges codex/library-overlay-clearance copilot/sub-pr-2450 copilot/sub-pr-2508 cursor/cloud-agent-1773187939958-a3uh9 cursor/cloud-agent-1773198000484-3dnld cursor/development-environment-setup-bf09 cursor/skin-screens-download-access-6f2f develop-rf2222222-emuthreeRebirth develop-spm develop-spm2 develop-testflight feature/1004-8bitdo_2nd_player feature/AppSingleTarget feature/AppStoreDesmume2015 feature/AppStoreTarget feature/CorePVBeetlePSX feature/DeltaSkins feature/DocumentBrowserPreviews feature/GitHubActionsBuild feature/GitHubAutomation feature/MIDIController feature/MultiPlatformTargets feature/MupenGlidenEtcUpdate feature/OECores feature/OpenEMUShaders feature/PSX_Controller_Layout feature/RetroInputs feature/RetroInputs-oct23 feature/SaveStateReimport feature/SwiftCores feature/SwiftPackages feature/UpdateMupen feature/VirtualGameController feature/VisualBoyAdvance-Enable-GameBoy feature/beetle_psx_gles feature/core_dolphin feature/core_dolphin_rebase feature/desmume2015 feature/desmume2015CoreOptions feature/dos-box feature/doublebuffer feature/fceuxUpdate feature/flycastRedo feature/flycastRedo2 feature/gameMoreInfoSwiftUI feature/gameimporterstatus feature/metal feature/mupenoptions feature/new-cores/Dolphin feature/new-cores/Dreamcast-Reicast feature/new-cores/DuckStation feature/new-cores/PSP-ppsspp feature/new-cores/PSX-Beetle feature/new-cores/Saturn-yabause feature/new-cores/flycast feature/new-cores/libretrogles feature/new-cores/mednafenPce feature/patreon feature/pvwebserver-followups feature/reicast_move feature/resetUserPreferredCore fix/icloud-sim-entitlement-crash fix/revert-overlay-opacity mrjschulte-arfix-sega patch-1 pr/issue-3187 pr/issue-3188 pullrequests/rf2222222/play_features_2 pullrequests/rf2222222/retroarch_features pullrequests/rf2222222/rf2222222-emuthreeRebirth release/2.0.0 release/2.0.1 release/2.0.2 release/2.0.3 release/2.0.4 release/2.1.0 release/2.1.1 release/2.2.0 release/3.0.0 release/3.0.1 release/3.0.2 release/3.0.6 rf2222222-emuthreeRebirth sgc/metal-rebase 
```

## Other remotes

- `rf2222222`: 82 branches on a contributor's fork. They are not ours to delete. To stop fetching them, run
  `git remote remove rf2222222`.
- `parent/develop`: a stale tracking ref with no configured remote. Remove it with
  `git update-ref -d refs/remotes/parent/develop`.
