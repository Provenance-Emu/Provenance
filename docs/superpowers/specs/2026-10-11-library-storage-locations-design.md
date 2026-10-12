# Library storage locations: a user-picked folder, and moving between locations

**Date:** 2026-10-11
**Status:** Draft, for review before planning
**Scope:** iOS / iPadOS (and the Designed-for-iPad Mac build). tvOS keeps its current storage; it has no Files app or folder picker.

## Problem

ROMs, BIOS files and saves can live in three places today, chosen by settings that grew separately:

| Location | Chosen by | Root (`URL.documentsiCloudOrLocalPath` / `URL.documentsPath`) | Visible in Files.app |
|---|---|---|---|
| App Documents (default) | nothing | `<app>/Documents` | Yes, under On My iPhone › Provenance |
| App Group | `useAppGroups` (default off) | `<group container>/Documents` | No |
| iCloud Drive | `iCloudSync` + `iCloudSyncMode == .iCloudDrive` | the ubiquity container's `Documents` | Yes, under iCloud Drive › Provenance |

There are three problems with this:

1. **No sharing with our other apps.** Provenance, iCube and iFly each keep their own copy of a ROM. App groups can't fix that: they only span apps that share one group ID, and their files don't show in Files.app, which users dislike because they manage their files there, including the hidden settings files some cores write.
2. **Switching location is ad hoc.** `PVGameLibrary+Migration.oldPaths` moves six folders when `useAppGroups` flips. iCloud Drive mode just changes the root. Neither verifies the copy, survives being interrupted, or rewrites the database as one step.
3. **The library database follows its own rule.** The Realm database always lives in the app group, whatever `useAppGroups` says. That's how Lite came to share the full app's library while keeping its own files (fixed in `766c3605ac`: Lite now has its own `lite.realm`).

## Goal

The user picks exactly one location for library files, and can move between locations safely at any time:

- **App storage**: today's default.
- **iCloud Drive**: today's iCloud Drive mode.
- **A folder you choose (new)**: any folder in Files. Provenance, iCube and iFly can all point at the same folder and share ROMs and BIOS files without app groups, and the user keeps managing the files in Files.app.

App Group storage stops being offered. Existing App Group users keep it until they move, and it stays a valid source for a move.

Existing users see no change unless they choose a new location.

## How a user-picked folder works

iOS doesn't let an app change its own Documents folder. A user-picked folder works like this:

1. The app shows the folder picker (`UIDocumentPickerViewController(forOpeningContentTypes: [.folder])`).
2. The picker returns a URL with a temporary access grant (a security-scoped URL).
3. The app saves that grant to disk as a bookmark: `url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)`. On iOS no `.withSecurityScope` option is needed; that option is for macOS.
4. On every launch the app resolves the bookmark: `URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)`, then `startAccessingSecurityScopedResource()`. The grant lasts for the whole process, and emulator cores open files by path inside it.
5. If the bookmark comes back stale, the app saves a fresh one. If it no longer resolves, the app shows a re-pick prompt (see Failure handling).

Which folders work well:

| Picked folder | Works? | Notes |
|---|---|---|
| On My iPhone › Provenance › (any folder) | **Best.** | Local, fast, and survives other apps being deleted. This is the recommended default. |
| iCloud Drive › (any folder) | Yes | Files can be cloud-only placeholders. Download them before a core opens them (`startDownloadingUbiquitousItem` plus `NSFileCoordinator`); the importer needs to know about this. |
| On My iPhone › *another app* | Works, but warn | The folder disappears if that app is deleted. |
| Third-party providers (Dropbox, Drive, …) | Not supported for play | No reliable random access or in-place writes. Allow importing from them, not living there. |

## Which files move with the location

| Data | Follows the location | Why |
|---|---|---|
| ROMs (`ROMs/<system id>/…`) | Yes | This is what users want to share. |
| BIOS (`BIOS/`, `System/<console>/`) | Yes | Shared across apps; one copy. |
| Imports inbox (`Imports/`) | No | It's the app's own drop folder (the ecosystem fetch writes here). |
| Battery saves, save states, screenshots | **Option, off by default for a picked folder** | Save formats differ between Provenance's cores and iCube/iFly's cores. Sharing them by default would invite corrupted or mismatched loads. |
| Core config / hidden core files, cheats, patches, skins | No | Per app. They stay in Documents, which stays visible in Files.app. |
| Realm database | No, ever | It's per app and stays in the app group as today. |

When saves stay in the app, a picked folder holds only `ROMs/` and `BIOS/` (and `System/`), and the picked folder becomes a shared library.

## Folder layout contract (shared with iCube and iFly)

A shared folder needs a layout every app agrees on:

```
<picked folder>/
  .provenance-library.json   { "version": 1, "createdBy": "org.provenance-emu.provenance", ... }
  ROMs/<system id>/<file>    system ids are SystemIdentifier raw values (com.provenance.snes, …)
  BIOS/
  System/<console>/
```

- Each app reads and writes only the subfolders for the systems it supports, and ignores the rest.
- The manifest marks the folder as a library. Picking a folder that contains a manifest means "join this library": the app scans it without moving anything into it.
- iCube and iFly adopt the same contract before they ship. Neither is public yet, so the contract can still change.
- Notes added while building phases 3 and 4. They are additive; the layout itself is unchanged.
  1. Manifest JSON: `{"version":1,"createdBy":"<bundle id>","createdAt":"<ISO 8601>"}`. Readers ignore unknown keys, accept a missing `createdAt`, and treat a `version` above what they know as still joinable. Whoever creates the library writes it; nobody rewrites it.
  2. `Conflicts/` may appear at the root of a shared folder: Provenance's move engine files name clashes there (`Conflicts/ROMs/<system>/<name>`, `-2`, `-3` suffixes). Ignore it when scanning.
  3. Hidden temp files `.<name>.librarymove-partial` and `.provenance-write-probe-<uuid>` can appear briefly. Skip hidden files.
  4. `Save States/`, `Battery States/`, `Screenshots/`, `Cheats/`, `Patches/` may be present when the user opted to move saves. They are Provenance-core formats; ignore them.
  5. Provenance never deletes a file it did not copy into the folder, never deletes `ROMs/<system>/` folders of systems it does not know, and reads only the system folders it supports.

## Data model

*Revised 2026-10-11 while building phase 1. The first draft added a `library` value to `PVFile.relativeRoot` and migrated every record to it. That was dropped for two reasons:*
- *Records don't resolve by their root. `PVFile.url` sends the stored `partialPath` (`ROMs/com.provenance.snes/Game.sfc`) to `FileLocationResolver.bestURL(for:)`, which searches the storage roots. A move therefore needs no record rewrite.*
- *A new raw value would crash older builds. `relativeRoot` force-unwraps `RelativeRoot(rawValue:)`, so a TestFlight downgrade reading the new value would crash.*

- **`LibraryLocation` (PVFileSystem) is the one place that decides the library root.** It has three values: `.appStorage`, `.appGroup` (legacy), and `.iCloudDrive`. Phase 3 adds `.pickedFolder`.
  - `LibraryLocation.current.rootURL` backs `URL.documentsiCloudOrLocalPath`, so it also backs every `Paths` library accessor (`romsPath`, `biosesPath`, `saveSavesPath`, …).
- **Two roots, kept apart:**
  - The **app-files root** is `URL.documentsPath`: Imports, core configs, and the resolver's `localBaseURL`. It stays per app.
  - The **library root** is `LibraryLocation.current.rootURL`.
  - The two already differ today, for example with `useAppGroups` and iCloud Drive both on.
- **The location is stored since phase 2** as `Defaults[.libraryLocation]` (`LibraryLocation.rawValue`, `nil` until the first move). Precedence, in `LibraryLocation.resolve`: iCloud Drive (sync on + Drive mode, still derived from the iCloud settings until phase 5) → the stored value → the legacy `useAppGroups` toggle. The move engine's switch writes both the stored value and `useAppGroups`, so a build that only knows `useAppGroups` agrees after a downgrade.
  - The appGroup/appStorage axis, including `useAppGroups`, is snapshotted once per process (`storedAtLaunch`, `useAppGroupsAtLaunch`), and `URL.documentsPath` / `URL.cachesPath` follow the same value (`LibraryLocation.usesAppGroupContainer`), so the app-files root and the library root cannot disagree mid-session. A switch takes effect at the next launch; the UI tells the user to quit and reopen.
  - On tvOS the location is always `.appStorage` and the move engine is a no-op.
- **Phase 3 picked folder:** the bookmark is stored in the app's own defaults, not shared, along with a display name for the settings UI.

*Revised 2026-10-12 while building phases 3 and 4. What phase 3 and 4 settled:*

- **`LibraryLocation.pickedFolder`.** The fourth case, raw value `"pickedFolder"`. It is stored like the others in `Defaults[.libraryLocation]`; the folder itself is `Defaults[.libraryPickedFolder]`, the JSON of a `PickedLibraryFolder` (bookmark data, display name, `includesSaves`, `pickedAt`). Both are written only by `LibraryLocation.switchStored(to:pickedFolder:)`, which the engine calls at the switch. The bookmark lives in the app's own defaults, never the App Group.
- **Resolved once per launch.** `LibraryLocation.pickedFolderAtLaunch` resolves the bookmark, calls `startAccessingSecurityScopedResource()` and never stops it, because cores open files by path for the life of the process. A stale bookmark is saved again. A failure becomes `.unavailable(reason:)`: `rootURL` falls back to local Documents so nothing crashes, the resolver finds nothing for shared paths, and the UI shows the three-choice recovery (re-pick, App storage, try again). Nothing in the database is touched.
- **Saves split.** A picked folder holds `ROMs/`, `BIOS/` and `System/`. `Battery States/`, `Save States/`, `Screenshots/`, `Cheats/` and `Patches/` stay at the app-files root unless `includesSaves` is on. `LibraryLocation.savesRootURL` is the second root and `URL.savesRootPath` backs the five saves accessors in `Paths`. `LibraryLocation.root(forPartialPath:)` picks the root by the first path component, and the resolver searches the matching root, then the app-files root, and iCloud in Drive mode.
- **Supported moves.** App Group ⇄ App storage (phase 2), App storage → picked folder, picked folder → App storage, and picked folder → picked folder. App Group → picked folder is refused: leaving the group carries every top-level entry and only three of them belong in a shared folder, so the UI says "Move to App storage first". iCloud Drive mode refuses every picked-folder move until phase 5, and the UI disables "Choose a folder…" while it is on. Leaving a picked folder always keeps a copy, because the shared folder is left untouched. Moving from a picked folder carries the saves folders exactly when that folder `includesSaves`, and a new picked folder inherits the flag.
- **Nested roots.** `On My iPhone › Provenance › MyLib` is a subfolder of our own Documents, so the picked root can sit inside the App storage root. The engine allows that nesting unless the inner root is one of the moved top-level folders or inside one, and `LibraryFolderInspector` applies the same rule to the pick.
- **Journal version 2.** The journal gains optional `sourceFolder` and `destinationFolder` (so a resume after the switch can still resolve the old picked folder once the stored one has changed), `deduplicateByMD5` and `remaps`. A version 1 journal still decodes, and an older build leaves a version 2 journal alone.
- **Manifest at switch.** `LibraryManifest.writeIfAbsent(in:createdBy:)` runs when the destination is a picked folder: after the copy verified, before the setting is written, and never over an existing manifest. The format is `{"version":1,"createdBy":"<bundle id>","createdAt":"<ISO 8601>"}`; readers ignore unknown keys and accept a missing `createdAt`.
- **Join is a move with de-duplication.** A folder that already has a manifest is joined with de-duplication on. For each `ROMs/` or `BIOS/` source file with no file at its own path in the destination, the engine looks for a destination file of the same size and MD5 under any name. A hit is journaled as `deduplicated`, pointing at the shared path, with a `remaps` entry from the source path to it. Cleanup verifies the shared copy by size and deletes the source like an identical file. Before cleanup the coordinator hands `remaps` to a registered applier (`LibraryPathRemapper` in PVLibrary rewrites `PVFile.partialPath` and `PVGame.romPath`); with no applier, or if it throws, cleanup waits for a later launch so a record never points at a deleted file.
- **Folder kinds and the write probe.** iOS paths do not reveal whether a Files folder is On My iPhone or a third-party provider; both live under `File Provider Storage`. The inspector classifies `iCloudDrive` (`isUbiquitousItem` or `/Mobile Documents/`), `ownDocuments`, `otherAppDocuments` (`/Containers/Data/Application/`) and otherwise `filesFolder`, and refuses any folder where a hidden probe file cannot be created and deleted. `otherAppDocuments` gets the warning about the folder vanishing with its app in the confirmation sheet.
- **Rescans.** The existing "Scan ROM Directories" path already scans `Paths.romsPath`, which follows the picked folder. Phase 4 adds triggers: foreground (throttled to once per 60 seconds), a "Rescan Library" button in the storage view, and `NSMetadataQuery` updates for an iCloud-located picked folder, which also starts downloads of cloud-only files under the shared folders. After each rescan on a picked folder the file-status service marks missing files as not downloaded. Download progress in the game-launch gate is a follow-up.
- **Extensions.** Spotlight, TopShelf, widgets and the File Provider keep resolving against `URL.documentsPath` and never resolve the bookmark. Picked-folder games keep their metadata and artwork there and launch through the main app by id.

### Root computations not yet routed through `LibraryLocation` (phase 3 work)

- **`FileLocationResolver`** searches local, then iCloud Drive whenever the *mode* is iCloud Drive, even with iCloud sync off. It needs a picked-folder root in its search order.
- **`PVFile.realPath`** appends the partial path to the raw ubiquity container, without `/Documents`. Check its callers.
- **`PVFile.url`**'s special case for paths containing "iCloud" or "private".
- **`RelativeRoot.createRelativePath(fromURL:)`** pattern-matches `"Documents/"` and the like. A picked iCloud Drive folder (`…/Mobile Documents/com~apple~CloudDocs/MyLib/ROMs/x`) would match inside "Mobile Documents/" and store a wrong partial path. Before any pattern matching, strip the active library root. Today's outputs for Documents, App Group, iCloud and tvOS Caches URLs are pinned in `LibraryLocationTests`.
- **Other sites:**
  - `iCloudDriveSync`
  - `Container.documentsURL`
  - `LegacyFileMover` (compares `documentsPath` with the library root)
  - `GameFileStatusService`
  - `WidgetDataWriter+Realm`
  - `AppGroupFileBrowserView`
  - `CloudSyncStatusView`
  - `FeatureFlagsDebugView`

## Moving between locations

Use one move engine for every pair of locations, including leaving the App Group:

1. **Plan.** List the files that move. Check free space at the destination; for iCloud sources, count files that are only in the cloud and download them first.
2. **Copy.** Copy into the destination, verifying size (and MD5 for ROMs, which the library already has). The copy runs in the background with progress UI and can be resumed: write a journal file `move-journal.json` in Application Support listing what's done.
3. **Switch.** Set `libraryLocation` to the destination. Records keep their partial paths, so nothing in the database is rewritten; the library now resolves against the new root.
4. **Clean up.** Delete the source files only after a successful switch, and only files the journal recorded as copied. An option: "Keep a copy in the old location".
5. **Conflicts.** A destination file counts as identical only when its size **and** MD5 match, in every folder (fixed-size SRAM saves collide on size alone, and cleanup deletes the source of an identical file). If a different file already sits at the path, nothing is deleted or overwritten. During the copy phase the destination's own file is moved aside to `Conflicts/<relativePath>` (then `-2`, `-3`, … before the extension) and the live source file takes the real path, because every pre-existing destination file is one the app was not using. The journal records it (`displaced`, with the aside path), so cancelling before the switch puts the destination's file back. After the switch the destination is live, so the post-switch sweep keeps filing the incoming file under `Conflicts/` instead.
6. **Cleanup timing (phase 2 decision).** Because the location is fixed per process, cleanup runs on the launch after the switch, once the app is on the new root. A delta sweep first copies anything the old process wrote after its files were journaled: a source with no journal entry is copied normally, and a source whose size or modification time (even at the same size) differs from the journal goes to `Conflicts/` and is never treated as identical. Journal dates are stored exactly, so a same-size rewrite a fraction of a second after the copy is still caught. Then the journaled sources are deleted (only if their copy still verifies), emptied folders removed and the journal dropped. The journal lives at `<Application Support>/LibraryMove/move-journal.json` in the app's own container.

Safety rules the engine keeps:
- **What moves.** Leaving the App Group moves every top-level entry of the group's Documents except hidden files, names containing `.realm` and the journal. It is not a fixed folder list, so folders such as `Azahar` or `DeltaSkins` and loose files move too, including entries created after the move started: cleanup re-lists the group's top level and journals what is new. The Realm file is never part of a move.
- **Recovery never deletes a destination file the move didn't write.** Before each batch the engine records in the journal the destination paths it is about to create; on resume only an unjournaled file at one of those claimed paths (a torn copy of ours) is removed. A pre-existing destination file is only ever moved aside to `Conflicts/`.
- **A copy never leaves a partial file at a real path.** Each copy goes to a hidden `.name.librarymove-partial` file, is verified, then renamed into place; leftover temp files are swept at resume, cleanup and rollback. The planner throws instead of silently dropping a file it cannot read, so a switch never follows an incomplete plan.
- **Crash windows heal.** A copying journal whose launch is already on the destination (setting written, journal not) is finished; a switched journal on the source re-asserts the setting.
- **The location is not a debug flag.** "RESET TO DEFAULT" in the debug screen no longer touches `libraryLocation` or `useAppGroups`; only the engine changes the location.
- **Lite and the full app share the App Group.** Each app records its launch location in the group's shared defaults; while another app still uses the group, a move (and its cleanup) keeps a copy of the group's files.
- **Rollback is narrow.** Cancelling before the switch removes the files the move copied and only the directories it created, never a folder that already existed.

Joining an existing shared library (a folder that already has a manifest): copy only files that aren't already there, matched by MD5, then switch. Duplicates get de-duplicated against the shared copy.

Leaving a shared library for App storage copies the files back out, so the user gets their own copy, and the shared folder is left untouched.

## Failure handling

- **The bookmark won't resolve** (folder deleted, iCloud signed out, provider app deleted): the library shows "Library folder unavailable" with three choices: re-pick the folder, switch to App storage (the move is impossible, so start empty and rescan), or try again. Never delete any database records automatically.
- **iCloud file is only in the cloud at launch:** download it first and show progress. This reuses the on-demand download path that CloudKit ROMs use.
- **The move is interrupted** (app killed, low disk): resume from the journal on the next launch. Nothing is switched until every file is copied.
- **Another app changes the shared folder:** a rescan picks up added or removed files. A deleted ROM shows as missing, not as gone, so the user's library metadata and saves aren't lost.

## Watching the folder

`DirectoryWatcher` watches `Imports/`. A picked folder also needs change detection, because iCube or iFly may add files:

- **Local folder:** rescan on launch and on foreground, plus a "Rescan library" button.
- **iCloud Drive folder:** `NSMetadataQuery` scoped to it, as iCloud Drive mode does today.

## Settings UI

Settings › Library › Storage location:

- Shows the current location and its path or display name.
- Offers the choices: App storage, iCloud Drive, "Choose a folder…". "Choose a folder…" opens the picker, then a confirmation sheet showing what will move, the space it needs, and the option to also move saves.
- Shows move progress, with a cancel button that rolls back before the switch step.
- Footer text: "Core settings files always stay in On My iPhone › Provenance."

## Open questions

1. **Extensions.** *Resolved:* extensions never resolve the bookmark. Spotlight, the ROM File Provider and the widgets read ROM artwork and paths; they keep showing metadata from `URL.documentsPath` and open picked-folder games through the main app by id.
2. **Should the ROM File Provider extension go away?** With a picked folder, Files.app already shows the library. The File Provider only matters for App Group storage, which is being retired.
3. **Should CloudKit ROM sync be off while a picked folder is active?** A shared folder in iCloud Drive already syncs, and CloudKit uploading the same ROMs would double the iCloud usage.
4. **Mac (Designed for iPad):** *Resolved:* unchanged. Bookmarks are made and resolved with no security-scope option on the iOS SDK, which is what the Designed-for-iPad build runs. The user verifies on a Mac that the sandbox keeps access across launches.

## Out of scope

- tvOS storage.
- Sharing saves between different emulator cores.
- Moving the Realm database.
- The iCube/iFly side of the contract. It needs to be implemented in those repos; this spec only defines the layout.

## Suggested phasing

1. `LibraryLocation` as the single source of the library root, derived from today's settings; `Paths` routed through it; today's stored partial paths pinned by tests. No UI; behaviour unchanged. **Done.**
2. The move engine (journal, verify, switch) with tests, starting with App Group → App storage, which retires `oldPaths`. **Done** (`docs/superpowers/plans/2026-10-11-storage-move-engine.md`; the only UI is a debug row in `FeatureFlagsDebugView`).
3. The picked-folder location, folder picker, bookmark lifecycle, failure UI. **Done** (`docs/superpowers/plans/2026-10-12-picked-folder-and-shared-library.md`).
4. The shared-library manifest, joining with de-duplication, and the rescan triggers. **Done** (`docs/superpowers/plans/2026-10-12-picked-folder-and-shared-library.md`).
5. iCloud Drive as a move target and source, through the same engine.
