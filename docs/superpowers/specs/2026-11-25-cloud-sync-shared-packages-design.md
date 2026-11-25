# Moving Provenance's CloudKit sync onto PVSyncRules and PVCloudSync

Date: 2026-11-25. Status: scope approved by the owner on 2026-11-25 ("move partly");
decisions 2 to 9 in section 9 are still open.
No sync code has been changed. Nothing here should land before 3.4.0 ships.

Line numbers are from `develop` at `1592e26faa`, PVSyncRules 1.0.4, PVCloudSync 1.1.1
and iCube at `aa9ff9ac13`. `CS` means `PVLibrary/Sources/PVLibrary/Cloud Sync`, and
`CK` means `CS/iCloud/CloudKit`.

## 1. Recommendation

**Move partly, in four steps, and only after the packages change.**

- **Do not move ROMs, BIOS, save states or game metadata.** They are keyed by Realm
  rows and MD5, carry metadata fields, download on demand and are tied to Provenance
  Plus. PVCloudSync mirrors a folder of small files and has none of that.
- **Move the plain files** (battery saves, screenshots, skins) onto PVCloudSync. This
  is where Provenance's own code is weakest: a newer remote copy overwrites the local
  file with no check, a remote delete is never applied, and there are no tests.
- **Adopting PVSyncRules for classification only is rejected as the first step.** The
  package as released describes Dolphin's `User/` folder and nothing else (section 4.1).
- **The first step that can ship alone** uses two parts of PVCloudSync 1.1.1 that need
  no classifier: `SyncTrash` and `SyncRetryPolicy`. It changes no CloudKit record, so
  old and new app versions keep working together (section 7, step 1).

## 2. What Provenance does today

### 2.1 Container, database, zone

| Item | Today | Evidence |
|---|---|---|
| Container | `iCloud.org.provenance-emu.provenance` (`.dev` in Debug), or the first `NSUbiquitousContainers` key | `CS/iCloud/iCloudConstants.swift:12-32` |
| Database | Private only. The "public database" comment in the schema header is wrong | `CK/CloudKitSyncer.swift:166`, `CK/CloudKitRomsSyncer.swift:109` |
| Zone | Default zone. No custom zone is created | `CK/CloudKitRomsSyncer.swift:306` |
| Change tokens | One, for ROMs, in `UserDefaults`. Its only caller is unwired code. Everything else queries | `CK/CloudKitRomsSyncer.swift:68-69,470-476` |
| Subscriptions | Three separate systems create query subscriptions with different IDs | `CK/CloudKitSubscriptionManager.swift:170-296`, `CK/CloudKitNotificationManager.swift:206`, `CK/CloudKitSyncer.swift:610` |

### 2.2 Record types and record names

| Kind | Record type | Record name | Syncer |
|---|---|---|---|
| ROM, plus its metadata and play stats | `ROM` | `rom_<MD5>` | `CloudKitRomsSyncer` |
| Save state, screenshot, JSON sidecar | `SaveState` | `savestate_<GAME MD5>_<file name with . as _>` | `CloudKitSaveStatesSyncer` |
| Battery saves, screenshots, skins (iOS) | `File` | `<directory>_<path with / as _>`, plus `_<first 4 MD5 bytes>` under 50 MB | `CloudKitNonDatabaseSyncer` on `CloudKitSyncer` |
| BIOS, and `System/{PSP,DC,AtariST,Saturn}` | `BIOS` | Same generic form. Three older forms are still read | `CloudKitBIOSSyncer` |
| Settings | none | iCloud key-value store, not CloudKit records | `PVSettings` `iCloudSettingsSync` |

Sources: `CK/CloudKitSchema.swift:24-30,252,263`, `CK/CloudKitSyncer.swift:1708-1717`,
`CS/iCloud/CloudSyncManager.swift:1552-1557`, `CS/DeltaSkinSyncSupport.swift:11-25`,
`CS/iCloud/iCloud Drive/iCloudDriveBIOSSyncer.swift:378`.

- There is no schema version field. The schema is created by saving records
  (`CK/CloudKitSchema.swift:196-205`).
- A multi-file game uploads as one zip with `isArchive` set
  (`CK/CloudKitRomsSyncer.swift:937-968`).
- The `File` record name includes a hash of the content, so an edited file no longer
  matches its own name and the lookup falls back to a query
  (`CK/CloudKitSyncer.swift:1920-1960`).
- Cheat files are not synced by the live path: the manager passes its own directory
  list without `Cheats`.

### 2.3 Conflicts and deletions

| Kind | Conflict rule | Local delete | Remote delete |
|---|---|---|---|
| ROM | Local fields are copied over the server record. No date check (`CK/CloudKitRomsSyncer.swift:3103-3120`) | Soft delete: `isDeleted = true` (`:1049-1075`) | The local game is deleted through `RomDatabase.delete` (`:1446-1470`) |
| Save state | Newer date wins, 1 s tolerance (`CK/CloudKitSaveStatesSyncer.swift:1465-1515`) | Record deleted | Applied only when every fetch says the record is gone (`:1395-1432`) |
| Plain file | Upload skipped unless local is newer. A remote change deletes and replaces the local file (`CK/CloudKitNonDatabaseSyncer.swift:567-571`) | Record deleted | Only logged. The local file stays (`:587`) |

- `CloudKitConflictResolver` has no callers.
- Nothing sets `isDeleted` back to false, and uploads skip a record that has it
  (`CK/CloudKitRomsSyncer.swift:855-859`). A ROM deleted once and imported again
  stays deleted in iCloud.
- No rule limits how many games one sync may delete.
- The losing copy of any conflict is overwritten. Nothing is kept.

### 2.4 Retry

`CloudKitRetryStrategy` retries six error codes three times, using the server's
retry-after value or a fixed delay (`CK/CloudKitRetryStrategy.swift:14-55`). A full
iCloud account is reported and nothing else happens.

### 2.5 On-demand download

- Realm holds the state: `cloudRecordID`, `isDownloaded` and `hasCloudAssets` on
  `PVGame`, and the first two on `PVSaveState` and `PVBIOS`. `GameFileStatusService`
  is the only writer of `isDownloaded`.
- A ROM downloads when the game is launched, through `CloudKitDownloadQueue`
  (`PVUI/.../PVEmulatorViewController.swift:1712-1760`).
- Battery saves download at launch (`SceneCoordinator.downloadBatterySavesIfNeeded`).
- BIOS downloads on demand (`CK/CloudKitSyncer.swift:1470`).
- Apple TV never downloads ROMs by itself and defaults to metadata only.

### 2.6 Gating

- `Defaults[.iCloudSync]` is off by default on iOS and on by default on Apple TV.
- `Defaults[.iCloudSyncMode]` is CloudKit by default. The older iCloud Drive mode is
  still selectable on iOS and its code is live.
- Lite never syncs.
- Provenance Plus limits one thing: without it, an App Store iOS build syncs metadata
  and saves but does not move ROM files automatically
  (`PVSettings/.../CloudSyncContentAccess.swift:17-29`).

### 2.7 Where "what is this file" is decided

Eight places, with no shared rule: `CS/DeltaSkinSyncSupport.swift:11-25`,
`CK/CloudKitNonDatabaseSyncer.swift:62-77,202-212`,
`CS/iCloud/CloudSyncManager.swift:1552-1557`, `CK/CloudKitInitialSyncer.swift:931-934`,
`iCloudDriveBIOSSyncer.swift:378`, `CK/CloudKitSyncer.swift:1976-1998` (two functions),
and the zip packaging in `CloudKitRomsSyncer`.

Two of them disagree. `getRecordType` looks for a folder named `Save States` while the
save syncer uses `Saves`. The initial syncer excludes `DolphinData`, which the plain
file syncer includes on purpose.

### 2.8 Tests

Tests cover the task queue, the progress tracker, skin extensions and fetch keys.
Nothing tests record names, conflicts, deletions, retry, the initial sync or the plain
file syncer.

### 2.9 Faults found while reading

These exist today and are separate from the move. Each needs a test before it is
called confirmed.

1. A save-state record name turns `.` into `_`, and reading it back turns every `_`
   into `.` (`CK/CloudKitSchema.swift:263,313-316`). A file name containing an
   underscore does not survive, so a remote delete of that state is not applied.
2. Plain files upload with fields `filename` and `fileData`, and download reading
   `relativePath` and `fileAsset`, falling back to parsing the record name
   (`CK/CloudKitNonDatabaseSyncer.swift:20-28,536,575-600`).
3. `forceSyncFiles` keys records by file name alone (`:361-366`), so two games with
   `save.sav` in different folders collide.
4. The SwiftData CloudKit layer (`CloudKitSwiftDataSyncManager`,
   `SwiftDataLocalSyncMonitor`, `SwiftDataSyncActor`) has no callers.

## 3. What the packages do

### 3.1 PVSyncRules 1.0.4

Three value types, no I/O.

- `SyncClassifier.classify(relativePath:)` is an allow-list over **Dolphin's `User/`
  folder**: `StateSaves/`, `GC/`, `GBA/Saves/`, `Wii/`, `Config/*.ini`,
  `GameSettings/*.ini`, `Profiles/*.json`, `Skins/`. Anything else returns nil.
- It refuses disc images by extension and the `Software/` folder outright. The file's
  own comment says games belong elsewhere.
- `SyncableFileType` is a `@frozen` enum of 16 kinds, among them `gameCubeMemoryCard`,
  `wiiSave`, `wiiChannel`, `wiiSystem`, `firmware`. Each kind carries its size cap,
  merge kind and whether deletes travel.
- `SyncPolicy` holds four switches: firmware, Wii channels, full Wii NAND, large files
  on Wi-Fi only.

### 3.2 PVCloudSync 1.1.1

| Part | What it does |
|---|---|
| `CloudSyncConfiguration` | Container, zone name, record type and timings, passed in by the app |
| `CloudKitSyncProvider` | Private database, one custom zone, one record type. Record name is the file's relative path. Every payload is a `CKAsset`. Reads the whole zone with a zone-changes fetch on each run |
| `UserDataScanner` | Walks one root folder, classifies through `SyncClassifier`, hashes with SHA-256, caches hashes by size and date |
| `SyncPlanner` | Pure function from local list, remote list and index to steps: upload, download, merge, conflict, write tombstone, move to trash, restore |
| `SyncIndexStore` | JSON record of what this device last synced, bound to one iCloud account |
| `SyncTombstone` | A delete is the same record with its asset removed, `deleted = 1` and the checksum of the deleted content. Kept 90 days |
| `SyncTrash` | Every local removal is a move into a dated folder, kept 30 days, restorable |
| `TimestampConflictResolver` | Newer wins outside a tolerance window. Inside it, the user is asked |
| `DocumentMerger` | Field-by-field merge for JSON documents such as favorites and play stats |
| `SyncRetryPolicy` | Pure retry decision. Honours the server's retry-after, separate budgets for throttling and for network loss |
| `SyncLifecyclePolicy` | Pure state machine. No sync while a game runs, an in-flight run is aborted when a game starts, deferred work runs when the game stops |
| `PVLibraryMetadata` (second product) | Per-game custom titles, covers and tags as small merged documents |

A peer deletes its copy only when the bytes it holds are the bytes that were deleted.
A local change made after the delete wins and the file is uploaded again.

### 3.3 How iCube uses them

- `ICubeCloudSync.swift` is eleven lines: container `iCloud.com.joemattiello.iCube`,
  zone `iCubeUserData`, record type `iCubeUserFile`.
- The run loop is **not** in the package. `CloudSyncCoordinator.swift` (1,289 lines)
  holds it: lifecycle events, watchers, the run itself, conflicts, trash, account
  changes, statistics. Push handling is another 417 lines, and the settings screens
  about 740.
- On Apple TV iCube does not infer deletes from missing files, because a cache purge
  looks the same as the user deleting a save (`CloudSyncCoordinator.swift:533-534`).
- iCube filters some whole files out on top of the classifier (credentials,
  `Logger.ini`) in the coordinator (`:72-81`).

## 4. Comparison

### 4.1 Why classification alone cannot be the first step

`SyncClassifier` is a static function over Dolphin paths. None of Provenance's
folders (`Battery States/`, `Saves/`, `Screenshots/`, `DeltaSkins/`, `BIOS/`,
`ROMs/`) match one rule in it; every Provenance path classifies as nil. The enum of
kinds is `@frozen`, so adding Provenance's kinds changes the binary interface of a
package that ships as an XCFramework. PVCloudSync calls the static function directly
in its provider, scanner and planner, so a second classifier cannot be handed in today.

### 4.2 What PVCloudSync has that Provenance lacks

- Tombstones that carry the deleted content's checksum, with an expiry.
- A local trash. Provenance overwrites and deletes in place.
- A device index, so "deleted here" and "never had it" are told apart.
- Content checksums. Provenance compares dates only.
- A conflict the user can settle, with a keep-both choice.
- Sync held off while a game runs.
- Account binding, so signing in as someone else cannot apply the previous account's
  deletes.
- Tests on every rule above.

### 4.3 What Provenance has that PVCloudSync lacks

| Provenance needs | PVCloudSync 1.1.1 |
|---|---|
| ROM sync keyed by MD5, with a zip for multi-file games | Refuses games by design |
| Metadata fields on a record (favorite, rating, play time) | One asset per record, no extra fields |
| On-demand download with a "cloud only" state per game | Downloads everything the plan lists |
| Files of several gigabytes | Reads each file into memory (`UserDataScanner.swift:124,137`, `CloudKitSyncProvider.swift:290`). The default cap is 64 MB |
| Realm rows that must change with the file | Knows files only |
| Plus limiting ROM transfers | Category switches only |
| Thousands of records | Fetches the whole zone each run. The change token is thrown away (`CloudKitSyncProvider.swift:121-124`) |
| File names with any characters | Record name is the raw path. CloudKit record names must be ASCII and at most 255 characters, and ROM-named saves break both |
| Several roots (library folder and saves folder can differ) | One root |
| A run loop | In the app. iCube's is 1,289 lines |

### 4.4 What has to be added to the packages first

1. **PVSyncRules 2.0: a classifier the app supplies.** A protocol for "classify this
   path", with iCube's rules as one implementation. Kinds become open (a string-backed
   struct with per-kind traits) so each app adds its own. This is a breaking release.
2. **PVCloudSync 2.0: take the classifier as a value.** Provider, scanner and planner
   receive it instead of calling the static function.
3. **Record names that are safe for any path.** Keep the path in `fileName` and derive
   the record name from it, behind a configuration option that defaults to today's
   behaviour so iCube's records stay valid.
4. **File-to-file transfer.** Upload from a URL and download to a URL, so nothing is
   held in memory.
5. **Delta fetch.** Keep the zone change token, with the full fetch as the fallback.
6. **More than one root.**
7. **A shared run loop.** Lift the app-neutral part of iCube's coordinator into the
   package, or Provenance and iFly each write a third and fourth copy.

Items 1 to 3 are required before Provenance can use the engine at all. Items 4 to 6
are required before screenshots and skins move. Item 7 is a saving, not a blocker.

Type names also clash: `SyncProvider` and `SyncStatus` exist in both PVLibrary and
PVCloudSync. One adapter file may import the package, the same rule PVPatching follows
for PVPatchEngine.

## 5. What stays on Provenance's own code, and why

| Kind | Decision | Reason |
|---|---|---|
| ROMs | Stay | MD5 identity, zip packaging, on demand, Plus, size |
| BIOS | Stay | On demand, tied to `PVBIOS` rows. Copyrighted firmware also needs its own opt-in decision |
| Save states | Stay for now | Tied to `PVSaveState` rows, with the screenshot and sidecar on the same record. Revisit after step 3 |
| Favorites, rating, play stats | Stay on the ROM record for now | `PVLibraryMetadata` and `DocumentMerger` would do this better, but it is a separate design |
| Battery saves | Move | Small whole files, the most valuable user data, the weakest code |
| Screenshots | Move | Whole files. Many of them, so this needs delta fetch |
| Delta skins | Move | Whole files up to tens of megabytes. Needs file-to-file transfer |
| Settings | Stay | Already on the key-value store |

## 6. Rules the migration must keep

1. **No existing record is modified or deleted by the new code.** The old records in
   the default zone are read, never written.
2. **New records go to a new custom zone** in the same container, for example zone
   `ProvenanceUserData` and record type `ProvenanceUserFile`. Old app versions never
   look there, so they cannot misread a tombstone.
3. **The first run on any device is additive.** With no index the planner uploads and
   downloads and never deletes. This is the package's existing behaviour.
4. **Apple TV never infers a delete from a missing file.** Its library is in Caches
   and can be purged. Only an explicit tombstone from another device applies there.
5. **Nothing is unlinked.** Every local removal and every overwrite goes through the
   trash.
6. **The production CloudKit schema is deployed before the build ships.** Production
   does not create a record type from a save. The new type and its ten fields have to
   be promoted in the CloudKit dashboard by the owner.
7. **Each step is behind a flag that is off by default** until it has run on the
   owner's devices against real data.

## 7. Steps

### Step 1. Trash and retry (ships alone, no package change)

- Depend on PVCloudSync 1.1.1 from PVLibrary through one adapter file.
- Before `CloudKitNonDatabaseSyncer` replaces a local file with a remote copy, move
  the local file into a `SyncTrash` outside the library folders.
- Before a remote ROM soft delete removes a local game, move its battery saves and
  save-state files into the same trash.
- Add a Recently Deleted list to the iCloud settings screen, with restore.
- Replace `CloudKitRetryStrategy`'s decision with `SyncRetryPolicy`.
- Add tests for today's record names (section 2.2) so later steps cannot change them
  by accident, and tests for faults 1 to 3 in section 2.9.

Record layout: unchanged. Old and new versions: fully compatible. Risk: disk use from
the trash, bounded by the 30-day purge.

`SyncTrash` and `SyncRetryPolicy` do not reference the classifier
(no `PVSyncRules` symbol in either file), which is why this works with 1.1.1.

### Step 2. Package releases 2.0 (no Provenance change)

Items 1 to 3 of section 4.4, released for all three apps together. iCube moves to 2.0
with its rules unchanged and its record names unchanged. Provenance bumps the pin and
still uses only the trash and retry policy.

### Step 3. One classifier in Provenance (no record change)

- Write `ProvenanceSyncClassifier` against the 2.0 protocol, with Provenance's kinds:
  battery save, screenshot, skin, save state, save-state screenshot, save-state
  sidecar, BIOS, ROM.
- Point the eight places in section 2.7 at it. The existing syncers keep their record
  types and names.
- Settle the two disagreements in section 2.7 with tests.

This is the "classification only" step, possible once step 2 exists.

### Step 4. Battery saves on the new engine

- New zone and record type (rule 2). Scanner root is the saves root; kinds limited to
  battery saves at first.
- **Import, once per device:** list the old `File` records for `Battery States`.
  Download any whose file is missing locally. Change nothing remotely.
- **Then run the new engine.** With no index it uploads what is local and downloads
  what is only in the new zone.
- **Bridge for older versions:** keep the old uploader running for battery saves, so a
  device on 3.4.x still receives new saves. The old *download* path is limited to
  files missing locally, which removes the unconditional overwrite.
- Deletes travel only in the new zone. An old device still holding a deleted save will
  upload it to the old zone, where the new engine ignores it after the import is done.
- The bridge is removed in a later release, when the owner decides old versions no
  longer need new saves (decision 4).

Screenshots and skins follow in the same way once items 4 and 5 of section 4.4 exist.

### What can go wrong at step 4, and the answer

| Case | Result |
|---|---|
| Two devices import the same old records | Same paths, same bytes: the planner marks them synced |
| Old device overwrites a newer save in the old zone | The new engine does not read the old zone after import. The newer save stays in the new zone |
| Old device has an older save, new device a newer one | Old device keeps receiving through the bridge upload. The newer one is not lost |
| User deletes a save on a new device | Tombstone in the new zone. Old devices keep their copy and may re-upload it to the old zone only |
| Apple TV cache purge | No tombstone (rule 4). The next run downloads the saves again |
| Different iCloud account signs in | Index is wiped for the new account. One additive run |
| Plus lapses | No effect. Saves sync without Plus today and that stays |
| Sync mode is iCloud Drive | Not covered. See decision 5 |

## 8. Cost

- Step 1: small. One adapter, two call sites, one settings list, tests.
- Step 2: medium, in the package repos, and it touches iCube and iFly.
- Step 3: small to medium, all inside PVLibrary.
- Step 4: large. A Provenance run loop (or the shared one from item 7), the import,
  the bridge, settings screens for conflicts, and a device test pass on iPhone and
  Apple TV with a real library.

About 1,500 lines of Provenance's 27,000 lines of sync code would go at the end of
step 4 (`CloudKitNonDatabaseSyncer` and part of `CloudKitSyncer`). The ROM, save-state
and BIOS syncers remain. The move is justified by safer saves, not by less code.

## 9. Decisions for the owner

1. **Scope.** Decided 2026-11-25: move partly. Plain files move; ROMs, BIOS, save
   states and game metadata stay.
2. **Step 1 timing.** Ship trash and retry in the first release after 3.4.0?
3. **Package 2.0.** Approve a breaking release of PVSyncRules and PVCloudSync that
   makes the classifier and the kinds app-supplied, with iCube and iFly bumped in the
   same pass.
4. **Bridge length.** How many releases keep uploading battery saves to the old zone
   for devices that have not updated.
5. **iCloud Drive mode.** Keep it as is, or retire it before step 4. Step 4 does not
   cover it.
6. **Shared run loop.** Lift iCube's coordinator into PVCloudSync (item 7), or let
   Provenance write its own.
7. **Zone and record type names.** `ProvenanceUserData` and `ProvenanceUserFile` are
   placeholders. They can never change after the first build ships.
8. **Faults in section 2.9.** Fix them in place now, or leave them until the code
   around them is replaced. Fault 1 affects save states, which are not moving.
9. **Dead code.** Remove `CloudKitConflictResolver` and the unwired SwiftData sync
   layer, or keep them for the SwiftData migration.

## 10. Not checked

- The 255-character ASCII limit on CloudKit record names is from Apple's
  documentation as remembered, not from a test. Check it against a real container
  before item 3 of section 4.4 is designed.
- Faults 2 and 3 in section 2.9 were read in the code and not reproduced.
- How a different iCloud account signing in is handled by today's code was not
  determined.
- iFly's sync was not read. PVCloudSync's comments say its shape came from iFly.
- Nothing in this document has been run.
