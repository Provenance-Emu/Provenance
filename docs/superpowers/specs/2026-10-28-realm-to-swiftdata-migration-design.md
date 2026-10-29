# Realm → SwiftData migration: scope and plan

Date: 2026-10-28. Status: proposal, no code changes yet. Supersedes the March 2026 status in epic
[#2510](https://github.com/Provenance-Emu/Provenance/issues/2510).

## Why now

Two 3.4.0 TestFlight crashes in one week were Realm thread-confinement bugs:

- `a4cab8efd8`: `CloudKitRomsSyncer.submitArtworkTasks` returned a lazy `Results` map out of
  `withBackgroundRealm`. A later read on another thread threw an RLMException.
- `bae478d1ed`: tvOS `TVMediaSystemGamesView.loadContent` read a detached `Realm()` and threw
  "Realm accessed from incorrect thread" inside `filter` on every boot into a system screen.

The question is whether to leave Realm for SwiftData. One suggestion was tvOS first, because tvOS 3.4
has never shipped publicly.

**SwiftData does not remove this class of bug by itself.** A `@Model` instance belongs to its
`ModelContext`, just as a Realm object belongs to its thread. Passing one across actors is still
wrong. What changes:

- `@Model` and `ModelContext` are not `Sendable`, so strict concurrency flags many crossings at
  compile time. Realm reports them only at runtime.
- The fix for both stores is the same: only value types cross threads, and one owner per store does
  the reads. `GameCellModel` already works this way.

So every option below starts with the same phase: a value-type repository seam. That phase alone
fixes the crash class while Realm is still underneath.

## 1. Earlier work

### Issues

| Link | State | What it is | Still applies? |
|---|---|---|---|
| [#2510](https://github.com/Provenance-Emu/Provenance/issues/2510) | open | Epic: Realm → SwiftData. The 2026-03-06 status comment marks tasks 1–7 and 9 done. | The plan shape holds. The status is wrong (see "Actual state"). |
| [#2551](https://github.com/Provenance-Emu/Provenance/issues/2551) | closed | Task 2: `SwiftDataDatabaseDriver` | Code exists. Only the importer bridge uses it. |
| [#2552](https://github.com/Provenance-Emu/Provenance/issues/2552) | closed | Task 3: one-time Realm → SwiftData migration | Code exists and has never run. It predates schema v24–v29. |
| [#2553](https://github.com/Provenance-Emu/Provenance/issues/2553) | closed | Task 4: CloudKit sync for SwiftData | Code exists with no callers. It cannot work as written (see CloudKit below). |
| [#2554](https://github.com/Provenance-Emu/Provenance/issues/2554) | closed | Task 5: importer dual-write | **Live in production**, with no flag |
| [#2555](https://github.com/Provenance-Emu/Provenance/issues/2555) | open | Task 6: views to `@Query` / `@Observable` | Not started beyond one unused driver |
| [#2556](https://github.com/Provenance-Emu/Provenance/issues/2556) | closed | Tasks 7–9: tvOS support, remove Realm, tests | tvOS compiles. Realm is not removed. Tests exist. |
| [#2574](https://github.com/Provenance-Emu/Provenance/issues/2574) | closed | Bug: shared container created a new `ModelContainer` per call | Fixed by #2576 / #2600 |
| [#2506](https://github.com/Provenance-Emu/Provenance/issues/2506) | open | Cheats persistence: schema workaround, SwiftData model, CloudKit | The Realm parts landed (v24, #2507, #2940). The SwiftData part follows this plan. |
| [#2776](https://github.com/Provenance-Emu/Provenance/issues/2776) | open | Multi-select batch operations data layer ("Realm + SwiftData-compatible") | Belongs on the Phase 1 repository API |
| [#2710](https://github.com/Provenance-Emu/Provenance/issues/2710) | closed | `PVGame` `matchSource` / `userCustomizedFields`, done as Realm v27 | `Game_Data` has these fields |
| [#3181](https://github.com/Provenance-Emu/Provenance/issues/3181) | closed | Save-state crash from the pause menu: a Realm thread violation | Same crash class as this week's |

### Pull requests

| Link | State | Content |
|---|---|---|
| [#2522](https://github.com/Provenance-Emu/Provenance/pull/2522) | merged | `@Model` on 11 draft `*_Data` models; `@Attribute(.unique)` on keys |
| [#2523](https://github.com/Provenance-Emu/Provenance/pull/2523) | merged | Review fixes on #2522 |
| [#2562](https://github.com/Provenance-Emu/Provenance/pull/2562) | merged | `SwiftDataDatabaseDriver` (501 lines) and tests |
| [#2569](https://github.com/Provenance-Emu/Provenance/pull/2569) | closed, not merged | Review fixes for the driver, superseded by commits squashed into #2562 |
| [#2564](https://github.com/Provenance-Emu/Provenance/pull/2564) | merged | `RealmToSwiftDataMigration` (1,286 lines, 10 phases) and tests |
| [#2563](https://github.com/Provenance-Emu/Provenance/pull/2563) | merged | `CloudKitModelContainerConfiguration`, `CloudKitSwiftDataSyncManager`, `SwiftDataSyncActor`, `SwiftDataLocalSyncMonitor` |
| [#2566](https://github.com/Provenance-Emu/Provenance/pull/2566) | merged | `GameImporterSwiftDataBridge`: dual-write from the importer |
| [#2567](https://github.com/Provenance-Emu/Provenance/pull/2567) | merged | tvOS validation; `SwiftDataCRUDTests`, `RealmToSwiftDataMigrationTests` |
| [#2568](https://github.com/Provenance-Emu/Provenance/pull/2568) | merged | `SwiftDataContinuesDataDriver` (never instantiated) |
| [#2570](https://github.com/Provenance-Emu/Provenance/pull/2570) | merged | `fetchLimit` fix; "wire ModelContainer to hosted views" (no `.modelContainer` remains in PVUI today) |
| [#2576](https://github.com/Provenance-Emu/Provenance/pull/2576) | merged | One app-wide `PVSwiftDataSchema.sharedContainer` |
| [#2600](https://github.com/Provenance-Emu/Provenance/pull/2600) | merged | Lock around `sharedContainer` |
| [#2887](https://github.com/Provenance-Emu/Provenance/pull/2887) | merged | That lock changed to `OSAllocatedUnfairLock` |
| [#2597](https://github.com/Provenance-Emu/Provenance/pull/2597) | merged | `Cheats_Data.codeType` and file path |
| [#2507](https://github.com/Provenance-Emu/Provenance/pull/2507) | merged | Realm v24 cheat `codeType` split |
| [#2940](https://github.com/Provenance-Emu/Provenance/pull/2940) | merged | CloudKit sync of cheat files (file-based, not SwiftData) |
| [#3540](https://github.com/Provenance-Emu/Provenance/pull/3540) | merged | Realm v27 `matchSource` / `userCustomizedFields`, mirrored on `Game_Data` |

Other commits on develop: `3b33572d73` (iOS/tvOS minimum 17.0), `abaee18be3` (removed the
`canImport(SwiftData)` guards), `53742a85f6` (`Game_Data.mockGenerate`), `493c8cf963` (the
`.agents/skills/swiftdata-pro` skill), `804920129d` (made `SwiftDataDatabaseDriverTests` and the
rest of PVLibraryTests compile again).

### Branches

All three are squash-merged leftovers whose content is on develop. Keep them as history. Nothing
there needs salvaging.

- [`agent/issue-2553-swiftdata-cloudkit`](https://github.com/Provenance-Emu/Provenance/tree/agent/issue-2553-swiftdata-cloudkit) (8 commits): superseded by #2563.
- [`agent/issue-2562-swiftdata-fixes`](https://github.com/Provenance-Emu/Provenance/tree/agent/issue-2562-swiftdata-fixes) (6 commits): superseded by #2562; head of #2569.
- [`agent/issue-2564-copilot-fixes`](https://github.com/Provenance-Emu/Provenance/tree/agent/issue-2564-copilot-fixes) (3 commits): superseded by #2564.

None of the 87 `refs/archive/*` refs listed in `docs/branch-triage-2026-10-11.md` touches
`SwiftData/`, `Migration/RealmToSwiftData*` or `Database/Drivers/`. `refs/archive/pr/issue-3181`
holds the #3181 Realm-thread fix. `refs/deleted-branches/realm-readonly-extension-config` is local
only; develop has its content (`145b8bb25a`, `c0b87ebd26`).

### Actual state on develop (corrects the March status)

| Piece | Runs at runtime? | Notes |
|---|---|---|
| `GameImporterSwiftDataBridge` | **Yes, on every import, no flag** | `GameImporterDatabaseService.swift:427,486,535,950`. Errors are swallowed (`WLOG`). |
| `PVSwiftDataSchema.sharedContainer` | Yes, created lazily by the bridge | Local-only `ModelConfiguration` with no URL, so it lands in the app's own Application Support, outside the App Group. On tvOS that storage is not guaranteed persistent. |
| `SwiftDataDatabaseDriver` | Only inside the bridge | Nothing reads through it |
| `RealmToSwiftDataMigration` | **Never** | Only tests reference it |
| CloudKit SwiftData (`CloudKitSwiftDataSyncManager`, `SwiftDataSyncActor`, `SwiftDataLocalSyncMonitor`, `CloudKitModelContainerConfiguration`) | **Never** | No callers. `CloudKitSchema.swift:112-119` says it is "always on", which is false. |
| `SwiftDataContinuesDataDriver` (PVUI) | Never | `RealmContinuesDataDriver` is the default |
| `@Query`, `.modelContainer` | None | |

So iOS and tvOS installs that have imported a game since March carry a partial, write-only SwiftData
store that nothing reads. It holds only the games imported or re-imported since then.

Defects in the existing SwiftData code:

1. **The models don't match Realm v29.** Missing models: `PVPatch` (v26/v29), `PVControllerProfile`
   and `PVControllerMapping` (v22/v28). Missing fields, by model:

   | Model | Missing fields |
   |---|---|
   | `Game_Data` | `contentless`, `isPatchVariant`, `baseGameMD5`, `patchID`, `isHiddenPatchVariant`, and the patches inverse. `isDownloaded`/`fileSize` are `@Transient`. |
   | `SaveState_Data` | `isPinned`, `isFavorite`, `userDescription`, `lastUploadedDate`, `isDownloaded`, `fileSize` |
   | `Core_Data` | `appStoreDisabled`, `contentless`, `supportedCheatTypeNames` |
   | `System_Data` | `appStoreDisabled` |
   | `BIOS_Data` | the cloud fields |
   | `File_Data` | `_relativeRoot` and `sizeCache`, so relative-root resolution is lost |
   | `User_Data` | `isPatron`, `savesAccess` |
2. **The unique constraints conflict with `GameRekey`.** `Game_Data` is unique on both `id` and
   `md5Hash`. `GameRekey` keeps `id` while changing `md5Hash`, so the bridge's next save of a
   rekeyed game collides on `id`, and the error is swallowed. `BIOS_Data` is unique on
   `expectedMD5`, which Realm does not require.
3. **The CloudKit container can't be created.** SwiftData with CloudKit forbids
   `@Attribute(.unique)` and needs every property optional or defaulted and every relationship
   optional (`.agents/skills/swiftdata-pro/references/cloudkit.md`). `BIOS_Data.expectedFilename`
   has no default, and every model uses `.unique`, so `makeCloudKitEnabledContainer` would throw.
4. **No `VersionedSchema` / `SchemaMigrationPlan`.** `v1Schema` is a bare `Schema`.

**What to keep:** the migration's dependency order and phasing, the test scaffolding, and the store
shape as a starting point. Rebuild the models against v29. Delete the CloudKit SwiftData files.
Gate the bridge now (Phase 0).

## 2. Realm surface inventory

### Schema and files

`RomDatabase.swift`: `schemaVersion = 29`. It has 14 object types: PVGame, PVSystem, PVCore,
PVBIOS, PVSaveState, PVCheats, PVPatch, PVControllerProfile, PVControllerMapping (embedded),
PVLibrary, PVRecentGame, PVUser, PVFile, and PVImageFile (a subclass of PVFile). The models live in
`PVLibrary/Sources/PVRealm/RealmPlatform/Entities/`.

| Model | Primary key | Notable |
|---|---|---|
| PVGame | `md5Hash` (uppercase, header-stripped importer MD5) | `id` indexed and stable across rekey; links to `file`, `relatedFiles`, `originalArtworkFile`, `screenShots`, `system`; LinkingObjects to saves, patches, variants, cheats, recents, libraries; cloud fields; v29 patch-variant fields |
| PVSaveState | `id` | `game`, `core`, `file`, `image`; pin/favorite; cloud fields; `createdWithCoreVersion` |
| PVSystem | `identifier` | `controlLayoutData: Data?` (JSON blob) is the only blob in the schema; `supportedExtensions: List<String>` |
| PVCore | `identifier` | `supportedSystems` many-to-many, license fields (v25) |
| PVBIOS | `expectedFilename` | `expectedMD5` indexed, cloud fields |
| PVCheats | `id` | legacy `dynamic var`; `codeType` (v24) |
| PVPatch | `id` | `PersistableEnum` `matchState`; raw-string enums; SHA-256 fields; `game`/`variantGame` links |
| PVControllerProfile | `id` | embedded `List<PVControllerMapping>`; `gameID` is a string, not a link |
| PVFile / PVImageFile | none | `partialPath` + `_relativeRoot` (Int enum); class inheritance |

Files:

- The store is `default.realm`, or `lite.realm` for Lite. It sits in the App Group container, which
  on tvOS is `Library/Caches/`, because tvOS Documents is not writable. It falls back to Documents
  when the group is unreadable.
- Unencrypted. Compacted at launch when over 20 MB and under 60% used.
- `default.restored.realm` swap-in for backup restore.
- `readOnlyConfig` for extensions.

The migration block covers v2–v29. v17 onward added cloud fields, controller profiles (v22),
cheats `codeType` (v24), licenses (v25), PVPatch (v26), match source (v27), light-bar colour (v28)
and patch variants with a backfill (v29).

### Threading helpers (the thing that keeps breaking)

- `RomDatabase.sharedInstance` returns the singleton on main. Off main it builds a per-thread
  `RomDatabase`, cached through `Thread.realm`.
- `.realm` is `try! Realm(configuration:)` on every access.
- `RealmContext.withRealm` (main), `withRealmSync` (`@MainActor`) and `withBackgroundRealm`
  (`Task.detached(.utility)`). Results must be `Sendable`, so callers return `.freeze()`d objects.
  That rule is easy to break with a lazy map (`a4cab8efd8`).
- Static caches of **live** objects (`gamesCache`, `systemCache`).
- No mechanical enforcement: the rule lives in comments.

Call-site counts, by pattern:

| Pattern | Lines / files |
|---|---|
| Direct `Realm()` / `Realm(configuration:)` opens | PVLibrary 62, PVRealm 8, PVUI ~62, Extensions 2, tests 24 |
| `.freeze()` family in PVUI | 174 lines / 51 files |
| `RomDatabase.sharedInstance` in PVUI | 165 / 59 |
| `@ObservedResults` / `@ObservedRealmObject` | 23 / 18 |
| `.observe(` / `NotificationToken` | 28 / 11 |
| RxRealm / RxSwift | PVLibrary 23 files, PVRealm 5, PVUI 13, plus the local `Packages/RxRealm` copy |
| Files importing RealmSwift | ~204 (PVUI 96, PVLibrary 51, PVRealm 23, tests 12, Extensions 6, other) |

The heaviest PVLibrary files are `ArtworkSearchQueue.swift` (13 bare `try? Realm()` in closures)
and `RomDatabase.swift` (17).

### CloudKit (`PVLibrary/Sources/PVLibrary/Cloud Sync/`)

The sync is hand-rolled on the private database:

- Classes: `CloudKitSyncer` and its subclasses, `CloudKitRomsSyncer`, `CloudKitSaveStatesSyncer`,
  `CloudKitBIOSSyncer` and `CloudKitInitialSyncer`, driven by `CloudSyncManager`.
- Record types: `ROM`, `SaveState`, `BIOS`, `File`, `Metadata` (`CloudKitSchema.swift`). `Cheat`
  is reserved.
- Record names are deterministic and come from **domain keys**, not Realm identities: `rom_<md5>`,
  `savestate_<gameID>_<filename>`, `bios_<systemID>_<md5>`, `file_<directory>_<id>`.
- Realm models carry sync bookkeeping (`cloudRecordID`, `isDownloaded`, `fileSize`,
  `hasCloudAssets`, `lastCloudSyncDate`, `lastUploadedDate`).
- `LocalGameSyncMonitor` observes PVGame on its own serial queue (`observe(on:)`). SwiftData has no
  direct equivalent before iOS 18 history tracking.
- Several syncers call `RomDatabase.sharedInstance.game(withMD5:)` from async contexts and get a
  live object on whichever thread the task resumed on, for example `CloudKitRomsSyncer.swift:1119,
  1445, 1544, 2143`. These are the next crash candidates.

### Importer, GameRekey, library moves

- The importer (`GameImporter`, `GameImporterDatabaseService`) writes through `withBackgroundRealm`
  and returns frozen games. The artwork queue and self-healing open bare `try? Realm()` in many
  closures.
- `GameRekey` copies a PVGame under a new `md5Hash` (it is the primary key), re-points saves,
  cheats, recents, patches, variants, libraries and controller profiles, then raw-deletes the old
  row. Its only caller is `PatchReplacement.commit`.
- `LibraryPathRemapper` rewrites `PVFile.partialPath` and `PVGame.romPath` after a library move.
  It runs on main.
- `LibraryMove*` (PVFileSystem) has no Realm code, but its exclusions match `.realm` names only
  (`LibraryMovePlanner.swift:158`, `LibraryMoveTypes.swift:43`). A SwiftData store in the App Group
  would need `.store`, `.store-wal` and `.store-shm` excluded too.

### Extensions and snapshots

| Consumer | Data source |
|---|---|
| Spotlight index (`IndexRequestHandler.swift:52`) | Realm, **read/write** `realmConfig`, including the migration block |
| ROM File Provider (`FileProviderExtension.swift:46`, `RomFileProviderCPDI.swift:18`) | Realm, read/write default config |
| SpotlightImportExtension | Realm, `readOnlyConfig` |
| Top Shelf | `PVLibrarySnapshot` from the App Group (no Realm) |
| Widgets | App Group UserDefaults JSON (`PVLibrarySnapshotLegacy`) |
| Quick Look and thumbnails | File-based `LibraryIndex` in the App Group |
| PVAppIntents | No Realm. `ToggleFavoriteIntent` queues the change and the app applies it. |

The writers are `WidgetDataWriter.writeFromRealm` and `LibrarySnapshotWriter.writeFromRealm`. Both
are in PVUI and read on `@MainActor`.

The snapshot pattern already decouples five consumers from the store. Moving Spotlight and the File
Provider onto snapshots too would leave no extension opening the database.

### PVUI

- 96 files import RealmSwift, concentrated in `PVUIBase/SwiftUI` (29), `PVUIBase` (26), Settings
  (13) and Consoles (9).
- tvOS Media UI: `TVMediaMainView.swift` has
  - 4 `Task.detached { try Realm() … .freeze() }` reads (systems, games per system, favorites,
    search). They are safe today because each block freezes before returning.
  - main-thread observers;
  - main-thread writes through `RomDatabase.sharedInstance`.
- Remaining escape candidates in tvOS Media UI:
  - `TVMediaGameActions` delegate methods capture a live `PVGame` into `Task { @MainActor in }` and
    freeze it inside, which is safe only if the delegate fires on main.
  - `TVMediaRouter` payloads and `TVMediaSaveBrowserContext` carry `PVGame` without enforcing
    frozen.
- Existing value seams to build on:
  - `GameCellModel`, an immutable snapshot conforming to `GameItemPresentable`.
  - `ContinueItemModel`, `RetroSaveStateItem` and `SaveImportMatchResult`.
  - The protocols `ContinuesDataDriver`, `SaveStateDriver` (with a mock) and `GameLibraryDriver`.
- Types holding live objects: `RetroGameCellModel.originalGame`,
  `RetroGameLibrarySystemMoveState`, `GameSkinSelectionState`, `SaveBrowserContext` and
  `RealmGameWrapper` (`@ObservedRealmObject`).

## 3. Options

Two constraints hold for every option:

- **CloudKit: keep the hand-rolled record schema unchanged** (record types, field keys,
  deterministic names). Do not adopt `NSPersistentCloudKitContainer` in this migration:
  - It writes `CD_*` records into its own zone, so devices on different app versions would split
    metadata.
  - It forbids the uniqueness `md5Hash` dedupe relies on.
  - The hand-rolled syncers already carry the metadata.

  Because record names come from MD5, game ID and filename, a Realm client and a SwiftData client
  can sync through the same container, provided the CKRecord encoding of a game is byte-for-byte
  the same from either backend.
- **iOS users on Realm v29 need a launch-time copy into SwiftData.** Realm must stay linked for the
  migrator for several releases after cutover, because users skip versions. `default.realm` stays
  untouched until a later release deletes it.

### (a) tvOS-only SwiftData

Use SwiftData on tvOS and keep Realm on iOS.

- **iOS data path:** none for now. tvOS TestFlight users on Realm still need a migration or a
  library rescan. Their Realm sits in purgeable Caches, so a rescan from ROM files is an acceptable
  fallback there.
- **CloudKit:** works only with the identical-encoding constraint, since an iPhone on Realm and an
  Apple TV on SwiftData share the container.
- **Cost:** about the same as (b) minus the iOS migration. PVLibrary and PVUI are shared, so tvOS
  needs the full repository abstraction and a complete SwiftData backend anyway: importer, CloudKit
  syncers, GameRekey, path remapper, patches and controller profiles.
- **What it leaves you with:** two backends in production indefinitely, `#if os(tvOS)` at the
  store boundary, and iOS still carrying the crash class.
- **Risks:** ships SwiftData to the platform with the least crash telemetry (MetricKit is
  unavailable on tvOS, so Sentry gets nothing), and iOS keeps its bugs.

This option only defers the work. Its useful part, tvOS first, fits inside (b).

### (b) Repository seam, dual backend, staged cutover (recommended)

Put a value-type repository in front of the store, move every caller onto it, implement it on
SwiftData, then flip platforms one at a time: tvOS first, iOS after.

- **iOS data path:** a launch migration (bootstrap task with a blocking progress screen), resumable
  and verified. Realm is left intact, but it supports rollback only until SwiftData accepts its
  first write (see Phase 4).
- **CloudKit:** the syncers talk to the repository, not to Realm. Record encoding is shared code,
  so both backends produce identical records.
- **Cost:** the largest total, but split into shippable phases. The first phase pays off before
  SwiftData exists.
- **Risks:**
  - Dual-backend drift while both exist. Mitigation: one contract test suite runs against both
    backends.
  - SwiftData on iOS 17 maturity (see Risks).

### (c) Full cutover in one release

Replace Realm everywhere and migrate in one release.

- **iOS data path:** one migration on the update launch, with no fallback store kept in sync
  afterwards.
- **CloudKit:** same record constraint. Mixed-version fleets are unavoidable, because users update
  at different times.
- **Cost:** one huge release (~200 files plus the migrator). It blocks unrelated work and is hard
  to review.
- **Risks:** every regression lands at once, with no rollback without shipping Realm again. This
  is the highest data-loss exposure for real iOS users. Not recommended.

### Alternatives worth one line

GRDB, or Point-Free's SQLiteData (GRDB plus CloudKit `SyncEngine`), gives value-type rows that are
`Sendable` by construction, which removes thread confinement entirely. The repository seam in
Phase 1 keeps the backend choice open. If SwiftData on iOS 17 proves too rough in Phase 3, swap the
backend behind the same seam.

## 4. Recommendation: (b), tvOS flips first

### Phase 0: stop the bleeding

- **Gate the importer dual-write.** Wrap the four `GameImporterSwiftDataBridge` call sites behind a
  new `PVFeatureFlags` flag, default off. On launch, delete the stale partial store
  (`Application Support/default.store*`).
  - The real migration will build its store from Realm, so nothing in the old store is worth
    keeping.
  - Use the full path, so nothing else's `default.store` is touched.
- **Delete the unreachable CloudKit SwiftData files** (`CloudKitSwiftDataSyncManager`,
  `SwiftDataSyncActor`, `SwiftDataLocalSyncMonitor`, `CloudKitModelContainerConfiguration`) and the
  false "always on" comment in `CloudKitSchema.swift`.
- **Fix the known escape candidates:**
  - The `RomDatabase.sharedInstance.game(withMD5:)` calls in async syncer code.
  - `TVMediaGameActions` freezing inside the Task.
  - The `ContinueItemModel.resolver` live return.
- **Add a CI audit** (`Scripts/audits/`, registered in `jobs.toml`) that counts `Realm(` opens and
  `RomDatabase.sharedInstance` in PVUI and fails when the count rises. It is a ratchet, so the
  number only falls from here.

Done when: no SwiftData store is created at runtime (verify on device: no `default.store` after an
import), the audit is in CI, and the listed call sites return values or frozen objects.

Test: a unit test that the bridge is inert with the flag off. Re-run the two crash repros: a
background CloudKit launch, and tvOS booting into a system screen.

### Phase 1: value-type repository seam (Realm underneath)

Add `LibraryStore`, an actor in PVLibrary, plus `Sendable` value types:

- `GameRecord`, `SystemRecord`, `SaveStateRecord`, `CoreRecord`, `BIOSRecord`, `PatchRecord`,
  `CheatRecord`, `ControllerProfileRecord`, `RecentPlayRecord`.
- Reads return values. Writes take values or keys.
- Change streams come as `AsyncStream`, built on Realm notifications for now.

Move callers module by module, smallest first:

1. Extensions (Spotlight and File Provider move to snapshot or `LibraryStore` reads).
2. tvOS Media UI.
3. CloudKit syncers.
4. Importer and artwork queue.
5. GameRekey and LibraryPathRemapper.
6. The rest of PVUI.
7. Replace RxRealm with `AsyncStream`/Combine along the way.

The #2776 batch API goes here.

Done when: no file outside `PVLibrary/Sources/PVRealm` and a `RealmLibraryStore` implementation
imports RealmSwift, and the CI audit reads zero.

Test:

- A `LibraryStoreContract` XCTest suite exercises every repository operation against
  `RealmLibraryStore` on an in-memory Realm. Phase 3 reuses it.
- Strict concurrency is on for PVLibrary's new files, so `Sendable` crossings fail at compile time.
- The PVUI unit suites keep passing (`PVUI-UnitTests`).
- The PVLibrary baseline is not green today (`804920129d`: 14 failures and a Realm-thread crash in
  `SaveExporterTests`). Record that baseline first and require "no new failures". Fix the
  thread-crash test early, since it is this bug class.

Cost: the bulk of the work, roughly 15–25 PRs. Each PR is independently shippable and reduces crash
exposure on its own.

### Phase 2: SwiftData schema v1 = Realm v29

Rebuild `*_Data` as a `VersionedSchema` (`SchemaV1`) with a `SchemaMigrationPlan`.

- **Models:** all 14 types, including `Patch_Data`, `ControllerProfile_Data`, controller mappings
  stored as a `Codable` value array, every v24–v29 field, `relativeRoot` and `sizeCache`.
- **Keys:** `md5Hash` unique, as the domain key, and `id` indexed but **not unique**, so
  GameRekey can re-key in place. `BIOS_Data` is unique on `expectedFilename` only.
- **No CloudKit configuration.**
- **Store location:** the App Group, at the same root `RomDatabase` uses (tvOS: Caches), via an
  explicit `ModelConfiguration(url:)`.
- **Housekeeping:** add the `.store` file names to `LibraryMove*` exclusions and to backup/restore.
- **Decision for the maintainer:** the iOS 17 floor means no `#Unique`/`#Index` macros and no
  history API. Either accept that or raise the minimum to iOS/tvOS 18 for the cutover release.

Done when: the schema builds on iOS and tvOS, and one model test per type round-trips every field.

Test: the CRUD tests rewritten against the new models in in-memory containers, plus a schema
snapshot test that fails when a Realm property has no SwiftData counterpart (reflection over
`objectSchema`).

### Phase 3: `SwiftDataLibraryStore`

Implement `LibraryStore` over a `@ModelActor`:

- one actor owns all writes;
- reads map to records inside the actor, so no `@Model` leaves it;
- change streams come from `ModelContext.didSave` notifications, plus history on iOS 18 if the
  minimum is raised.

Reuse what is useful from the existing `SwiftDataDatabaseDriver` and migration code.

Done when: the full `LibraryStoreContract` suite passes on both backends.

Test:

- The contract suite, parameterized over both stores.
- A CKRecord encode-parity test: the same fixture through each store must produce identical ROM,
  SaveState and BIOS records.
- Benchmarks at 500 and 5,000 games for library load, search and import batch, Realm vs SwiftData.

### Phase 4: Realm v29 → SwiftData migrator

Run it as a bootstrap task before library setup, with a blocking progress screen, as discussed on
#2510.

- Batched and resumable: a per-phase checkpoint in UserDefaults, and an idempotent upsert keyed by
  domain key.
- Validates counts and spot-checks fields per type.
- Leaves `default.realm` untouched.
- A `librarySchemaBackend` setting says which store is live. On failure the app stays on Realm,
  logs to Sentry, and retries next launch.
- **Rollback window.** Once an install is on SwiftData, every write goes there, so the retained
  Realm goes stale with the first import, save, favorite, patch or profile change. There is no
  reverse migration and no dual-write after cutover. Rollback is therefore limited:
  - **Before SwiftData's first write:** the backend flag can safely point back to Realm.
  - **After that:** the flag is ignored, and recovery means fixing forward on SwiftData. CloudKit
    restores synced games, saves and BIOS. Local-only changes made since the cutover would be lost
    by a revert, which is why the flag refuses one.
  - The store records a `firstWriteAt` marker so the flag can tell which side of that line an
    install is on.
  - A reverse copy (SwiftData → Realm) is out of scope. If Phase 5 shows it is needed, it reuses
    the contract suite and the field mapping, in the other direction.

Done when: a committed v29 `default.realm` fixture (systems, games with related files and artwork,
saves, cheats, patches with a variant, controller profiles, recents, a rekeyed game) migrates with
count and field parity, and an interrupted migration resumes to the same result.

Test:

- The fixture test.
- Kill-and-resume at every phase boundary.
- A 5,000-game synthetic Realm for time and peak memory, on device.
- **A background-suspend test with the store in the App Group:** SQLite there is a known
  0xdead10cc trigger, and 3.4.0 already has unexplained 0xdead10cc kills (crash-triage notes,
  2026-10-23).

### Phase 5: flip tvOS (TestFlight)

Set the tvOS default backend to SwiftData. iOS stays on Realm, and the two sync through the
unchanged CloudKit records.

Done when: two TestFlight builds pass with no store-related crashes on the tvOS device fleet, a
mixed pair (iPhone on Realm, Apple TV on SwiftData) round-trips a game, a save state and a BIOS
through CloudKit, and Top Shelf and the snapshot still update.

Test:

- On-device `.ips` pulls (`devicectl`), since MetricKit and Sentry receive nothing from tvOS.
- The dev harness on the tvOS simulator.
- A manual CloudKit mixed-pair checklist.

### Phase 6: flip iOS

Ship behind the backend flag, defaulting to SwiftData for new installs first and then for migrated
installs.

Done when: one App Store release is on SwiftData with the migrator's success rate visible in Sentry
logs, and no rise in crash-free sessions lost to store errors.

Test: an upgrade test from the last 3.3.x and 3.4.x builds on device (Lite excluded, per release
scope), plus the Phase 4 suite on CI.

### Phase 7: remove Realm

- Delete `default.realm` per install, never by release count. An install deletes it only when all
  three hold:
  - its own migration finished and verified (the Phase 4 checkpoint says complete);
  - `librarySchemaBackend` is SwiftData;
  - it has run on SwiftData for at least two releases.

  An install whose migration failed, or that skipped releases, still has an authoritative Realm,
  and it keeps that file.
- Then drop `PVRealm`, RealmSwift, RxRealm, `Packages/RxRealm` and `RealmLibraryStore`.
- Keep the migrator, and RealmSwift with it, until telemetry shows no Realm-only installs
  launching.
- When the migrator is removed, a launch that finds an unmigrated `default.realm` must not delete
  it. It moves the file to `Backups/`, imports the library by rescanning the ROM folders, and tells
  the user that saves and metadata come back from iCloud or from that backup. That keeps a
  supported path for users who upgrade straight from a Realm-only version.

Done when: there is no RealmSwift in `Package.resolved`, and the app's size delta is recorded.

## 5. Risks

| Risk | Where it bites | Mitigation |
|---|---|---|
| Thread confinement persists in a new form (`@Model` used outside its context) | Every phase | Records only past the actor (Phase 1 rule); strict concurrency; no `@Query` in views until the store is the source of truth. If `@Query` is adopted later, it is for main-context reads only. |
| Frozen-object semantics have no SwiftData equivalent | Code that passes frozen `PVGame` around (174 sites) | Phase 1 replaces frozen objects with records, so there is nothing to port |
| SwiftData iOS 17 bugs: `@ModelActor` running on the main thread when created there, missed merges into the main context, predicate limits on optional relationships | Phases 3–6 | Create the actor off main; make the change streams tolerate missed merges; contract tests on the iOS 17 simulator; consider an iOS 18 floor |
| CloudKit split-brain between versions | Phases 5–6 | Unchanged record schema; encode-parity test; no `NSPersistentCloudKitContainer` |
| 0xdead10cc from SQLite in the App Group during suspension | Phase 4 onward | Background-suspend test; end write transactions before `sceneDidEnterBackground`; keep extensions on snapshots, not the store |
| Primary-key change (GameRekey) | Phases 2–3 | `md5Hash` unique and `id` not unique; rekey test in the contract suite |
| tvOS storage is purgeable | Phase 5 | Same exposure as Realm in Caches today; rescan fallback; CloudKit restore |
| Dual-backend drift | Phases 1–6 | One contract suite, and the schema snapshot test |
| Migration data loss | Phases 4 and 7 | Realm left intact; resumable; verified; rollback only before SwiftData's first write; Realm deleted only after that install's verified migration |

## 6. Open decisions for the maintainer

1. Raise the minimum to iOS/tvOS 18 for the cutover release (to get history, `#Unique`, `#Index`,
   and fewer SwiftData bugs), or stay on 17.
2. SwiftData vs SQLiteData/GRDB behind the Phase 1 seam. Phase 1 doesn't depend on this.
3. Whether tvOS TestFlight users get the migrator or a rescan. The migrator costs nothing extra
   once Phase 4 exists.
