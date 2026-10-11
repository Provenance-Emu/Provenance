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

## Data model

- `PVFile` stores `partialPath` plus a `relativeRoot` (`documents`, `caches`, `iCloud`). Add a `library` root that resolves to the active library location (App storage, iCloud Drive or the picked folder). Records then survive a move unchanged, and only the root's resolution changes.
  - This is the key simplification: a move copies files and flips one setting. It doesn't rewrite every record.
  - One-time migration: records under `documents` or `iCloud` whose path starts with `ROMs/`, `BIOS/` or `System/` (and, when saves follow, `Save States/`, `Battery States/` or `Screenshots/`) become `library`.
- A new setting, `libraryLocation`, takes the values `.appStorage`, `.iCloudDrive`, `.pickedFolder` and `.appGroup` (`.appGroup` is legacy and not selectable). It replaces reading `useAppGroups` and the iCloud Drive mode for paths. The iCloud Drive mode setting keeps meaning "sync method" for CloudKit.
- The bookmark is stored in the app's own defaults, not shared, along with a display name for the settings UI.
- `Paths.romsPath`, `biosesPath` and the rest go through one `LibraryLocation.root` instead of `documentsiCloudOrLocalPath`.

## Moving between locations

Use one move engine for every pair of locations, including leaving the App Group:

1. **Plan.** List the files that move. Check free space at the destination; for iCloud sources, count files that are only in the cloud and download them first.
2. **Copy.** Copy into the destination, verifying size (and MD5 for ROMs, which the library already has). The copy runs in the background with progress UI and can be resumed: write a journal file `move-journal.json` in Application Support listing what's done.
3. **Switch.** In one step: set `libraryLocation` to the destination and run the `relativeRoot` migration above if it hasn't run. The library now reads from the destination.
4. **Clean up.** Delete the source files only after a successful switch, and only files the journal recorded as copied. An option: "Keep a copy in the old location".
5. **Conflicts.** If a file of the same name already exists with a different hash, rename the incoming file and put it in `Conflicts/`, as today.

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

1. **Extensions.** Spotlight, the ROM File Provider and the widgets read ROM artwork and paths. Can a bookmark saved by the main app be resolved inside an extension (the bookmark data shared through the app group)? If not, extensions keep showing metadata but can't open picked-folder files, which may be acceptable. Test this before planning.
2. **Should the ROM File Provider extension go away?** With a picked folder, Files.app already shows the library. The File Provider only matters for App Group storage, which is being retired.
3. **Should CloudKit ROM sync be off while a picked folder is active?** A shared folder in iCloud Drive already syncs, and CloudKit uploading the same ROMs would double the iCloud usage.
4. **Mac (Designed for iPad):** folder bookmarks behave the same, but check that the sandbox keeps access across launches.

## Out of scope

- tvOS storage.
- Sharing saves between different emulator cores.
- Moving the Realm database.
- The iCube/iFly side of the contract. It needs to be implemented in those repos; this spec only defines the layout.

## Suggested phasing

1. `LibraryLocation` + the `library` relative root + migrating existing records. No UI; behaviour unchanged.
2. The move engine (journal, verify, switch) with tests, starting with App Group → App storage, which retires `oldPaths`.
3. The picked-folder location, folder picker, bookmark lifecycle, failure UI.
4. The shared-library manifest, joining with de-duplication, and the rescan triggers.
5. iCloud Drive as a move target and source, through the same engine.
