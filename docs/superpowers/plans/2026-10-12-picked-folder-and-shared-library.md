# Picked Library Folder and Shared Library (Phases 3 + 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The user can point the library at any folder in Files (a security-scoped bookmark), move ROMs/BIOS/System there and back through the phase 2 engine, recover when the folder disappears, and join a folder that another Provenance-family app already uses as a library (manifest, MD5 de-duplication, rescans).

**Architecture:** Everything that decides a path stays in `PVFileSystem` (PVLibrary package): `LibraryLocation` gains a `.pickedFolder` case whose root is resolved once per launch from a bookmark stored in `Defaults`; `FileLocationResolver` and `RelativeRoot` learn the picked root; `LibraryMoveEngine`/`LibraryMoveCoordinator` gain picked-folder moves, a manifest write at switch time, MD5 de-duplication and a record-remap hook. `PVLibrary` adds the Realm remap applier and an iCloud metadata watcher; `PVUI` adds Settings › Library › Storage Location (picker, confirmation, progress, failure UI) and the rescan triggers. tvOS: the location stays `.appStorage`, every new UI is `#if !os(tvOS)`.

**Tech Stack:** Swift 5 language mode on the Swift 6 toolchain, Swift concurrency, `Codable` JSON, `Defaults` (sindresorhus) keys in `PVSettings`, PVHashing `MD5Provider`, `UIDocumentPickerViewController`, security-scoped bookmarks, `NSMetadataQuery`, SwiftUI `@Observable`, XCTest in `PVLibraryTests`.

**Spec:** `docs/superpowers/specs/2026-10-11-library-storage-locations-design.md` (read the revised "Data model"; this plan is items 3 and 4 of "Suggested phasing"). Phase 2 plan with the engine's design decisions D1–D7: `docs/superpowers/plans/2026-10-11-storage-move-engine.md`. Handoff memory: `~/.claude/projects/-Users-jmattiello-Workspace-Provenance-Provenance/memory/handoff-oct11-2026-storage-locations.md`.

## Global Constraints

- iOS 17+ / tvOS 17+; the PV* packages also declare macOS 14+ and visionOS 1+, so every new file compiles on all four. `#if os(tvOS)` guards, never availability checks. Bookmark options: `[]` on iOS/tvOS/visionOS, `.withSecurityScope` only under `#if os(macOS)`.
- **tvOS is a no-op.** `LibraryLocation.current` stays `.appStorage`, `pickedFolderAtLaunch` is `.notConfigured`, the coordinator returns `nil`/throws, all new SwiftUI is `#if !os(tvOS)`.
- **Agents never run `xcodebuild` or `swift test`.** The user runs the PVLibrary test suite. Each task ends with: `swiftlint lint --path <file>` on every changed Swift file, a careful re-read of the diff for type errors (optionals, `Sendable`, `throws`), and a commit. Test code is still mandatory; write it as if it will run, because it will.
- **The folder layout contract is frozen** (spec § "Folder layout contract"): `<root>/.provenance-library.json`, `ROMs/<SystemIdentifier raw value>/`, `BIOS/`, `System/<console>/`. iFly is implementing the same contract concurrently. This plan adds only *additive* behaviour (see "Contract notes for iFly" at the end); do not rename folders, change the manifest's required keys, or write anything else at the root of a shared folder except `Conflicts/`, the saves folders when the user opts in, and hidden temp files.
- No magic strings at call sites: folder names in `LibraryMoveFolders`, the manifest name in `LibraryManifest.fileName`, Defaults keys in `PVSettingsModel.swift`, notification names in the `Notification.Name` extension in `LibraryLocation.swift`. `LibraryLocation` raw values, `LibraryMovePhase`/`Entry.State` raw values and journal keys are on-disk contracts: never rename them.
- The Realm database is never moved. `PVFileSystem` never imports Realm; Realm writes live in `PVLibrary`.
- No `Cores/` changes, no submodule edits, no `project.pbxproj` edits. New files under `PVLibrary/Sources/PVFileSystem/`, `PVLibrary/Sources/PVLibrary/`, `PVLibrary/Tests/PVLibraryTests/`, `PVUI/Sources/PVSwiftUI/` and `PVUI/Sources/PVUIBase/` need no project edits (SwiftPM globs).
- Tests use temp directories and injected closures only, never the real App Group, iCloud container or `Defaults` (except the pure `resolve(...)` table tests and the two existing `switchStored` tests, which restore the keys they touch).
- SwiftLint: line length 200; `type_body_length` warning at 300; `function_body_length` warning at 200.
- Conventional commits, subject < 72 chars, body ends with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Commit with `git -c commit.gpgsign=false commit`.
- **Working tree rules (the main tree has the user's unrelated uncommitted edits: DeltaSkin files, `Cores/Dolphin/dolphin-ios`, `Cores/Mupen64Plus/.../GBI.cpp`, `PVEmulatorCore+RunLoop.swift`, `PVAppDelegate+MetricKit.swift`, `Package.resolved`).** Stage only the files this plan names, by explicit path. Never `git add -A`, `git add .`, `git stash`, `git reset`, `git rebase`, `git checkout -- <file>`, `git push`, or touch a branch. Commit on `develop` in `/Users/jmattiello/Workspace/Provenance/Provenance`; the coordinator pushes. Verify `pwd` and `git branch --show-current` before each commit.
- The user's test command (for the handoff message at the end of each batch; agents do not run it):

  ```bash
  SCRATCH=/private/tmp/claude-501/-Users-jmattiello-Workspace-Provenance-Provenance/27a0693e-5054-48dd-a55f-cc73afcaf1fc/scratchpad
  printf 'OTHER_CFLAGS = $(inherited) -Wno-invalid-specialization\nOTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-invalid-specialization\n' > "$SCRATCH/realm.xcconfig"
  cd /Users/jmattiello/Workspace/Provenance/Provenance/PVLibrary && xcodebuild test \
    -workspace .swiftpm/xcode/package.xcworkspace -scheme PVLibrary-UnitTests \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -collect-test-diagnostics never \
    CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation \
    -xcconfig "$SCRATCH/realm.xcconfig" \
    -only-testing:PVLibraryTests/LibraryLocationTests \
    -only-testing:PVLibraryTests/LibraryFolderBookmarkTests \
    -only-testing:PVLibraryTests/PickedLibraryFolderTests \
    -only-testing:PVLibraryTests/FileLocationResolverRootsTests \
    -only-testing:PVLibraryTests/RelativeRootPickedFolderTests \
    -only-testing:PVLibraryTests/LibraryFolderInspectorTests \
    -only-testing:PVLibraryTests/LibraryManifestTests \
    -only-testing:PVLibraryTests/LibraryMoveEngineTests \
    -only-testing:PVLibraryTests/LibraryMoveEngineRecoveryTests \
    -only-testing:PVLibraryTests/LibraryMoveCleanupTests \
    -only-testing:PVLibraryTests/LibraryMoveCoordinatorTests \
    -only-testing:PVLibraryTests/SharedLibraryIndexTests \
    -only-testing:PVLibraryTests/LibraryPathRemapperTests \
    -only-testing:PVLibraryTests/RescanThrottleTests
  ```

## Review Focus

Behaviour the spec implies but no single sentence covers; each gets a test in the owning task.

1. **The picked folder is the library root, contains it, or sits inside `ROMs/`, `BIOS/`, `System/` or a saves folder.** The move would copy a tree into itself. `LibraryFolderInspector` refuses with `.isCurrentRoot`; a sibling subfolder of our own Documents (`On My iPhone › Provenance › MyLib`) is allowed and recommended (Task 5), and the engine's root check accepts that nesting (Task 6).
2. **A picked folder under iCloud Drive or a file provider** has `Documents/` inside its own path (`…/Mobile Documents/com~apple~CloudDocs/…`). Without stripping the picked root first, `createRelativePath` stores `com~apple~CloudDocs/…` as the partial path (Task 4).
3. **A ROM deleted in the shared folder by another app** must resolve to `.notFound` and be marked not downloaded, never deleted from the database (Task 3 resolver test; Task 11 wires `GameFileStatusService.refreshAllStatuses()` after a rescan).
4. **Joining when the shared folder already has the ROM under another name.** The record must point at the shared copy *before* cleanup deletes our source; if the remap cannot be applied, cleanup must not run (Tasks 9 and 10).
5. **A TestFlight downgrade mid-move.** The journal is now version 2; an older build must leave it alone (its `VersionProbe` does: `2 > 1`), and a version 1 journal from the previous build must still decode in this one (Task 6).

## Design decisions (settled here; implementers don't reopen them)

**D8 — `LibraryLocation.pickedFolder`.** Fourth case, raw value `"pickedFolder"`. Stored like the others in `Defaults[.libraryLocation]`; the folder itself is `Defaults[.libraryPickedFolder]` (JSON of `PickedLibraryFolder`: bookmark data, display name, `includesSaves`, `pickedAt`). Both are written only by `LibraryLocation.switchStored(to:pickedFolder:)`, which the engine calls at the switch. The bookmark is in the app's own defaults, never the App Group (spec, "Data model").

**D9 — Resolved once per launch.** `LibraryLocation.pickedFolderAtLaunch` (`static let`) resolves the bookmark, calls `startAccessingSecurityScopedResource()` and never stops it: cores open files by path for the life of the process. A stale bookmark is re-saved. A failure becomes `.unavailable(reason:)`; `rootURL` then falls back to local Documents so nothing crashes, the resolver still finds nothing for shared paths, and the UI shows the three-choice recovery (re-pick, App storage, try again). Nothing in the database is touched.

**D10 — Saves split.** A picked folder holds `ROMs/`, `BIOS/`, `System/` (`LibraryMoveFolders.shared`). `Battery States/`, `Save States/`, `Screenshots/`, `Cheats/`, `Patches/` (`LibraryMoveFolders.saves`) stay at the app-files root unless `includesSaves` is on. `LibraryLocation.savesRootURL` is the second root; `URL.savesRootPath` backs the five saves accessors in `Paths`. `LibraryLocation.root(forPartialPath:)` picks the root by the first path component, and the resolver searches `[root(forPartialPath), app-files root, iCloud in Drive mode]`.

**D11 — Supported moves.** `[.appGroup, .appStorage]` (phase 2), `[.appStorage, .pickedFolder]`, `[.pickedFolder, .appStorage]`, `[.pickedFolder, .pickedFolder]`. App Group → picked folder is refused: the group exit carries every top-level entry (D7) and only three of them belong in a shared folder; the UI says "Move to App storage first". iCloud Drive mode (live setting) refuses every picked-folder move until phase 5; the UI disables "Choose a folder…" while it is on. Leaving a picked folder always keeps a copy (the shared folder is left untouched). Moving from a picked folder carries the saves folders exactly when that folder `includesSaves`, and a new picked folder inherits that flag (one destination per move).

**D12 — Nested roots.** `On My iPhone › Provenance › MyLib` is our own Documents' subfolder, so the picked root is *inside* the App storage root. The engine's `requireDistinctRoots` now allows nesting unless the inner root is one of the moved top-level folders or inside one; `LibraryFolderInspector` applies the same rule to the pick.

**D13 — Journal version 2.** Adds optional `sourceFolder`, `destinationFolder` (the `PickedLibraryFolder` values, so a resume after the switch can still resolve the *old* picked folder once the stored one has changed), `deduplicateByMD5`, `remaps`. `currentVersion = 2`; a version 1 journal decodes (new keys optional), and an older build leaves a version 2 journal alone.

**D14 — Manifest at switch.** `LibraryManifest.writeIfAbsent(in:createdBy:)` runs in `performSwitch` when the destination is a picked folder: after the copy verified, before the setting is written, never over an existing manifest. Format: `{"version":1,"createdBy":"<bundle id>","createdAt":"<ISO 8601>"}`; readers ignore unknown keys and accept a missing `createdAt`.

**D15 — Join = move with de-duplication.** A folder that already has a manifest is joined: `moveToPickedFolder(..., deduplicate: true)`. For each `ROMs/` or `BIOS/` source file with no file at its own path in the destination, `SharedLibraryIndex` looks for a destination file of the same size and MD5 under any name; a hit is journaled as `.deduplicated` with `destinationPath` = the shared path and `remaps[source] = shared`. Cleanup verifies the shared copy by size and deletes the source like an identical file. Before cleanup, the coordinator hands `remaps` to a registered applier (`LibraryPathRemapper` in PVLibrary rewrites `PVFile.partialPath` and `PVGame.romPath`); if none is registered or it throws, cleanup waits for a later launch.

**D16 — Folder kinds and the write probe.** iOS paths do not reveal whether a Files folder is "On My iPhone" or a third-party provider (both live under `File Provider Storage`). The inspector classifies `iCloudDrive` (`isUbiquitousItem` or `/Mobile Documents/`), `ownDocuments`, `otherAppDocuments` (`/Containers/Data/Application/`), else `filesFolder`, and refuses any folder where a hidden probe file cannot be created and deleted (`.notWritable`). `otherAppDocuments` gets the spec's warning in the confirmation sheet.

**D17 — Rescans.** The existing "Scan ROM Directories" path (`.PVReimportLibrary` → `importROMDirectories()`) already scans `Paths.romsPath`, which follows the picked folder. Phase 4 adds triggers: foreground (throttled to once per 60 s), a "Rescan Library" button in the storage view, and `NSMetadataQuery` updates for an iCloud-located picked folder (which also starts downloads of cloud-only files under the shared folders). After each rescan on a picked folder, `GameFileStatusService.refreshAllStatuses()` marks missing files as not downloaded. Download progress in the game-launch gate is a follow-up, not this plan.

**D18 — Extensions (spec open question 1).** Spotlight, TopShelf, widgets and the File Provider keep resolving against `URL.documentsPath`; they never resolve the bookmark. Picked-folder games keep their metadata and artwork there and launch through the main app by id. No task; recorded in the spec amendment (Task 13).

---

## File map

| File | Responsibility |
|---|---|
| `PVLibrary/Sources/PVFileSystem/LibraryFolderBookmark.swift` (new) | Make/resolve security-scoped bookmarks; `LibraryFolderError`. |
| `PVLibrary/Sources/PVFileSystem/PickedLibraryFolder.swift` (new) | The stored folder value and its `Defaults`-backed store. |
| `PVLibrary/Sources/PVFileSystem/LibraryLocation.swift` | `.pickedFolder`, launch resolution, saves root, `launchAxis`, `switchStored(to:pickedFolder:)`. |
| `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift` | `libraryPickedFolder` key. |
| `PVLibrary/Sources/PVFileSystem/Paths.swift`, `iCloud/Paths+iCloud.swift` | `URL.savesRootPath`; saves accessors use it. |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift` | `shared`/`saves` folder lists, `isShared(partialPath:)`, request fields, `LibraryMovePreview`. |
| `PVLibrary/Sources/PVFileSystem/FileLocationResolver.swift` | Root-aware search order; injectable roots. |
| `PVLibrary/Sources/PVFileSystem/RelativeRoot.swift` | Strip picked roots before pattern matching. |
| `PVLibrary/Sources/PVFileSystem/LibraryManifest.swift` (new) | `.provenance-library.json` read/write. |
| `PVLibrary/Sources/PVFileSystem/LibraryFolderInspector.swift` (new) | Kind, write probe, overlap check, manifest presence, free space. |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift` | Version 2 fields, `.deduplicated`. |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift` | New pairs, nested roots, manifest at switch, de-dup in the copy loop. |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/SharedLibraryIndex.swift` (new) | Size → paths index with lazy MD5. |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift` | Picked-folder moves, preview, cancel, rebind, abandon, remap hook. |
| `PVLibrary/Sources/PVFileSystem/RescanThrottle.swift` (new) | Pure throttle. |
| `PVLibrary/Sources/PVLibrary/Database/LibraryPathRemapper.swift` (new) | Realm remap applier. |
| `PVLibrary/Sources/PVLibrary/Database/PVGameLibrary.swift` | Register the applier. |
| `PVLibrary/Sources/PVLibrary/Cloud Sync/iCloud/PickedFolderCloudWatcher.swift` (new) | `NSMetadataQuery` on an iCloud picked folder. |
| `PVUI/Sources/PVSwiftUI/Settings/ViewModels/LibraryStorageViewModel.swift` (new) | Storage screen state machine. |
| `PVUI/Sources/PVSwiftUI/Settings/Views/LibraryStorageView.swift` (new) | Storage screen, folder picker, confirmation, progress, recovery. |
| `PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift`, `SettingsSearchIndex+Entries.swift` | Row + search entry. |
| `PVUI/Sources/PVSwiftUI/App Delegate/MainUI/MainView.swift` | Launch alert when the folder is unavailable. |
| `PVUI/Sources/PVUIBase/Game Library/LibraryRescanRequester.swift` (new) | Throttled `.PVReimportLibrary` poster. |
| `PVUI/Sources/PVSwiftUI/App Delegate/PVAppDelegate.swift` | Foreground rescan, status refresh, cloud watcher start. |

---

## Batch A — PVFileSystem foundations (Tasks 1–5)

### Task 1: Security-scoped bookmark helper

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/LibraryFolderBookmark.swift`
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryFolderBookmarkTests.swift`

**Interfaces:**
- Produces: `LibraryFolderError` (Equatable, LocalizedError), `LibraryFolderBookmark.make(from: URL) throws -> Data`, `LibraryFolderBookmark.resolve(_ data: Data, fileManager: FileManager = .default) throws -> LibraryFolderBookmark.Resolution` where `Resolution { url: URL; isStale: Bool }`.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  LibraryFolderBookmarkTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryFolderBookmarkTests: XCTestCase {
    private var base: URL!

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryFolderBookmarkTests")
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func makeFolder(_ name: String) throws -> URL {
        let url = base.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testRoundTripResolvesToTheSameFolder() throws {
        let folder = try makeFolder("Library")
        let data = try LibraryFolderBookmark.make(from: folder)
        let resolution = try LibraryFolderBookmark.resolve(data)
        XCTAssertEqual(resolution.url.resolvingSymlinksInPath().path, folder.resolvingSymlinksInPath().path)
        XCTAssertFalse(resolution.isStale)
    }

    func testGarbageDataIsUnresolvable() {
        XCTAssertThrowsError(try LibraryFolderBookmark.resolve(Data("not a bookmark".utf8))) { error in
            guard case LibraryFolderError.bookmarkUnresolvable = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testDeletedFolderDoesNotResolve() throws {
        let folder = try makeFolder("Gone")
        let data = try LibraryFolderBookmark.make(from: folder)
        try FileManager.default.removeItem(at: folder)
        XCTAssertThrowsError(try LibraryFolderBookmark.resolve(data))
    }

    func testAFileIsNotAFolder() throws {
        let file = try LibraryMoveTestSupport.write(base, "file.txt", "x")
        let data = try LibraryFolderBookmark.make(from: file)
        XCTAssertThrowsError(try LibraryFolderBookmark.resolve(data)) { error in
            guard case LibraryFolderError.notADirectory = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testErrorsHaveDescriptions() {
        XCTAssertNotNil(LibraryFolderError.unreachable("/x").errorDescription)
        XCTAssertNotNil(LibraryFolderError.isCurrentRoot("/x").errorDescription)
        XCTAssertNotNil(LibraryFolderError.notWritable("/x").errorDescription)
        XCTAssertNotNil(LibraryFolderError.missingPickedFolder.errorDescription)
    }
}
```

- [ ] **Step 2: Write the implementation**

```swift
//
//  LibraryFolderBookmark.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The security-scoped bookmark that keeps access to a folder the user picked in Files: made once
//  from the picker's URL, resolved at every launch, and kept open for the life of the process.
//  Spec: docs/superpowers/specs/2026-10-11-library-storage-locations-design.md ("How a user-picked folder works").
//

import Foundation

public enum LibraryFolderError: Error, Equatable, LocalizedError {
    /// `URL(resolvingBookmarkData:)` threw: the folder was deleted, iCloud was signed out, or the provider app is gone.
    case bookmarkUnresolvable(String)
    /// The bookmark resolved but nothing readable is at the path.
    case unreachable(String)
    case notADirectory(String)
    /// The folder is the library root, contains it, or sits inside a folder the library owns.
    case isCurrentRoot(String)
    /// A hidden probe file could not be created and deleted: read-only, or a provider without in-place writes.
    case notWritable(String)
    /// `switchStored(to: .pickedFolder, pickedFolder: nil)`.
    case missingPickedFolder

    public var errorDescription: String? {
        switch self {
        case .bookmarkUnresolvable(let detail): return "The library folder can't be opened: \(detail)"
        case .unreachable(let path): return "The library folder is not reachable: \(path)"
        case .notADirectory(let path): return "\(path) is not a folder."
        case .isCurrentRoot(let path): return "\(path) is already part of the library."
        case .notWritable(let path): return "Provenance can't write to \(path). Choose a folder in On My iPhone or iCloud Drive."
        case .missingPickedFolder: return "No folder was given for the picked-folder location."
        }
    }
}

public enum LibraryFolderBookmark {
    public struct Resolution: Equatable, Sendable {
        public let url: URL
        /// The system wants a fresh bookmark; the caller re-saves one made from `url`.
        public let isStale: Bool
    }

    #if os(macOS)
    private static let creationOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
    private static let resolutionOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
    #else
    private static let creationOptions: URL.BookmarkCreationOptions = []
    private static let resolutionOptions: URL.BookmarkResolutionOptions = []
    #endif

    /// Bookmark data for `url`. Access is started first: the picker's URL needs it before any file operation,
    /// including this one. The Bool result is ignored on purpose: `false` only means the URL was never
    /// security-scoped (a plain path, as in tests), not that access was refused.
    public static func make(from url: URL) throws -> Data {
        _ = url.startAccessingSecurityScopedResource()
        return try url.bookmarkData(options: creationOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Resolves the bookmark and starts accessing the folder. The access is never stopped: cores open files
    /// by path for the life of the process.
    public static func resolve(_ data: Data, fileManager: FileManager = .default) throws -> Resolution {
        var isStale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: data, options: resolutionOptions, relativeTo: nil, bookmarkDataIsStale: &isStale)
        } catch {
            throw LibraryFolderError.bookmarkUnresolvable(error.localizedDescription)
        }
        _ = url.startAccessingSecurityScopedResource()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw LibraryFolderError.unreachable(url.path)
        }
        guard isDirectory.boolValue else { throw LibraryFolderError.notADirectory(url.path) }
        return Resolution(url: url.standardizedFileURL, isStale: isStale)
    }
}
```

- [ ] **Step 3: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryFolderBookmark.swift
swiftlint lint --path PVLibrary/Tests/PVLibraryTests/LibraryFolderBookmarkTests.swift
git add PVLibrary/Sources/PVFileSystem/LibraryFolderBookmark.swift PVLibrary/Tests/PVLibraryTests/LibraryFolderBookmarkTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): security-scoped bookmark helper for picked folders"
```

### Task 2: `PickedLibraryFolder`, its store, and `LibraryLocation.pickedFolder`

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/PickedLibraryFolder.swift`
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift` (the `// MARK: File system` extension, after `libraryLocation`)
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryLocation.swift`
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift` (`LibraryMoveFolders`)
- Modify: `PVLibrary/Sources/PVFileSystem/iCloud/Paths+iCloud.swift`, `PVLibrary/Sources/PVFileSystem/Paths.swift`
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift` (only the two `switch location` statements and the default `switchLocation` closure, so the package keeps compiling; Task 7 rewrites the file)
- Test: `PVLibrary/Tests/PVLibraryTests/PickedLibraryFolderTests.swift`, `PVLibrary/Tests/PVLibraryTests/LibraryLocationTests.swift`

**Interfaces:**
- Consumes: `LibraryFolderBookmark` (Task 1).
- Produces: `PickedLibraryFolder` (Codable), `PickedLibraryFolderStore` (`shared`, `load()`, `save(_:) throws`, `clear()`), `PickedFolderLaunchState`, `LibraryLocation.pickedFolder`, `LibraryLocation.pickedFolderAtLaunch`, `LibraryLocation.launchAxis`, `LibraryLocation.savesRootURL`, `LibraryLocation.root(forPartialPath:)`, `LibraryLocation.pickedRootsAtLaunch`, `LibraryLocation.switchStored(to:pickedFolder:) throws`, `LibraryMoveFolders.shared`, `.saves`, `isShared(partialPath:)`, `URL.savesRootPath`.

- [ ] **Step 1: Add the Defaults key** in `PVSettingsModel.swift` right after `libraryLocation`:

```swift
    /// JSON of `PickedLibraryFolder` (PVFileSystem): the security-scoped bookmark of the folder the user chose,
    /// its display name and whether saves live there too. Only `LibraryLocation.switchStored` writes it.
    static let libraryPickedFolder = Key<Data?>("libraryPickedFolder")
```

- [ ] **Step 2: Write the failing store tests**

```swift
//
//  PickedLibraryFolderTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class PickedLibraryFolderTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""
    private let key = "libraryPickedFolder"

    override func setUpWithError() throws {
        suite = "PickedLibraryFolderTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func testRoundTripKeepsEveryField() throws {
        let store = PickedLibraryFolderStore(defaults: defaults, key: key)
        let picked = Date(timeIntervalSinceReferenceDate: 1234.5678)
        let folder = PickedLibraryFolder(bookmark: Data([1, 2, 3]), displayName: "Retro", includesSaves: true, pickedAt: picked)
        try store.save(folder)
        XCTAssertEqual(store.load(), folder)
        XCTAssertEqual(store.load()?.version, PickedLibraryFolder.currentVersion)
    }

    func testEmptyStoreLoadsNil() {
        XCTAssertNil(PickedLibraryFolderStore(defaults: defaults, key: key).load())
    }

    func testClearRemovesTheValue() throws {
        let store = PickedLibraryFolderStore(defaults: defaults, key: key)
        try store.save(PickedLibraryFolder(bookmark: Data(), displayName: "x", includesSaves: false))
        store.clear()
        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: key))
    }

    func testUnreadableValueLoadsNil() {
        defaults.set(Data("{ nope".utf8), forKey: key)
        XCTAssertNil(PickedLibraryFolderStore(defaults: defaults, key: key).load())
    }
}
```

- [ ] **Step 3: Write `PickedLibraryFolder.swift`**

```swift
//
//  PickedLibraryFolder.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The folder the user picked for the library, as stored in the app's own defaults: the bookmark that
//  grants access, a name for Settings, and whether saves live there too (D10). Written only by
//  `LibraryLocation.switchStored(to:pickedFolder:)`.
//

import Foundation
import Defaults
import PVSettings

public struct PickedLibraryFolder: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var bookmark: Data
    public var displayName: String
    /// `Battery States`, `Save States`, `Screenshots`, `Cheats` and `Patches` live in the folder too.
    public var includesSaves: Bool
    /// When the user picked it. Tells two picks of one folder apart (bookmark bytes are not stable).
    public var pickedAt: Date

    public init(bookmark: Data, displayName: String, includesSaves: Bool, pickedAt: Date = Date()) {
        version = Self.currentVersion
        self.bookmark = bookmark
        self.displayName = displayName
        self.includesSaves = includesSaves
        self.pickedAt = pickedAt
    }
}

/// Reads and writes the one `PickedLibraryFolder`. Dates are stored as `timeIntervalSinceReferenceDate`
/// so `pickedAt` round-trips exactly (it is compared for equality).
public struct PickedLibraryFolderStore: Sendable {
    public static let shared = PickedLibraryFolderStore(read: { Defaults[.libraryPickedFolder] },
                                                        write: { Defaults[.libraryPickedFolder] = $0 })

    private let read: @Sendable () -> Data?
    private let write: @Sendable (Data?) -> Void

    public init(read: @escaping @Sendable () -> Data?, write: @escaping @Sendable (Data?) -> Void) {
        self.read = read
        self.write = write
    }

    /// A suite of its own, for tests.
    public init(defaults: UserDefaults, key: String) {
        self.init(read: { defaults.data(forKey: key) }, write: { defaults.set($0, forKey: key) })
    }

    public func load() -> PickedLibraryFolder? {
        guard let data = read() else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return try? decoder.decode(PickedLibraryFolder.self, from: data)
    }

    public func save(_ folder: PickedLibraryFolder) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        write(try encoder.encode(folder))
    }

    public func clear() {
        write(nil)
    }
}
```

- [ ] **Step 4: Add the folder lists to `LibraryMoveFolders`** in `LibraryMoveTypes.swift` (keep the existing members):

```swift
    /// What a picked folder holds (the shared layout contract: `ROMs/<system id>/`, `BIOS/`, `System/<console>/`).
    public static let shared: [String] = ["ROMs", "BIOS", "System"]

    /// What a picked folder holds in addition when `PickedLibraryFolder.includesSaves` is on (D10).
    public static let saves: [String] = ["Battery States", "Save States", "Screenshots", "Cheats", "Patches"]

    /// `true` when the partial path's first component is one of `shared`.
    public static func isShared(partialPath: String) -> Bool {
        let trimmed = partialPath.hasPrefix("/") ? String(partialPath.dropFirst()) : partialPath
        guard let top = trimmed.split(separator: "/", maxSplits: 1).first else { return false }
        return shared.contains(String(top))
    }
```

- [ ] **Step 5: Write the failing `LibraryLocation` tests** (append to `LibraryLocationTests.swift`; also change `testRawValuesArePinned` to assert `LibraryLocation.pickedFolder.rawValue == "pickedFolder"` and `allCases.count == 4`, and add `try` to the two existing `switchStored(to:)` calls)

```swift
    // MARK: - Picked folder

    func testStoredPickedFolderIsHonoured() {
        XCTAssertEqual(LibraryLocation.resolve(stored: .pickedFolder, useAppGroups: true, iCloudSync: false, iCloudDriveMode: false), .pickedFolder)
        XCTAssertEqual(LibraryLocation.resolve(stored: .pickedFolder, useAppGroups: false, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
        XCTAssertFalse(LibraryLocation.usesAppGroupContainer(stored: .pickedFolder, useAppGroupsAtLaunch: true))
    }

    func testPickedFolderRootFallsBackToLocalDocuments() {
        let picked = URL(fileURLWithPath: "/picked", isDirectory: true)
        XCTAssertEqual(LibraryLocation.pickedFolder.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, pickedFolder: picked, usesAppGroupContainer: false), picked)
        XCTAssertEqual(LibraryLocation.pickedFolder.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, pickedFolder: nil, usesAppGroupContainer: false), local)
        // The other cases ignore the picked folder.
        XCTAssertEqual(LibraryLocation.appStorage.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, pickedFolder: picked, usesAppGroupContainer: false), local)
    }

    func testSavesRootStaysInTheAppUnlessIncluded() {
        let picked = URL(fileURLWithPath: "/picked", isDirectory: true)
        XCTAssertEqual(LibraryLocation.pickedFolder.savesRootURL(rootURL: picked, appFilesRoot: local, includesSaves: false), local)
        XCTAssertEqual(LibraryLocation.pickedFolder.savesRootURL(rootURL: picked, appFilesRoot: local, includesSaves: true), picked)
        XCTAssertEqual(LibraryLocation.appStorage.savesRootURL(rootURL: local, appFilesRoot: local, includesSaves: false), local)
        XCTAssertEqual(LibraryLocation.appGroup.savesRootURL(rootURL: group, appFilesRoot: group, includesSaves: false), group)
    }

    func testRootForPartialPathSplitsSharedAndSaves() {
        let picked = URL(fileURLWithPath: "/picked", isDirectory: true)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "ROMs/com.provenance.snes/Game.sfc", libraryRoot: picked, savesRoot: local), picked)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "BIOS/scph5501.bin", libraryRoot: picked, savesRoot: local), picked)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "System/PSP/x", libraryRoot: picked, savesRoot: local), picked)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "Save States/Game/s.svs", libraryRoot: picked, savesRoot: local), local)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "/ROMs/x", libraryRoot: picked, savesRoot: local), picked)
    }

    func testLaunchStateFromStore() throws {
        let base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryLocationTests")
        addTeardownBlock { LibraryMoveTestSupport.removeTree(base) }
        let suite = "LibraryLocationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = PickedLibraryFolderStore(defaults: defaults, key: "k")

        XCTAssertEqual(LibraryLocation.launchState(folder: nil, store: store), .unavailable(reason: "No library folder is saved."))

        let folder = PickedLibraryFolder(bookmark: try LibraryFolderBookmark.make(from: base), displayName: "x", includesSaves: false)
        try store.save(folder)
        XCTAssertEqual(LibraryLocation.launchState(folder: folder, store: store).url?.resolvingSymlinksInPath().path, base.resolvingSymlinksInPath().path)

        let broken = PickedLibraryFolder(bookmark: Data("junk".utf8), displayName: "x", includesSaves: false)
        XCTAssertTrue(LibraryLocation.launchState(folder: broken, store: store).isUnavailable)
    }

    func testSwitchStoredToPickedFolderNeedsAFolder() {
        XCTAssertThrowsError(try LibraryLocation.switchStored(to: .pickedFolder, pickedFolder: nil)) { error in
            XCTAssertEqual(error as? LibraryFolderError, .missingPickedFolder)
        }
    }

    func testSavesAccessorsUseTheSavesRoot() {
        let saves = LibraryLocation.current.savesRootURL
        XCTAssertEqual(URL.savesRootPath, saves)
        XCTAssertEqual(Paths.saveSavesPath, saves.appendingPathComponent("Save States", isDirectory: true))
        XCTAssertEqual(Paths.batterySavesPath, saves.appendingPathComponent("Battery States", isDirectory: true))
        XCTAssertEqual(Paths.cheatsPath, saves.appendingPathComponent("Cheats", isDirectory: true))
    }
```

In the existing `testLibraryAccessorsUseTheCurrentRoot`, replace the `saveSavesPath` assertion with `XCTAssertEqual(Paths.systemPath, root.appendingPathComponent("System", isDirectory: true))` (non-tvOS only; wrap in `#if !os(tvOS)`).

- [ ] **Step 6: Change `LibraryLocation.swift`**

Replace the enum's cases and add the new members. The final file keeps everything that exists today except where shown.

```swift
public enum LibraryLocation: String, Sendable, CaseIterable {
    case appStorage
    case appGroup
    case iCloudDrive
    /// A folder the user picked in Files, reached through a security-scoped bookmark (`PickedLibraryFolder`).
    case pickedFolder
```

Keep `requiresRelaunchUserInfoKey`, `storedAtLaunch`, `useAppGroupsAtLaunch`, `usesAppGroupContainer`, `resolve` as they are: a stored `.pickedFolder` already satisfies `stored != .iCloudDrive`, so `resolve` returns it and `usesAppGroupContainer` returns `false`. Add:

```swift
    /// The appGroup/appStorage/pickedFolder axis this process launched on. Unlike `current` it ignores the live
    /// iCloud Drive setting. The move engine starts and resumes against this.
    public static var launchAxis: LibraryLocation {
        #if os(tvOS)
        return .appStorage
        #else
        if storedAtLaunch == .pickedFolder { return .pickedFolder }
        return usesAppGroupContainer ? .appGroup : .appStorage
        #endif
    }

    // MARK: - Picked folder

    /// Resolved once per process from the stored bookmark (D9). The access it starts is never stopped.
    public static let pickedFolderAtLaunch: PickedFolderLaunchState = {
        #if os(tvOS)
        return .notConfigured
        #else
        guard storedAtLaunch == .pickedFolder else { return .notConfigured }
        let store = PickedLibraryFolderStore.shared
        return launchState(folder: store.load(), store: store)
        #endif
    }()

    /// Whether the picked folder also holds the saves folders. `true` for every other location (one root).
    static let pickedFolderIncludesSavesAtLaunch: Bool = {
        guard storedAtLaunch == .pickedFolder else { return true }
        return PickedLibraryFolderStore.shared.load()?.includesSaves ?? false
    }()

    /// Resolves `folder`; a stale bookmark is re-saved through `store`. Pure apart from that write.
    static func launchState(folder: PickedLibraryFolder?, store: PickedLibraryFolderStore) -> PickedFolderLaunchState {
        guard let folder else { return .unavailable(reason: "No library folder is saved.") }
        do {
            let resolution = try LibraryFolderBookmark.resolve(folder.bookmark)
            if resolution.isStale, let fresh = try? LibraryFolderBookmark.make(from: resolution.url) {
                var refreshed = folder
                refreshed.bookmark = fresh
                try? store.save(refreshed)
            }
            return .available(resolution.url)
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }
    }

    /// Roots `RelativeRoot.createRelativePath` strips before pattern matching (Task 4).
    public static var pickedRootsAtLaunch: [URL] {
        pickedFolderAtLaunch.url.map { [$0] } ?? []
    }
```

Change `rootURL` and its testable overload:

```swift
    public var rootURL: URL {
        #if os(tvOS)
        return URL.cachesPath
        #else
        return rootURL(localDocuments: URL.documentsPathLocal,
                       appGroupDocuments: URL.documentsPathAppGroup,
                       iCloudDocuments: self == .iCloudDrive ? URL.iCloudDocumentsDirectory : nil,
                       pickedFolder: self == .pickedFolder ? Self.pickedFolderAtLaunch.url : nil,
                       usesAppGroupContainer: Self.usesAppGroupContainer)
        #endif
    }

    /// An unavailable picked folder falls back to local Documents so nothing crashes; the UI reports it (D9).
    func rootURL(localDocuments: URL, appGroupDocuments: URL?, iCloudDocuments: URL?, pickedFolder: URL?, usesAppGroupContainer: Bool) -> URL {
        switch self {
        case .appStorage:
            return localDocuments
        case .appGroup:
            return appGroupDocuments ?? localDocuments
        case .iCloudDrive:
            return iCloudDocuments ?? (usesAppGroupContainer ? appGroupDocuments : nil) ?? localDocuments
        case .pickedFolder:
            return pickedFolder ?? localDocuments
        }
    }

    /// Where the saves folders live: the app-files root for a picked folder without saves, else the library root (D10).
    public var savesRootURL: URL {
        #if os(tvOS)
        return rootURL
        #else
        return savesRootURL(rootURL: rootURL, appFilesRoot: URL.documentsPath, includesSaves: Self.pickedFolderIncludesSavesAtLaunch)
        #endif
    }

    func savesRootURL(rootURL: URL, appFilesRoot: URL, includesSaves: Bool) -> URL {
        self == .pickedFolder && !includesSaves ? appFilesRoot : rootURL
    }

    /// The root a partial path resolves against: the library root for `ROMs/`, `BIOS/`, `System/`, the saves root otherwise.
    public static func root(forPartialPath partialPath: String) -> URL {
        let current = LibraryLocation.current
        return root(forPartialPath: partialPath, libraryRoot: current.rootURL, savesRoot: current.savesRootURL)
    }

    static func root(forPartialPath partialPath: String, libraryRoot: URL, savesRoot: URL) -> URL {
        LibraryMoveFolders.isShared(partialPath: partialPath) ? libraryRoot : savesRoot
    }
```

Replace `switchStored(to:)`:

```swift
    /// Records the library location. Only `LibraryMoveEngine` (and the picked-folder recovery actions) call this.
    /// `pickedFolder` is required for `.pickedFolder` and cleared for every other location, so the stored
    /// bookmark can never outlive the location that uses it. Mirrors the legacy toggle. Applies at the next launch.
    public static func switchStored(to location: LibraryLocation, pickedFolder: PickedLibraryFolder? = nil) throws {
        if location == .pickedFolder {
            guard let pickedFolder else { throw LibraryFolderError.missingPickedFolder }
            try PickedLibraryFolderStore.shared.save(pickedFolder)
        } else {
            PickedLibraryFolderStore.shared.clear()
        }
        Defaults[.libraryLocation] = location.rawValue
        Defaults[.useAppGroups] = (location == .appGroup)
        NotificationCenter.default.post(name: .libraryLocationDidChange, object: nil,
                                        userInfo: [requiresRelaunchUserInfoKey: true])
    }
```

Add, after the enum:

```swift
/// What `LibraryLocation.pickedFolderAtLaunch` found.
public enum PickedFolderLaunchState: Sendable, Equatable {
    /// The stored location is not `.pickedFolder`.
    case notConfigured
    case available(URL)
    /// The folder was deleted, iCloud signed out, the provider removed, or the stored value is missing.
    case unavailable(reason: String)

    public var url: URL? {
        if case .available(let url) = self { return url }
        return nil
    }

    public var isUnavailable: Bool {
        if case .unavailable = self { return true }
        return false
    }
}
```

- [ ] **Step 7: Saves root accessor.** In `Paths+iCloud.swift`, after `documentsiCloudOrLocalPath`:

```swift
    /// Where saves, screenshots, cheats and patches live: see `LibraryLocation.savesRootURL` (D10). Background thread.
    static var savesRootPath: URL { LibraryLocation.current.savesRootURL }
```

In `Paths.swift`, change `batterySavesPath`, `saveSavesPath`, `screenShotsPath`, `cheatsPath`, `patchesPath` to build on `URL.savesRootPath` instead of `URL.documentsiCloudOrLocalPath`. `romsPath`, `biosesPath` and `systemPath` stay on `documentsiCloudOrLocalPath`.

- [ ] **Step 8: Keep the coordinator compiling** (`LibraryMoveCoordinator.swift`, minimal edits; Task 7 rewrites it): add `case .pickedFolder: return LibraryLocation.pickedFolderAtLaunch.url` to `defaultRoot(for:)`, and change the default `switchLocation` closure to `{ try LibraryLocation.switchStored(to: $0) }`. Search the whole package for other `switch` statements over `LibraryLocation` (`grep -rn "case .iCloudDrive" PVLibrary/Sources PVUI/Sources`) and add a `.pickedFolder` arm wherever the compiler would now complain (`FeatureFlagsDebugView` only prints `rawValue`, no switch).

- [ ] **Step 9: Lint and commit**

```bash
for f in PVLibrary/Sources/PVFileSystem/PickedLibraryFolder.swift PVLibrary/Sources/PVFileSystem/LibraryLocation.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift PVLibrary/Sources/PVFileSystem/Paths.swift PVLibrary/Sources/PVFileSystem/iCloud/Paths+iCloud.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift PVLibrary/Tests/PVLibraryTests/PickedLibraryFolderTests.swift PVLibrary/Tests/PVLibraryTests/LibraryLocationTests.swift; do swiftlint lint --path "$f"; done
git add PVLibrary/Sources/PVFileSystem/PickedLibraryFolder.swift PVLibrary/Sources/PVFileSystem/LibraryLocation.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift PVLibrary/Sources/PVFileSystem/Paths.swift PVLibrary/Sources/PVFileSystem/iCloud/Paths+iCloud.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift PVLibrary/Tests/PVLibraryTests/PickedLibraryFolderTests.swift PVLibrary/Tests/PVLibraryTests/LibraryLocationTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): pickedFolder location, stored folder and saves root"
```

### Task 3: `FileLocationResolver` searches the library and saves roots

**Files:**
- Modify: `PVLibrary/Sources/PVFileSystem/FileLocationResolver.swift`
- Test: `PVLibrary/Tests/PVLibraryTests/FileLocationResolverRootsTests.swift`

**Interfaces:**
- Consumes: `LibraryLocation.current.rootURL` / `.savesRootURL`, `LibraryMoveFolders.isShared(partialPath:)` (Task 2).
- Produces: `init(localBase:libraryRoot:savesRoot:iCloudBase:iCloudDriveMode:)` (internal, for tests), `libraryRoot(for partialPath:) -> URL`, unchanged public API otherwise (`resolve`, `bestURL`, `expectedLocalURL`, `fileExists`, `resolveByFilename`, `resolve(partialPath:systemIdentifier:candidateFilenames:)`, `relativePath(for:)`, `buildLocalFileIndex`, `buildAvailabilityIndex`, `buildFilenameIndex`, `existsInIndex`).

- [ ] **Step 1: Write the failing tests**

```swift
//
//  FileLocationResolverRootsTests.swift
//  PVLibraryTests
//
//  With a picked folder the library has two roots besides the app-files root: the resolver must search
//  the right one for each partial path and fall back to the app-files root (D10).
//

import XCTest
@testable import PVFileSystem

final class FileLocationResolverRootsTests: XCTestCase {
    private var base: URL!
    private var local: URL!
    private var library: URL!
    private var saves: URL!
    private var cloud: URL!

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "FileLocationResolverRootsTests")
        local = base.appendingPathComponent("app/Documents", isDirectory: true)
        library = base.appendingPathComponent("picked", isDirectory: true)
        saves = local
        cloud = base.appendingPathComponent("icloud/Documents", isDirectory: true)
        for url in [local, library, cloud] {
            try FileManager.default.createDirectory(at: url!, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func resolver(driveMode: Bool = false, library: URL? = nil, saves: URL? = nil) -> FileLocationResolver {
        let local = self.local!, lib = library ?? self.library!, sav = saves ?? self.saves!, cloud = self.cloud!
        return FileLocationResolver(localBase: { local }, libraryRoot: { lib }, savesRoot: { sav },
                                    iCloudBase: { cloud }, iCloudDriveMode: { driveMode })
    }

    func testSharedPathsResolveInTheLibraryRoot() throws {
        try LibraryMoveTestSupport.write(library, "ROMs/com.provenance.snes/Game.sfc", "rom")
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Game.sfc"), .local(library.appendingPathComponent("ROMs/com.provenance.snes/Game.sfc")))
    }

    func testSavesResolveInTheSavesRoot() throws {
        try LibraryMoveTestSupport.write(saves, "Save States/Game/s.svs", "save")
        XCTAssertEqual(resolver().resolve("Save States/Game/s.svs"), .local(saves.appendingPathComponent("Save States/Game/s.svs")))
    }

    func testAppFilesRootIsTheFallback() throws {
        // A ROM imported while the picked folder was unavailable landed in Documents; it is still found.
        try LibraryMoveTestSupport.write(local, "ROMs/com.provenance.snes/Old.sfc", "rom")
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Old.sfc"), .local(local.appendingPathComponent("ROMs/com.provenance.snes/Old.sfc")))
    }

    func testLibraryRootWinsOverAppFilesRoot() throws {
        try LibraryMoveTestSupport.write(local, "ROMs/com.provenance.snes/Game.sfc", "old")
        try LibraryMoveTestSupport.write(library, "ROMs/com.provenance.snes/Game.sfc", "new")
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Game.sfc").url, library.appendingPathComponent("ROMs/com.provenance.snes/Game.sfc"))
    }

    func testDeletedSharedFileIsNotFound() throws {
        // Review Focus 3: another app removed the ROM; nothing elsewhere may stand in for it.
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Gone.sfc"), .notFound)
        XCTAssertFalse(resolver().fileExists("ROMs/com.provenance.snes/Gone.sfc"))
    }

    func testICloudIsSearchedOnlyInDriveMode() throws {
        try LibraryMoveTestSupport.write(cloud, "ROMs/com.provenance.snes/Cloud.sfc", "rom")
        XCTAssertEqual(resolver().resolve("ROMs/com.provenance.snes/Cloud.sfc"), .notFound)
        XCTAssertEqual(resolver(driveMode: true).resolve("ROMs/com.provenance.snes/Cloud.sfc"), .cloudDrive(cloud.appendingPathComponent("ROMs/com.provenance.snes/Cloud.sfc")))
    }

    func testExpectedURLUsesTheRootForThePath() {
        XCTAssertEqual(resolver().expectedLocalURL(for: "ROMs/x/y.bin"), library.appendingPathComponent("ROMs/x/y.bin"))
        XCTAssertEqual(resolver().expectedLocalURL(for: "Battery States/y/y.sav"), saves.appendingPathComponent("Battery States/y/y.sav"))
        XCTAssertEqual(resolver().bestURL(for: "ROMs/x/missing.bin"), library.appendingPathComponent("ROMs/x/missing.bin"))
    }

    func testSameRootIsSearchedOnce() {
        // App storage: all three roots are Documents. The search order must not repeat it.
        let r = resolver(library: local, saves: local)
        XCTAssertEqual(r.searchBases(for: "ROMs/x").count, 1)
        XCTAssertEqual(resolver().searchBases(for: "ROMs/x").map(\.url), [library, local])
        XCTAssertEqual(resolver().searchBases(for: "Save States/x").map(\.url), [saves])
    }

    func testIndexesCoverEveryRoot() throws {
        try LibraryMoveTestSupport.write(library, "ROMs/com.provenance.snes/A.sfc", "a")
        try LibraryMoveTestSupport.write(local, "Save States/A/s.svs", "s")
        let all = resolver().buildLocalFileIndex()
        XCTAssertTrue(all.contains("ROMs/com.provenance.snes/A.sfc"))
        XCTAssertTrue(all.contains("Save States/A/s.svs"))
        let roms = resolver().buildLocalFileIndex(under: "ROMs")
        XCTAssertTrue(roms.contains("ROMs/com.provenance.snes/A.sfc"))
        XCTAssertFalse(roms.contains("Save States/A/s.svs"))
    }

    func testRelativePathStripsTheLibraryRoot() {
        XCTAssertEqual(resolver().relativePath(for: library.appendingPathComponent("ROMs/x/y.bin")), "ROMs/x/y.bin")
        XCTAssertEqual(resolver().relativePath(for: local.appendingPathComponent("Save States/y")), "Save States/y")
        XCTAssertNil(resolver().relativePath(for: base.appendingPathComponent("elsewhere/z")))
    }

    func testFilenameFallbackLooksInTheLibraryRoot() throws {
        try LibraryMoveTestSupport.write(library, "ROMs/com.provenance.snes/Game (USA).sfc", "rom")
        let found = resolver().resolveByFilename(under: "com.provenance.snes", filename: "game (usa).SFC")
        XCTAssertEqual(found.url, library.appendingPathComponent("ROMs/com.provenance.snes/Game (USA).sfc"))
    }
}
```

- [ ] **Step 2: Rework the resolver's roots.** Replace the "Base URLs" section and `private init()`:

```swift
    public static let shared = FileLocationResolver()

    private let localBase: @Sendable () -> URL
    private let libraryRootProvider: @Sendable () -> URL
    private let savesRootProvider: @Sendable () -> URL
    private let iCloudBase: @Sendable () -> URL?
    private let iCloudDriveMode: @Sendable () -> Bool

    /// Production roots: the app-files root, `LibraryLocation.current`'s two roots, the ubiquity Documents folder.
    private convenience init() {
        self.init(localBase: { Self.platformLocalBase },
                  libraryRoot: { LibraryLocation.current.rootURL },
                  savesRoot: { LibraryLocation.current.savesRootURL },
                  iCloudBase: { Self.platformICloudBase },
                  iCloudDriveMode: { Self.platformICloudDriveMode })
    }

    /// Injected roots, for tests.
    init(localBase: @escaping @Sendable () -> URL,
         libraryRoot: @escaping @Sendable () -> URL,
         savesRoot: @escaping @Sendable () -> URL,
         iCloudBase: @escaping @Sendable () -> URL?,
         iCloudDriveMode: @escaping @Sendable () -> Bool) {
        self.localBase = localBase
        self.libraryRootProvider = libraryRoot
        self.savesRootProvider = savesRoot
        self.iCloudBase = iCloudBase
        self.iCloudDriveMode = iCloudDriveMode
    }

    private static var platformLocalBase: URL {
        #if os(tvOS)
        return URL.cachesPath
        #else
        return URL.documentsPath
        #endif
    }

    private static var platformICloudBase: URL? {
        #if os(tvOS)
        return nil
        #else
        return URL.iCloudDocumentsDirectory
        #endif
    }

    private static var platformICloudDriveMode: Bool {
        #if os(tvOS)
        return false
        #else
        return Defaults[.iCloudSyncMode].isICloudDrive
        #endif
    }

    // MARK: - Base URLs

    /// The app-files root (Documents on iOS/macOS, Caches on tvOS). Imports and core configs live here.
    public var localBaseURL: URL { localBase() }

    /// `<ubiquityContainer>/Documents/`, or `nil` when iCloud is not configured or on tvOS.
    public var iCloudBaseURL: URL? { iCloudBase() }

    public var isICloudDriveMode: Bool { iCloudDriveMode() }

    /// The root a partial path belongs to: the library root for `ROMs/`, `BIOS/`, `System/`, the saves root otherwise (D10).
    public func libraryRoot(for partialPath: String) -> URL {
        LibraryMoveFolders.isShared(partialPath: partialPath) ? libraryRootProvider() : savesRootProvider()
    }

    /// Search order for one partial path: its root, the app-files root, then iCloud Drive in Drive mode. No repeats.
    func searchBases(for partialPath: String) -> [(url: URL, isCloud: Bool)] {
        var bases: [(URL, Bool)] = [(libraryRoot(for: partialPath), false), (localBase(), false)]
        if iCloudDriveMode(), let cloud = iCloudBase() { bases.append((cloud, true)) }
        return Self.dedupe(bases)
    }

    /// Every root a library file may be under, for whole-library scans.
    private var allBases: [(url: URL, isCloud: Bool)] {
        var bases: [(URL, Bool)] = [(libraryRootProvider(), false), (savesRootProvider(), false), (localBase(), false)]
        if iCloudDriveMode(), let cloud = iCloudBase() { bases.append((cloud, true)) }
        return Self.dedupe(bases)
    }

    private static func dedupe(_ bases: [(URL, Bool)]) -> [(url: URL, isCloud: Bool)] {
        var seen = Set<String>()
        var out: [(url: URL, isCloud: Bool)] = []
        for (url, isCloud) in bases where seen.insert(url.standardizedFileURL.path).inserted {
            out.append((url: url, isCloud: isCloud))
        }
        return out
    }
```

Then rewrite the methods that used `localBaseURL`/`iCloudBaseURL` directly:

```swift
    public func resolve(_ partialPath: String) -> FileResolution {
        let fm = FileManager.default
        for base in searchBases(for: partialPath) {
            let url = base.url.appendingPathComponent(partialPath)
            if fm.fileExists(atPath: url.path) {
                return base.isCloud ? .cloudDrive(url) : .local(url)
            }
        }
        return .notFound
    }

    public func expectedLocalURL(for partialPath: String) -> URL {
        libraryRoot(for: partialPath).appendingPathComponent(partialPath)
    }

    public func resolveByFilename(under subdirectory: String, filename: String) -> FileResolution {
        guard !filename.isEmpty else { return .notFound }
        let lowered = filename.lowercased()
        let romsScopedSubdir = "ROMs/" + subdirectory
        // ROMs live under "ROMs/<systemID>/" while save states / BIOS use the raw subdirectory; try both under every base.
        let bases = Self.dedupe((searchBases(for: romsScopedSubdir) + searchBases(for: subdirectory)).map { ($0.url, $0.isCloud) })
        for base in bases {
            for dir in [base.url.appendingPathComponent(romsScopedSubdir), base.url.appendingPathComponent(subdirectory)] {
                if let match = firstMatch(in: dir, filename: lowered) {
                    return base.isCloud ? .cloudDrive(match) : .local(match)
                }
            }
        }
        return .notFound
    }

    public func relativePath(for url: URL) -> String? {
        for base in allBases {
            if let stripped = stripPrefix(url: url, base: base.url) { return stripped }
        }
        return nil
    }

    public func buildLocalFileIndex(under subdirectory: String? = nil) -> Set<String> {
        let bases = subdirectory.map { searchBases(for: $0) } ?? allBases
        var index = Set<String>()
        for base in bases where !base.isCloud {
            index.formUnion(enumerateRelativePaths(base: base.url, subdirectory: subdirectory))
        }
        return index
    }

    public func buildAvailabilityIndex(under subdirectory: String? = nil) -> Set<String> {
        let bases = subdirectory.map { searchBases(for: $0) } ?? allBases
        var index = Set<String>()
        for base in bases {
            index.formUnion(enumerateRelativePaths(base: base.url, subdirectory: subdirectory))
        }
        return index
    }
```

`fileExists`, `bestURL`, `resolve(partialPath:systemIdentifier:candidateFilenames:)`, `buildFilenameIndex`, `existsInIndex`, `firstMatch`, `stripPrefix` and `enumerateRelativePaths` stay as they are. `enumerateRelativePaths` must not create the directory when it is missing (it doesn't today; keep it so — a missing `Save States` under the picked root is normal). Remove the `#if !os(tvOS)` blocks that guarded the iCloud branches: the closures return `nil`/`false` on tvOS. Keep `import Defaults` and `import PVSettings`.

- [ ] **Step 3: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/FileLocationResolver.swift
swiftlint lint --path PVLibrary/Tests/PVLibraryTests/FileLocationResolverRootsTests.swift
git add PVLibrary/Sources/PVFileSystem/FileLocationResolver.swift PVLibrary/Tests/PVLibraryTests/FileLocationResolverRootsTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): resolver searches the library and saves roots"
```

### Task 4: `createRelativePath` strips the picked root first

**Files:**
- Modify: `PVLibrary/Sources/PVFileSystem/RelativeRoot.swift`
- Test: `PVLibrary/Tests/PVLibraryTests/RelativeRootPickedFolderTests.swift`

**Interfaces:**
- Consumes: `LibraryLocation.pickedRootsAtLaunch` (Task 2).
- Produces: `RelativeRoot.createRelativePath(fromURL:stripping:) -> String`; the existing one-argument method delegates to it.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  RelativeRootPickedFolderTests.swift
//  PVLibraryTests
//
//  A picked folder under iCloud Drive or a file provider has "Documents/" inside its own path, so the
//  pattern matching in `createRelativePath` stores a wrong partial path unless the root is stripped first.
//

import XCTest
@testable import PVFileSystem

final class RelativeRootPickedFolderTests: XCTestCase {
    private let expected = "ROMs/com.provenance.snes/Game.sfc"

    func testPickedICloudFolderIsStrippedBeforePatterns() {
        let root = URL(fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Retro", isDirectory: true)
        let url = root.appendingPathComponent(expected)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: url, stripping: [root]), expected)
        // Without the root, the "Documents/" pattern inside "Mobile Documents/" wins.
        XCTAssertNotEqual(RelativeRoot.documents.createRelativePath(fromURL: url, stripping: []), expected)
    }

    func testFilesFolderIsStripped() {
        let root = URL(fileURLWithPath: "/private/var/mobile/Containers/Shared/AppGroup/0A1B/File Provider Storage/Retro", isDirectory: true)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: root.appendingPathComponent(expected), stripping: [root]), expected)
    }

    func testOwnDocumentsSubfolderIsStripped() {
        let root = URL(fileURLWithPath: "/private/var/mobile/Containers/Data/Application/0A1B/Documents/MyLib", isDirectory: true)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: root.appendingPathComponent(expected), stripping: [root]), expected)
    }

    func testTrailingSlashAndVarPrefixAreTolerated() {
        let root = URL(fileURLWithPath: "/var/mobile/Containers/Shared/AppGroup/0A1B/File Provider Storage/Retro/", isDirectory: true)
        let url = URL(fileURLWithPath: "/var/mobile/Containers/Shared/AppGroup/0A1B/File Provider Storage/Retro/" + expected)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: url, stripping: [root]), expected)
    }

    func testUnrelatedURLFallsThroughToTheOldRules() {
        let root = URL(fileURLWithPath: "/picked", isDirectory: true)
        let url = URL(fileURLWithPath: "/private/var/mobile/Containers/Shared/AppGroup/0A1B/Documents/" + expected)
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: url, stripping: [root]), expected)
    }
}
```

- [ ] **Step 2: Implement.** In `RelativeRoot.swift` rename the existing `createRelativePath(fromURL:)` body into the new two-argument method and add the strip:

```swift
    func createRelativePath(fromURL url: URL) -> String {
        createRelativePath(fromURL: url, stripping: LibraryLocation.pickedRootsAtLaunch)
    }

    /// `roots` are stripped before any pattern matching: a picked folder under iCloud Drive or a file provider
    /// has "Documents/" inside its own path and would otherwise store a wrong partial path (D8, Review Focus 2).
    func createRelativePath(fromURL url: URL, stripping roots: [URL]) -> String {
        if let stripped = Self.strip(url: url, roots: roots) {
            return stripped
        }
        // … the existing body, unchanged, from `let urlPath = url.path` to the final `return url.lastPathComponent` …
    }

    /// The part of `url` below the first matching root, in raw, standardized or symlink-resolved form.
    static func strip(url: URL, roots: [URL]) -> String? {
        let paths = [url.path, url.standardizedFileURL.path, url.resolvingSymlinksInPath().path]
        for root in roots {
            let bases = [root.path, root.standardizedFileURL.path, root.resolvingSymlinksInPath().path]
            for base in bases {
                let prefix = base.hasSuffix("/") ? base : base + "/"
                for path in paths where path.hasPrefix(prefix) {
                    return String(path.dropFirst(prefix.count))
                }
            }
        }
        return nil
    }
```

- [ ] **Step 3: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/RelativeRoot.swift
swiftlint lint --path PVLibrary/Tests/PVLibraryTests/RelativeRootPickedFolderTests.swift
git add PVLibrary/Sources/PVFileSystem/RelativeRoot.swift PVLibrary/Tests/PVLibraryTests/RelativeRootPickedFolderTests.swift
git -c commit.gpgsign=false commit -m "fix(storage): strip the picked root before partial-path patterns"
```

### Task 5: `LibraryManifest` and `LibraryFolderInspector`

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/LibraryManifest.swift`
- Create: `PVLibrary/Sources/PVFileSystem/LibraryFolderInspector.swift`
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryManifestTests.swift`, `PVLibrary/Tests/PVLibraryTests/LibraryFolderInspectorTests.swift`

**Interfaces:**
- Consumes: `LibraryFolderError` (Task 1), `LibraryMoveFolders.shared/.saves` (Task 2), `LibraryMovePlanner.volumeCapacity` (phase 2).
- Produces: `LibraryManifest` (`fileName`, `currentVersion`, `url(in:)`, `exists(in:fileManager:)`, `read(from:)`, `writeIfAbsent(in:createdBy:fileManager:) throws -> Bool`), `LibraryFolderKind`, `LibraryFolderInspection`, `LibraryFolderInspector.inspect(_:) throws`.

- [ ] **Step 1: Write the failing manifest tests**

```swift
//
//  LibraryManifestTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryManifestTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryManifestTests")
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(root)
    }

    func testFileNameIsTheContract() {
        XCTAssertEqual(LibraryManifest.fileName, ".provenance-library.json")
        XCTAssertEqual(LibraryManifest.currentVersion, 1)
    }

    func testWriteThenRead() throws {
        XCTAssertFalse(LibraryManifest.exists(in: root))
        XCTAssertTrue(try LibraryManifest.writeIfAbsent(in: root, createdBy: "org.provenance-emu.provenance"))
        XCTAssertTrue(LibraryManifest.exists(in: root))
        let manifest = try LibraryManifest.read(from: root)
        XCTAssertEqual(manifest.version, 1)
        XCTAssertEqual(manifest.createdBy, "org.provenance-emu.provenance")
        XCTAssertNotNil(manifest.createdAt)
    }

    func testJSONShapeIsTheContract() throws {
        try LibraryManifest.writeIfAbsent(in: root, createdBy: "org.test")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: LibraryManifest.url(in: root))) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(json["createdBy"] as? String, "org.test")
        XCTAssertNotNil(json["createdAt"] as? String, "ISO 8601 string")
    }

    func testNeverOverwritesAnotherAppsManifest() throws {
        try LibraryMoveTestSupport.write(root, LibraryManifest.fileName, #"{"version":1,"createdBy":"com.ifly","extra":true}"#)
        XCTAssertFalse(try LibraryManifest.writeIfAbsent(in: root, createdBy: "org.test"))
        let manifest = try LibraryManifest.read(from: root)
        XCTAssertEqual(manifest.createdBy, "com.ifly")
        XCTAssertNil(manifest.createdAt, "a missing createdAt is tolerated")
    }

    func testNewerVersionStillReads() throws {
        try LibraryMoveTestSupport.write(root, LibraryManifest.fileName, #"{"version":7,"createdBy":"com.icube","createdAt":"2026-10-12T00:00:00Z"}"#)
        XCTAssertEqual(try LibraryManifest.read(from: root).version, 7)
    }

    func testUnreadableManifestThrows() throws {
        try LibraryMoveTestSupport.write(root, LibraryManifest.fileName, "{ not json")
        XCTAssertThrowsError(try LibraryManifest.read(from: root))
    }
}
```

- [ ] **Step 2: Write `LibraryManifest.swift`**

```swift
//
//  LibraryManifest.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  `.provenance-library.json` at the root of a shared library folder: the layout contract shared with iCube
//  and iFly (spec § "Folder layout contract"). Written once by whichever app created the library, never
//  rewritten. Readers ignore keys they don't know and tolerate a missing `createdAt`.
//

import Foundation

public struct LibraryManifest: Codable, Sendable, Equatable {
    public static let fileName = ".provenance-library.json"
    public static let currentVersion = 1

    public var version: Int
    /// Bundle identifier of the app that created the library.
    public var createdBy: String
    public var createdAt: Date?

    public init(createdBy: String, createdAt: Date? = Date()) {
        version = Self.currentVersion
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    public static func url(in root: URL) -> URL {
        root.appendingPathComponent(fileName, isDirectory: false)
    }

    public static func exists(in root: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: url(in: root).path)
    }

    public static func read(from root: URL) throws -> LibraryManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LibraryManifest.self, from: Data(contentsOf: url(in: root)))
    }

    /// Writes a manifest naming `createdBy` unless the folder already has one.
    /// - Returns: `true` when a manifest was written.
    @discardableResult
    public static func writeIfAbsent(in root: URL, createdBy: String, fileManager: FileManager = .default) throws -> Bool {
        guard !exists(in: root, fileManager: fileManager) else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(LibraryManifest(createdBy: createdBy)).write(to: url(in: root), options: .atomic)
        return true
    }
}
```

- [ ] **Step 3: Write the failing inspector tests**

```swift
//
//  LibraryFolderInspectorTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryFolderInspectorTests: XCTestCase {
    private var base: URL!
    private var documents: URL!

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryFolderInspectorTests")
        documents = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documents.appendingPathComponent("ROMs/com.provenance.snes"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func inspector(roots: [URL]? = nil) -> LibraryFolderInspector {
        let documents = self.documents!
        let roots = roots ?? [documents]
        return LibraryFolderInspector(appDocuments: documents, libraryRoots: { roots }, availableCapacity: { _ in 42 })
    }

    private func folder(_ relative: String) throws -> URL {
        let url = base.appendingPathComponent(relative, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testClassificationTable() {
        let docs = "/private/var/mobile/Containers/Data/Application/A/Documents"
        XCTAssertEqual(LibraryFolderInspector.classify(path: docs + "/MyLib", appDocumentsPath: docs, isUbiquitous: false), .ownDocuments)
        XCTAssertEqual(LibraryFolderInspector.classify(path: "/private/var/mobile/Containers/Data/Application/B/Documents/Lib", appDocumentsPath: docs, isUbiquitous: false), .otherAppDocuments)
        XCTAssertEqual(LibraryFolderInspector.classify(path: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Lib", appDocumentsPath: docs, isUbiquitous: false), .iCloudDrive)
        XCTAssertEqual(LibraryFolderInspector.classify(path: "/x/y", appDocumentsPath: docs, isUbiquitous: true), .iCloudDrive)
        XCTAssertEqual(LibraryFolderInspector.classify(path: "/private/var/mobile/Containers/Shared/AppGroup/C/File Provider Storage/Lib", appDocumentsPath: docs, isUbiquitous: false), .filesFolder)
    }

    func testSiblingSubfolderOfDocumentsIsAllowed() throws {
        // Review Focus 1: "On My iPhone › Provenance › MyLib" is the recommended pick.
        let picked = try folder("app/Documents/MyLib")
        let inspection = try inspector().inspect(picked)
        XCTAssertEqual(inspection.kind, .ownDocuments)
        XCTAssertFalse(inspection.hasManifest)
        XCTAssertEqual(inspection.availableBytes, 42)
    }

    func testTheRootItselfIsRefused() {
        XCTAssertThrowsError(try inspector().inspect(documents)) { error in
            guard case LibraryFolderError.isCurrentRoot = error else { return XCTFail("\(error)") }
        }
    }

    func testAFolderInsideALibraryFolderIsRefused() throws {
        let inside = try folder("app/Documents/ROMs/com.provenance.snes/Sub")
        XCTAssertThrowsError(try inspector().inspect(inside)) { error in
            guard case LibraryFolderError.isCurrentRoot = error else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try inspector().inspect(documents.appendingPathComponent("ROMs", isDirectory: true)))
        let saves = try folder("app/Documents/Save States/Game")
        XCTAssertThrowsError(try inspector().inspect(saves))
    }

    func testAFolderContainingTheRootIsRefused() {
        XCTAssertThrowsError(try inspector().inspect(base.appendingPathComponent("app", isDirectory: true))) { error in
            guard case LibraryFolderError.isCurrentRoot = error else { return XCTFail("\(error)") }
        }
    }

    func testManifestIsDetected() throws {
        let picked = try folder("shared")
        try LibraryManifest.writeIfAbsent(in: picked, createdBy: "com.ifly")
        XCTAssertTrue(try inspector().inspect(picked).hasManifest)
    }

    func testNotADirectory() throws {
        let file = try LibraryMoveTestSupport.write(base, "file.txt", "x")
        XCTAssertThrowsError(try inspector().inspect(file)) { error in
            guard case LibraryFolderError.notADirectory = error else { return XCTFail("\(error)") }
        }
    }

    func testReadOnlyFolderIsNotWritable() throws {
        let picked = try folder("readonly")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: picked.path)
        addTeardownBlock { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: picked.path) }
        XCTAssertThrowsError(try inspector().inspect(picked)) { error in
            guard case LibraryFolderError.notWritable = error else { return XCTFail("\(error)") }
        }
        XCTAssertNil(try? FileManager.default.contentsOfDirectory(atPath: picked.path).first { $0.hasPrefix(".provenance-write-probe") })
    }

    func testProbeFileIsRemoved() throws {
        let picked = try folder("clean")
        _ = try inspector().inspect(picked)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: picked.path), [])
    }
}
```

- [ ] **Step 4: Write `LibraryFolderInspector.swift`**

```swift
//
//  LibraryFolderInspector.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Checks a folder the user picked before any move: it must be a directory outside the library's own
//  folders, writable in place, and the UI needs to know what kind of place it is (D16, D12).
//

import Foundation

public enum LibraryFolderKind: String, Sendable, Equatable {
    /// Under this app's Documents ("On My iPhone › Provenance › …"): local, fast, survives other apps. Recommended.
    case ownDocuments
    /// Another app's container: the folder disappears when that app is deleted. Warn.
    case otherAppDocuments
    /// Files may be cloud-only placeholders until downloaded.
    case iCloudDrive
    /// On My iPhone, or a file provider; iOS paths cannot tell them apart. The write probe is the gate.
    case filesFolder
}

public struct LibraryFolderInspection: Sendable, Equatable {
    public let url: URL
    public let kind: LibraryFolderKind
    /// `LibraryManifest.fileName` is present: picking it means joining that library (phase 4).
    public let hasManifest: Bool
    public let availableBytes: Int64
}

public struct LibraryFolderInspector: Sendable {
    static let probePrefix = ".provenance-write-probe-"

    private let fileManager: FileManager
    private let appDocuments: URL
    private let libraryRoots: @Sendable () -> [URL]
    private let availableCapacity: @Sendable (URL) throws -> Int64

    public init(fileManager: FileManager = .default,
                appDocuments: URL = URL.documentsPathLocal,
                libraryRoots: @escaping @Sendable () -> [URL] = { [LibraryLocation.current.rootURL, LibraryLocation.current.savesRootURL] },
                availableCapacity: @escaping @Sendable (URL) throws -> Int64 = { try LibraryMovePlanner.volumeCapacity($0) }) {
        self.fileManager = fileManager
        self.appDocuments = appDocuments
        self.libraryRoots = libraryRoots
        self.availableCapacity = availableCapacity
    }

    public func inspect(_ url: URL) throws -> LibraryFolderInspection {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LibraryFolderError.notADirectory(url.path)
        }
        let folders = LibraryMoveFolders.shared + LibraryMoveFolders.saves
        for root in libraryRoots() where Self.conflicts(url, withRoot: root, folders: folders) {
            throw LibraryFolderError.isCurrentRoot(url.path)
        }
        try probeWrite(url)
        let isUbiquitous = (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) ?? false
        let kind = Self.classify(path: Self.canonical(url), appDocumentsPath: Self.canonical(appDocuments), isUbiquitous: isUbiquitous)
        return LibraryFolderInspection(url: url.standardizedFileURL, kind: kind,
                                       hasManifest: LibraryManifest.exists(in: url, fileManager: fileManager),
                                       availableBytes: try availableCapacity(url))
    }

    static func classify(path: String, appDocumentsPath: String, isUbiquitous: Bool) -> LibraryFolderKind {
        if isUbiquitous || path.contains("/Mobile Documents/") { return .iCloudDrive }
        if path == appDocumentsPath || path.hasPrefix(appDocumentsPath + "/") { return .ownDocuments }
        if path.contains("/Containers/Data/Application/") { return .otherAppDocuments }
        return .filesFolder
    }

    /// `url` is the root, contains it, or is one of (or inside) the folders the library owns under it.
    /// A sibling subfolder of the root (`Documents/MyLib`) is fine (D12).
    static func conflicts(_ url: URL, withRoot root: URL, folders: [String]) -> Bool {
        let picked = canonical(url)
        let base = canonical(root)
        if picked == base || base.hasPrefix(picked + "/") { return true }
        return folders.contains { picked == base + "/" + $0 || picked.hasPrefix(base + "/" + $0 + "/") }
    }

    static func canonical(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private func probeWrite(_ url: URL) throws {
        let probe = url.appendingPathComponent(Self.probePrefix + UUID().uuidString, isDirectory: false)
        do {
            try Data().write(to: probe)
            try fileManager.removeItem(at: probe)
        } catch {
            try? fileManager.removeItem(at: probe)
            throw LibraryFolderError.notWritable(url.path)
        }
    }
}
```

- [ ] **Step 5: Lint and commit**

```bash
for f in PVLibrary/Sources/PVFileSystem/LibraryManifest.swift PVLibrary/Sources/PVFileSystem/LibraryFolderInspector.swift PVLibrary/Tests/PVLibraryTests/LibraryManifestTests.swift PVLibrary/Tests/PVLibraryTests/LibraryFolderInspectorTests.swift; do swiftlint lint --path "$f"; done
git add PVLibrary/Sources/PVFileSystem/LibraryManifest.swift PVLibrary/Sources/PVFileSystem/LibraryFolderInspector.swift PVLibrary/Tests/PVLibraryTests/LibraryManifestTests.swift PVLibrary/Tests/PVLibraryTests/LibraryFolderInspectorTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): library manifest and picked-folder inspector"
```

---

## Batch B — Engine and coordinator (Tasks 6–7)

### Task 6: Engine: picked-folder pairs, nested roots, journal v2, manifest at switch

**Files:**
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift` (`LibraryMoveRequest`)
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift`
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift`
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift` (only the `LibraryMoveEngine(...)` construction, so it compiles; Task 7 rewrites it)
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryMoveEngineTests.swift`, `LibraryMoveJournalTests.swift`; update the `switchLocation:` closures in `LibraryMoveEngineRecoveryTests.swift`, `LibraryMoveCleanupTests.swift`, `LibraryMoveCoordinatorTests.swift`.

**Interfaces:**
- Consumes: `PickedLibraryFolder`, `LibraryMoveFolders.shared/.saves` (Task 2), `LibraryManifest` (Task 5).
- Produces: `LibraryMoveRequest.init(source:destination:sourceRoot:destinationRoot:folders:keepCopy:sourceFolder:destinationFolder:deduplicateByMD5:)` (last three default to `nil`/`nil`/`false`); `LibraryMoveJournal.sourceFolder`, `.destinationFolder`, `.deduplicateByMD5: Bool?`, `.remaps: [String: String]?`, `currentVersion == 2`; `LibraryMoveEngine.init(journalStore:fileManager:md5Provider:planner:manifestAuthor:switchLocation:)` with `switchLocation: @Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void`; `LibraryMoveEngine.supportedMoves`.

- [ ] **Step 1: Write the failing tests.** Append to `LibraryMoveEngineTests.swift` (follow the file's existing helpers; where it builds an engine with `switchLocation: { recorder.switches.append($0) }`, the recorder now stores `(LibraryLocation, PickedLibraryFolder?)` tuples or two arrays — pick one and apply it to every test file that constructs an engine or coordinator):

```swift
    // MARK: - Picked folder (phase 3)

    private func pickedFolder(name: String = "Retro") -> PickedLibraryFolder {
        PickedLibraryFolder(bookmark: Data([1]), displayName: name, includesSaves: false)
    }

    func testAppStorageToPickedFolderCopiesTheSharedFoldersAndWritesTheManifest() async throws {
        try write(source, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(source, "BIOS/scph5501.bin", "bios")
        try write(source, "System/PSP/font.pgf", "font")
        try write(source, "Save States/Game/s.svs", "save")
        let folder = pickedFolder()
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: source, destinationRoot: destination,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: folder)
        let outcome = try await engine().start(request)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(destination, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertEqual(read(destination, "BIOS/scph5501.bin"), "bios")
        XCTAssertEqual(read(destination, "System/PSP/font.pgf"), "font")
        XCTAssertFalse(exists(destination, "Save States/Game/s.svs"))
        XCTAssertTrue(LibraryManifest.exists(in: destination))
        XCTAssertEqual(try LibraryManifest.read(from: destination).createdBy, "org.test.full")
        XCTAssertEqual(recorder.switchedFolders.last??.displayName, "Retro")
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.destinationFolder, folder)
        XCTAssertEqual(journal.version, 2)
    }

    func testJoiningKeepsAnExistingManifest() async throws {
        try write(destination, LibraryManifest.fileName, #"{"version":1,"createdBy":"com.ifly"}"#)
        try write(source, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: source, destinationRoot: destination,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder())
        _ = try await engine().start(request)
        XCTAssertEqual(try LibraryManifest.read(from: destination).createdBy, "com.ifly")
    }

    func testPickedFolderToAppStorageCarriesTheSourceFolderInTheJournal() async throws {
        try write(source, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let folder = pickedFolder()
        let request = LibraryMoveRequest(source: .pickedFolder, destination: .appStorage, sourceRoot: source, destinationRoot: destination,
                                         folders: LibraryMoveFolders.shared, keepCopy: true, sourceFolder: folder)
        XCTAssertEqual(try await engine().start(request), .switched)
        XCTAssertEqual(try XCTUnwrap(store.load()).sourceFolder, folder)
        XCTAssertEqual(recorder.switches.last, .appStorage)
        XCTAssertNil(recorder.switchedFolders.last ?? nil)
        XCTAssertFalse(LibraryManifest.exists(in: destination), "no manifest in App storage")
    }

    func testAppGroupToPickedFolderIsRefused() async {
        let request = LibraryMoveRequest(source: .appGroup, destination: .pickedFolder, sourceRoot: source, destinationRoot: destination,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder())
        do {
            _ = try await engine().start(request)
            XCTFail("expected unsupportedMove")
        } catch {
            XCTAssertEqual(error as? LibraryMoveError, .unsupportedMove(from: .appGroup, to: .pickedFolder))
        }
    }

    func testADestinationInsideTheSourceRootIsAllowedOutsideMovedFolders() async throws {
        // Review Focus 1 / D12: Documents/MyLib as the picked folder.
        try write(source, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let nested = source.appendingPathComponent("MyLib", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: source, destinationRoot: nested,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder())
        XCTAssertEqual(try await engine().start(request), .switched)
        XCTAssertEqual(read(nested, "ROMs/com.provenance.snes/Game.sfc"), "rom")
    }

    func testADestinationInsideAMovedFolderIsRefused() async throws {
        let inside = source.appendingPathComponent("ROMs/Lib", isDirectory: true)
        try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: source, destinationRoot: inside,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder())
        do {
            _ = try await engine().start(request)
            XCTFail("expected unsupportedMove")
        } catch {
            XCTAssertEqual(error as? LibraryMoveError, .unsupportedMove(from: .appStorage, to: .pickedFolder))
        }
    }
```

Append to `LibraryMoveJournalTests.swift`:

```swift
    func testVersionIsTwoAndAVersionOneJournalStillDecodes() throws {
        XCTAssertEqual(LibraryMoveJournal.currentVersion, 2)
        // Review Focus 5: the shape phase 2 wrote (no folder fields, no remaps).
        let v1 = """
        {"createdAt":780000000,"createdDirectories":[],"destination":"appStorage","entries":{},"folders":["ROMs"],"id":"\(UUID().uuidString)",
         "inFlight":[],"keepCopy":false,"phase":"copying","source":"appGroup","updatedAt":780000000,"version":1}
        """
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(v1.utf8).write(to: store.url)
        let journal = try XCTUnwrap(store.load())
        XCTAssertNil(journal.sourceFolder)
        XCTAssertNil(journal.destinationFolder)
        XCTAssertNil(journal.remaps)
        XCTAssertEqual(journal.deduplicateByMD5 ?? false, false)
    }

    func testFolderFieldsRoundTrip() throws {
        let folder = PickedLibraryFolder(bookmark: Data([9, 9]), displayName: "Retro", includesSaves: true, pickedAt: Date(timeIntervalSinceReferenceDate: 12.5))
        var journal = LibraryMoveJournal(request: .init(source: .appStorage, destination: .pickedFolder, sourceRoot: URL(fileURLWithPath: "/a"),
                                                        destinationRoot: URL(fileURLWithPath: "/b"), folders: ["ROMs"], keepCopy: false, destinationFolder: folder))
        journal.remaps = ["ROMs/x/A.sfc": "ROMs/x/B.sfc"]
        try store.save(journal)
        XCTAssertEqual(store.load(), journal)
    }
```

- [ ] **Step 2: `LibraryMoveRequest`** in `LibraryMoveTypes.swift`: add the three stored properties and extend the initializer with defaults.

```swift
    /// The picked folder being left (`source == .pickedFolder`); lets a resume after the switch re-resolve it.
    public let sourceFolder: PickedLibraryFolder?
    /// The picked folder being moved to (`destination == .pickedFolder`); stored by the switch.
    public let destinationFolder: PickedLibraryFolder?
    /// Phase 4: journal `ROMs/` and `BIOS/` files that already exist in the destination under another name instead of copying them.
    public let deduplicateByMD5: Bool

    public init(source: LibraryLocation, destination: LibraryLocation, sourceRoot: URL, destinationRoot: URL, folders: [String], keepCopy: Bool,
                sourceFolder: PickedLibraryFolder? = nil, destinationFolder: PickedLibraryFolder? = nil, deduplicateByMD5: Bool = false) {
```

- [ ] **Step 3: Journal v2** in `LibraryMoveJournal.swift`: `currentVersion = 2`; add after `createdDirectories`:

```swift
    /// Phase 3: the picked folders at each end, when either end is `.pickedFolder`.
    public var sourceFolder: PickedLibraryFolder?
    public var destinationFolder: PickedLibraryFolder?
    /// Phase 4: see `LibraryMoveRequest.deduplicateByMD5`. Optional so a version 1 journal decodes.
    public var deduplicateByMD5: Bool?
    /// Phase 4: source relative path → the destination relative path a de-duplicated file resolved to. The
    /// coordinator applies these to the database before cleanup deletes the sources.
    public var remaps: [String: String]?
```

and in `init(request:now:)`: `sourceFolder = request.sourceFolder; destinationFolder = request.destinationFolder; deduplicateByMD5 = request.deduplicateByMD5 ? true : nil; remaps = nil`.

- [ ] **Step 4: Engine.** In `LibraryMoveEngine.swift`:

```swift
    /// Pairs the engine knows how to move (D11). Phase 5 adds iCloud Drive both ways.
    static let supportedMoves: Set<[LibraryLocation]> = [
        [.appGroup, .appStorage],
        [.appStorage, .pickedFolder],
        [.pickedFolder, .appStorage],
        [.pickedFolder, .pickedFolder]
    ]

    /// Named as the creator of a shared folder's manifest (D14). The main bundle id in production.
    let manifestAuthor: String
    /// Writes the setting that names the destination (and stores or clears the picked folder).
    let switchLocation: @Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void

    public init(journalStore: LibraryMoveJournalStore,
                fileManager: FileManager = .default,
                md5Provider: any MD5Provider = FileManager.default,
                planner: LibraryMovePlanner = LibraryMovePlanner(),
                manifestAuthor: String = Bundle.main.bundleIdentifier ?? "",
                switchLocation: @escaping @Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void) {
```

`start` and `resume`: pass `folders:` to the root check — `try requireDistinctRoots(request.sourceRoot, request.destinationRoot, folders: request.folders, source:, destination:)` and `folders: journal.folders` on resume. `run(...)` calls `try performSwitch(&journal, destinationRoot: destinationRoot)`.

```swift
    /// Roots that are the same folder, or where one sits in a folder the move carries, would make every file
    /// "identical" (cleanup would then delete the only copy) or have the copy enumerate its own output.
    /// Nesting outside the moved folders is fine (`Documents/MyLib` as a picked folder, D12).
    private func requireDistinctRoots(_ sourceRoot: URL, _ destinationRoot: URL, folders: [String], source: LibraryLocation, destination: LibraryLocation) throws {
        let first = sourceRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let second = destinationRoot.resolvingSymlinksInPath().standardizedFileURL.path
        guard first != second,
              !Self.isInsideMovedFolder(inner: second, outer: first, folders: folders),
              !Self.isInsideMovedFolder(inner: first, outer: second, folders: folders) else {
            throw LibraryMoveError.unsupportedMove(from: source, to: destination)
        }
    }

    /// `inner` nested in `outer` is a problem only when its first component under `outer` is one of `folders`.
    static func isInsideMovedFolder(inner: String, outer: String, folders: [String]) -> Bool {
        let prefix = outer.hasSuffix("/") ? outer : outer + "/"
        guard inner.hasPrefix(prefix) else { return false }
        let first = inner.dropFirst(prefix.count).split(separator: "/", maxSplits: 1).first.map(String.init) ?? ""
        return folders.contains(first)
    }

    // MARK: - Switch

    func performSwitch(_ journal: inout LibraryMoveJournal, destinationRoot: URL) throws {
        if journal.destination == .pickedFolder {
            // After the copy verified, before the setting: a shared folder is marked as a library exactly once (D14).
            try LibraryManifest.writeIfAbsent(in: destinationRoot, createdBy: manifestAuthor, fileManager: fileManager)
        }
        try switchLocation(journal.destination, journal.destinationFolder)
        journal.phase = .switched
        journal.updatedAt = Date()
        try journalStore.save(journal)
        ILOG("LibraryMove: switched to \(journal.destination.rawValue); cleanup runs at the next launch")
    }
```

In `LibraryMoveCoordinator.swift`, only make it compile: the `LibraryMoveEngine(...)` construction passes `switchLocation: switchLocation` whose type must become `@Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void` (change the stored property, the `init` parameter and its default `{ try LibraryLocation.switchStored(to: $0, pickedFolder: $1) }`, and the one `try? switchLocation(journal.destination)` call to `try? switchLocation(journal.destination, journal.destinationFolder)`). Give the engine `manifestAuthor: variantID`.

- [ ] **Step 5: Update the other test files.** Every `switchLocation: { ... $0 ... }` closure in `LibraryMoveEngineTests`, `LibraryMoveEngineRecoveryTests`, `LibraryMoveCleanupTests` and `LibraryMoveCoordinatorTests` takes two parameters now. Use a shared recorder shape in each file:

```swift
    private final class Recorder: @unchecked Sendable {
        var switches: [LibraryLocation] = []
        var switchedFolders: [PickedLibraryFolder?] = []
        func record(_ location: LibraryLocation, _ folder: PickedLibraryFolder?) {
            switches.append(location)
            switchedFolders.append(folder)
        }
    }
    // switchLocation: { recorder.record($0, $1) }
```

Pass `manifestAuthor: "org.test.full"` where the engine tests build an engine.

- [ ] **Step 6: Lint and commit**

```bash
for f in PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveEngineTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveJournalTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveEngineRecoveryTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCleanupTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift; do swiftlint lint --path "$f"; done
git add PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveEngineTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveJournalTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveEngineRecoveryTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCleanupTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): engine moves to and from a picked folder"
```

### Task 7: Coordinator: picked-folder moves, preview, cancel, rebind, abandon

**Files:**
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift` (rewrite)
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift` (add `LibraryMovePreview`)
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces (all public): `LibraryMoveCoordinator.RootProvider = @Sendable (LibraryLocation, PickedLibraryFolder?) -> URL?`; `init(journalStore:rootProvider:launchedLocation:resumeLocation:launchedFolder:switchLocation:folderStore:planner:md5Provider:sharedDefaults:variantID:)`; `defaultRoot(for:folder:)`; `resumeIfNeeded(progress:)`; `moveToAppStorage(keepCopy:progress:)` (from `.appGroup` or `.pickedFolder`); `moveToPickedFolder(_:displayName:includeSaves:deduplicate:progress:)`; `preview(destinationRoot:includeSaves:) throws -> LibraryMovePreview`; `rebindPickedFolder(to:displayName:) throws`; `abandonPickedFolder() throws`; `cancelRunningMove()`; `static folders(includeSaves:)`. Task 10 adds `setPathRemapApplier`.

- [ ] **Step 1: Add `LibraryMovePreview`** to `LibraryMoveTypes.swift`:

```swift
/// What the confirmation sheet shows before a move starts.
public struct LibraryMovePreview: Sendable, Equatable {
    public let fileCount: Int
    public let totalBytes: Int64
    /// `totalBytes` plus the planner's headroom.
    public let requiredBytes: Int64
    public let availableBytes: Int64
    public var fits: Bool { availableBytes >= requiredBytes }

    public init(fileCount: Int, totalBytes: Int64, requiredBytes: Int64, availableBytes: Int64) {
        self.fileCount = fileCount
        self.totalBytes = totalBytes
        self.requiredBytes = requiredBytes
        self.availableBytes = availableBytes
    }
}
```

- [ ] **Step 2: Write the failing tests.** Rework `LibraryMoveCoordinatorTests.swift`'s fixture: add `picked` and `picked2` temp roots, a `Recorder` with `switches`/`switchedFolders` (Task 6 shape), a `PickedLibraryFolderStore` on the test suite (`key: "libraryPickedFolder"`), and this builder (replace the old one; existing tests keep passing with `launched: .appGroup` / `.appStorage`):

```swift
    /// - Parameters:
    ///   - launched: the launch axis (`appGroup`, `appStorage` or `pickedFolder`).
    ///   - launchedFolder: the stored picked folder when `launched == .pickedFolder`.
    ///   - live: what `LibraryLocation.current` reports (it also follows iCloud Drive mode); defaults to `launched`.
    private func coordinator(launched: LibraryLocation, launchedFolder: PickedLibraryFolder? = nil, live: LibraryLocation? = nil,
                             groupAvailable: Bool = true, variantID: String = LibraryMoveCoordinatorTests.thisApp) -> LibraryMoveCoordinator {
        let record = recorder
        let group = groupAvailable ? self.group : nil
        let local = self.local!, picked = self.picked!, picked2 = self.picked2!
        return LibraryMoveCoordinator(journalStore: store,
                                      rootProvider: { location, folder in
                                          switch location {
                                          case .appGroup: return group
                                          case .appStorage: return local
                                          case .iCloudDrive: return nil
                                          // Tests name picked roots by display name: "A" is `picked`, "B" is `picked2`.
                                          case .pickedFolder: return (folder ?? launchedFolder)?.displayName == "B" ? picked2 : picked
                                          }
                                      },
                                      launchedLocation: { live ?? launched },
                                      resumeLocation: { launched },
                                      launchedFolder: { launchedFolder },
                                      switchLocation: { record.record($0, $1) },
                                      folderStore: folderStore,
                                      planner: LibraryMovePlanner(availableCapacity: { _ in .max }),
                                      sharedDefaults: defaults,
                                      variantID: variantID)
    }

    private func folderA(includesSaves: Bool = false) -> PickedLibraryFolder {
        PickedLibraryFolder(bookmark: Data([1]), displayName: "A", includesSaves: includesSaves, pickedAt: Date(timeIntervalSinceReferenceDate: 1))
    }
```

New tests:

```swift
    // MARK: - Picked folder (phase 3)

    func testMoveToPickedFolderCopiesSharedFoldersOnly() async throws {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(local, "BIOS/x.bin", "bios")
        try write(local, "Save States/Game/s.svs", "save")
        try write(local, "Imports/new.zip", "zip")
        let c = coordinator(launched: .appStorage)
        let outcome = try await c.moveToPickedFolder(picked, displayName: "A", includeSaves: false)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(picked, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertEqual(read(picked, "BIOS/x.bin"), "bios")
        XCTAssertFalse(exists(picked, "Save States/Game/s.svs"))
        XCTAssertFalse(exists(picked, "Imports/new.zip"))
        XCTAssertTrue(LibraryManifest.exists(in: picked))
        XCTAssertEqual(recorder.switches, [.pickedFolder])
        let folder = try XCTUnwrap(recorder.switchedFolders.last ?? nil)
        XCTAssertEqual(folder.displayName, "A")
        XCTAssertFalse(folder.includesSaves)
        XCTAssertNoThrow(try LibraryFolderBookmark.resolve(folder.bookmark))
        XCTAssertEqual(try XCTUnwrap(store.load()).keepCopy, false)
    }

    func testIncludeSavesMovesTheSavesFoldersToo() async throws {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(local, "Save States/Game/s.svs", "save")
        try write(local, "Battery States/Game/g.sav", "sram")
        let c = coordinator(launched: .appStorage)
        _ = try await c.moveToPickedFolder(picked, displayName: "A", includeSaves: true)
        XCTAssertEqual(read(picked, "Save States/Game/s.svs"), "save")
        XCTAssertEqual(read(picked, "Battery States/Game/g.sav"), "sram")
        XCTAssertEqual((recorder.switchedFolders.last ?? nil)?.includesSaves, true)
    }

    func testMoveToPickedFolderFromAppGroupIsRefused() async throws {
        let c = coordinator(launched: .appGroup)
        do {
            _ = try await c.moveToPickedFolder(picked, displayName: "A", includeSaves: false)
            XCTFail("expected unsupportedMove")
        } catch {
            XCTAssertEqual(error as? LibraryMoveError, .unsupportedMove(from: .appGroup, to: .pickedFolder))
        }
        XCTAssertFalse(c.hasPendingMove)
    }

    func testMoveToPickedFolderWhileICloudDriveModeIsOnIsRefused() async throws {
        let c = coordinator(launched: .appStorage, live: .iCloudDrive)
        do {
            _ = try await c.moveToPickedFolder(picked, displayName: "A", includeSaves: false)
            XCTFail("expected unsupportedMove")
        } catch {
            XCTAssertEqual(error as? LibraryMoveError, .unsupportedMove(from: .iCloudDrive, to: .pickedFolder))
        }
    }

    func testLeavingAPickedFolderKeepsACopyAndCarriesItsSaves() async throws {
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(picked, "Save States/Game/s.svs", "save")
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA(includesSaves: true))
        XCTAssertEqual(try await c.moveToAppStorage(keepCopy: false), .switched)
        XCTAssertEqual(read(local, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertEqual(read(local, "Save States/Game/s.svs"), "save")
        let journal = try XCTUnwrap(store.load())
        XCTAssertTrue(journal.keepCopy, "the shared folder is left untouched")
        XCTAssertEqual(journal.sourceFolder?.displayName, "A")
        XCTAssertEqual(recorder.switches, [.appStorage])
        XCTAssertNil(recorder.switchedFolders.last ?? nil)
    }

    func testLeavingAPickedFolderWithoutSavesLeavesSavesAlone() async throws {
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(picked, "Save States/Game/s.svs", "someone else's")
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA(includesSaves: false))
        _ = try await c.moveToAppStorage()
        XCTAssertFalse(exists(local, "Save States/Game/s.svs"))
    }

    func testCleanupAfterLeavingResolvesTheOldFolderFromTheJournal() async throws {
        // The stored folder was cleared at the switch; the journal's sourceFolder names the old root.
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let leaving = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        _ = try await leaving.moveToAppStorage()
        let relaunched = coordinator(launched: .appStorage)
        XCTAssertEqual(await relaunched.resumeIfNeeded(progress: nil), .cleanedUp)
        XCTAssertEqual(read(picked, "ROMs/com.provenance.snes/Game.sfc"), "rom", "keep-copy: nothing deleted in the shared folder")
        XCTAssertFalse(relaunched.hasPendingMove)
    }

    func testMovingBetweenTwoPickedFoldersTellsThemApartByPick() async throws {
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let a = folderA()
        let c = coordinator(launched: .pickedFolder, launchedFolder: a)
        XCTAssertEqual(try await c.moveToPickedFolder(picked2, displayName: "B", includeSaves: false), .switched)
        XCTAssertEqual(read(picked2, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.sourceFolder, a)
        XCTAssertEqual(journal.destinationFolder?.displayName, "B")
        XCTAssertTrue(journal.keepCopy)

        // Relaunch still on A (the setting didn't stick): the switch is re-asserted, cleanup waits.
        let stillOnA = coordinator(launched: .pickedFolder, launchedFolder: a)
        XCTAssertNil(await stillOnA.resumeIfNeeded(progress: nil))
        XCTAssertEqual(recorder.switches.last, .pickedFolder)
        XCTAssertEqual((recorder.switchedFolders.last ?? nil)?.displayName, "B")

        // Relaunch on B: cleanup runs.
        let b = try XCTUnwrap(journal.destinationFolder)
        let onB = coordinator(launched: .pickedFolder, launchedFolder: b)
        XCTAssertEqual(await onB.resumeIfNeeded(progress: nil), .cleanedUp)
    }

    func testPreviewCountsTheFilesThatWouldMove() throws {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", bytes: 10)
        try write(local, "Save States/Game/s.svs", bytes: 5)
        let c = coordinator(launched: .appStorage)
        let withoutSaves = try c.preview(destinationRoot: picked, includeSaves: false)
        XCTAssertEqual(withoutSaves.fileCount, 1)
        XCTAssertEqual(withoutSaves.totalBytes, 10)
        XCTAssertEqual(withoutSaves.requiredBytes, LibraryMovePlanner.requiredBytes(for: 10))
        XCTAssertTrue(withoutSaves.fits)
        XCTAssertEqual(try c.preview(destinationRoot: picked, includeSaves: true).fileCount, 2)
    }

    func testRebindSavesAFreshBookmarkWithoutAMove() throws {
        try folderStore.save(folderA(includesSaves: true))
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA(includesSaves: true))
        try c.rebindPickedFolder(to: picked2, displayName: "Moved")
        XCTAssertEqual(recorder.switches, [.pickedFolder])
        let folder = try XCTUnwrap(recorder.switchedFolders.last ?? nil)
        XCTAssertEqual(folder.displayName, "Moved")
        XCTAssertTrue(folder.includesSaves, "inherited from the previous pick")
        XCTAssertFalse(c.hasPendingMove)
    }

    func testAbandonSwitchesToAppStorageWithoutAMove() throws {
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        try c.abandonPickedFolder()
        XCTAssertEqual(recorder.switches, [.appStorage])
        XCTAssertNil(recorder.switchedFolders.last ?? nil)
        XCTAssertFalse(c.hasPendingMove)
        XCTAssertThrowsError(try coordinator(launched: .appStorage).abandonPickedFolder())
    }
```

- [ ] **Step 3: Rewrite `LibraryMoveCoordinator.swift`.** Keep the header comment (update it: "the moves phase 2 and 3 support"), the shared-App-Group helpers (`variantKey`, `recordLaunchLocation`, `anotherVariantUsesAppGroup`, `keepingCopyWhileAnotherVariantUsesTheGroup`, `carryNewTopLevelEntries`) exactly as they are, and replace the rest with:

```swift
public final class LibraryMoveCoordinator: @unchecked Sendable {
    public static let shared = LibraryMoveCoordinator()

    public typealias RootProvider = @Sendable (LibraryLocation, PickedLibraryFolder?) -> URL?

    private let journalStore: LibraryMoveJournalStore?
    private let rootProvider: RootProvider
    /// The location the library resolves to (`LibraryLocation.current`); gates starting a move.
    private let launchedLocation: @Sendable () -> LibraryLocation
    /// The axis this process launched on (`LibraryLocation.launchAxis`). Ignores the live iCloud Drive setting.
    private let resumeLocation: @Sendable () -> LibraryLocation
    /// The picked folder this process launched on; `nil` unless `resumeLocation()` is `.pickedFolder`.
    private let launchedFolder: @Sendable () -> PickedLibraryFolder?
    private let switchLocation: @Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void
    private let folderStore: PickedLibraryFolderStore
    private let planner: LibraryMovePlanner
    private let engine: LibraryMoveEngine?
    private let sharedDefaults: UserDefaults?
    private let variantID: String

    public init(journalStore: LibraryMoveJournalStore? = LibraryMoveCoordinator.defaultJournalStore(),
                rootProvider: @escaping RootProvider = { LibraryMoveCoordinator.defaultRoot(for: $0, folder: $1) },
                launchedLocation: @escaping @Sendable () -> LibraryLocation = { LibraryLocation.current },
                resumeLocation: @escaping @Sendable () -> LibraryLocation = { LibraryLocation.launchAxis },
                launchedFolder: @escaping @Sendable () -> PickedLibraryFolder? = { LibraryLocation.launchAxis == .pickedFolder ? PickedLibraryFolderStore.shared.load() : nil },
                switchLocation: @escaping @Sendable (LibraryLocation, PickedLibraryFolder?) throws -> Void = { try LibraryLocation.switchStored(to: $0, pickedFolder: $1) },
                folderStore: PickedLibraryFolderStore = .shared,
                planner: LibraryMovePlanner = LibraryMovePlanner(),
                md5Provider: any MD5Provider = FileManager.default,
                sharedDefaults: UserDefaults? = UserDefaults(suiteName: PVAppGroupId),
                variantID: String = Bundle.main.bundleIdentifier ?? "") {
        self.journalStore = journalStore
        self.rootProvider = rootProvider
        self.launchedLocation = launchedLocation
        self.resumeLocation = resumeLocation
        self.launchedFolder = launchedFolder
        self.switchLocation = switchLocation
        self.folderStore = folderStore
        self.planner = planner
        self.sharedDefaults = sharedDefaults
        self.variantID = variantID
        self.engine = journalStore.map {
            LibraryMoveEngine(journalStore: $0, md5Provider: md5Provider, planner: planner, manifestAuthor: variantID, switchLocation: switchLocation)
        }
    }

    public static func defaultJournalStore() -> LibraryMoveJournalStore? { /* unchanged */ }

    /// The root of each location. A picked folder is resolved from `folder` (a journaled one) or, when `nil`, the
    /// one this process launched on. iCloud Drive is phase 5. Always `nil` on tvOS.
    public static func defaultRoot(for location: LibraryLocation, folder: PickedLibraryFolder?) -> URL? {
        #if os(tvOS)
        return nil
        #else
        switch location {
        case .appStorage: return URL.documentsPathLocal
        case .appGroup: return URL.documentsPathAppGroup
        case .iCloudDrive: return nil
        case .pickedFolder:
            if let folder {
                do {
                    return try LibraryFolderBookmark.resolve(folder.bookmark).url
                } catch {
                    ELOG("LibraryMove: the journaled folder \(folder.displayName) does not resolve: \(error.localizedDescription)")
                    return nil
                }
            }
            return LibraryLocation.pickedFolderAtLaunch.url
        }
        #endif
    }

    public var hasPendingMove: Bool { journalStore?.exists ?? false }

    /// Stops the running copy (before the switch). A no-op otherwise.
    public func cancelRunningMove() {
        engine?.cancel()
    }

    /// The folders a picked-folder move carries (D10).
    public static func folders(includeSaves: Bool) -> [String] {
        LibraryMoveFolders.shared + (includeSaves ? LibraryMoveFolders.saves : [])
    }

    /// `launched` is `location`, and for a picked folder the same pick (two picks of one folder differ by `pickedAt`).
    private func launchedOn(_ location: LibraryLocation, _ folder: PickedLibraryFolder?, launched: LibraryLocation) -> Bool {
        guard launched == location else { return false }
        guard location == .pickedFolder else { return true }
        return folder?.pickedAt == launchedFolder()?.pickedAt
    }

    @discardableResult
    public func resumeIfNeeded(progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async -> LibraryMoveOutcome? {
        #if os(tvOS)
        return nil
        #else
        let launched = resumeLocation()
        recordLaunchLocation(launched)
        guard let engine, var journal = journalStore?.load() else { return nil }
        guard let sourceRoot = rootProvider(journal.source, journal.sourceFolder),
              let destinationRoot = rootProvider(journal.destination, journal.destinationFolder) else {
            ELOG("LibraryMove: a root for \(journal.source.rawValue) → \(journal.destination.rawValue) is unavailable; keeping the journal")
            return nil
        }
        let onDestination = launchedOn(journal.destination, journal.destinationFolder, launched: launched)
        let onSource = launchedOn(journal.source, journal.sourceFolder, launched: launched)
        switch journal.phase {
        case .copying:
            if onDestination, journal.inFlight.isEmpty {
                // (same crash-window comment as today)
                journal.phase = .switched
                journal.updatedAt = Date()
                do {
                    try journalStore?.save(journal)
                } catch {
                    ELOG("LibraryMove: could not record the switch: \(error.localizedDescription)")
                    return nil
                }
            } else if !onSource {
                ELOG("LibraryMove: journal is mid-copy but this launch is on \(launched.rawValue); keeping the journal")
                return nil
            }
        case .switched, .cleaning:
            guard onDestination else {
                if onSource {
                    try? switchLocation(journal.destination, journal.destinationFolder)
                }
                ILOG("LibraryMove: switch recorded but this launch is still on \(launched.rawValue); cleanup waits for a relaunch")
                return nil
            }
        }
        if journal.phase != .copying {
            journal = carryNewTopLevelEntries(journal, sourceRoot: sourceRoot)
            journal = keepingCopyWhileAnotherVariantUsesTheGroup(journal)
        }
        do {
            return try await engine.resume(journal, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)
        } catch {
            ELOG("LibraryMove: resume failed: \(error.localizedDescription)")
            return nil
        }
        #endif
    }

    /// From the App Group (phase 2: every top-level entry) or from a picked folder (phase 3: the shared folders and,
    /// when that folder holds them, the saves folders; always keep a copy so the shared folder is left untouched).
    public func moveToAppStorage(keepCopy: Bool = false,
                                 progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        let source = launchedLocation()
        guard source == .appGroup || source == .pickedFolder else { throw LibraryMoveError.unsupportedMove(from: source, to: .appStorage) }
        guard let engine else { throw LibraryMoveError.rootUnavailable(.appStorage) }
        let sourceFolder = source == .pickedFolder ? launchedFolder() : nil
        guard let sourceRoot = rootProvider(source, sourceFolder) else { throw LibraryMoveError.rootUnavailable(source) }
        guard let destinationRoot = rootProvider(.appStorage, nil) else { throw LibraryMoveError.rootUnavailable(.appStorage) }
        let folders: [String]
        let keep: Bool
        if source == .appGroup {
            folders = try planner.topLevelEntries(at: sourceRoot)
            keep = keepCopy || anotherVariantUsesAppGroup()
        } else {
            folders = Self.folders(includeSaves: sourceFolder?.includesSaves ?? false)
            keep = true
        }
        let request = LibraryMoveRequest(source: source, destination: .appStorage, sourceRoot: sourceRoot, destinationRoot: destinationRoot,
                                         folders: folders, keepCopy: keep, sourceFolder: sourceFolder)
        return try await engine.start(request, progress: progress)
    }

    /// Moves the shared folders (and the saves folders when `includeSaves`) into `url`, a folder from the picker that
    /// `LibraryFolderInspector` accepted. From App storage, or from another picked folder (which then keeps a copy and
    /// whose `includesSaves` decides what moves). `deduplicate` is phase 4's join (D15).
    public func moveToPickedFolder(_ url: URL, displayName: String, includeSaves: Bool, deduplicate: Bool = false,
                                   progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        let source = launchedLocation()
        guard source == .appStorage || source == .pickedFolder else { throw LibraryMoveError.unsupportedMove(from: source, to: .pickedFolder) }
        guard let engine else { throw LibraryMoveError.rootUnavailable(.pickedFolder) }
        let sourceFolder = source == .pickedFolder ? launchedFolder() : nil
        guard let sourceRoot = rootProvider(source, sourceFolder) else { throw LibraryMoveError.rootUnavailable(source) }
        let saves = sourceFolder?.includesSaves ?? includeSaves
        let folder = PickedLibraryFolder(bookmark: try LibraryFolderBookmark.make(from: url), displayName: displayName, includesSaves: saves)
        let request = LibraryMoveRequest(source: source, destination: .pickedFolder, sourceRoot: sourceRoot, destinationRoot: url.standardizedFileURL,
                                         folders: Self.folders(includeSaves: saves), keepCopy: source == .pickedFolder,
                                         sourceFolder: sourceFolder, destinationFolder: folder, deduplicateByMD5: deduplicate)
        return try await engine.start(request, progress: progress)
    }

    /// What `moveToPickedFolder` would carry and whether `destinationRoot` has room.
    public func preview(destinationRoot: URL, includeSaves: Bool) throws -> LibraryMovePreview {
        let source = launchedLocation()
        let sourceFolder = source == .pickedFolder ? launchedFolder() : nil
        guard let sourceRoot = rootProvider(source, sourceFolder) else { throw LibraryMoveError.rootUnavailable(source) }
        let plan = try planner.plan(root: sourceRoot, folders: Self.folders(includeSaves: sourceFolder?.includesSaves ?? includeSaves))
        return LibraryMovePreview(fileCount: plan.items.count, totalBytes: plan.totalBytes,
                                  requiredBytes: LibraryMovePlanner.requiredBytes(for: plan.totalBytes),
                                  availableBytes: try planner.availableCapacity(destinationRoot))
    }

    /// The saved folder no longer resolves and the user pointed at where it is now. A fresh bookmark; no files move;
    /// applies at the next launch.
    public func rebindPickedFolder(to url: URL, displayName: String) throws {
        guard resumeLocation() == .pickedFolder else { throw LibraryMoveError.unsupportedMove(from: resumeLocation(), to: .pickedFolder) }
        let previous = launchedFolder() ?? folderStore.load()
        let folder = PickedLibraryFolder(bookmark: try LibraryFolderBookmark.make(from: url), displayName: displayName,
                                         includesSaves: previous?.includesSaves ?? false)
        try switchLocation(.pickedFolder, folder)
    }

    /// The saved folder is gone for good: back to App storage without a move. Records stay and show as missing.
    public func abandonPickedFolder() throws {
        guard resumeLocation() == .pickedFolder else { throw LibraryMoveError.unsupportedMove(from: resumeLocation(), to: .appStorage) }
        try switchLocation(.appStorage, nil)
    }

    // MARK: - Shared App Group  (unchanged helpers follow)
```

- [ ] **Step 4: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift
swiftlint lint --path PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift
git add PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): coordinator moves to, from and between picked folders"
```

---

## Batch C — Settings UI and rescans (Tasks 8, 11)

### Task 8: Settings › Library › Storage Location, folder picker, confirmation, progress, recovery

**Files:**
- Create: `PVUI/Sources/PVSwiftUI/Settings/ViewModels/LibraryStorageViewModel.swift`
- Create: `PVUI/Sources/PVSwiftUI/Settings/Views/LibraryStorageView.swift`
- Modify: `PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift` (`LibrarySection2`, first row, `#if !os(tvOS)`)
- Modify: `PVUI/Sources/PVSwiftUI/Settings/SettingsSearchIndex+Entries.swift` (one entry)
- Modify: `PVUI/Sources/PVSwiftUI/App Delegate/MainUI/MainView.swift` (launch alert)

**Interfaces:**
- Consumes: `LibraryLocation.current`, `.pickedFolderAtLaunch`, `.launchAxis`, `PickedLibraryFolderStore.shared`, `LibraryFolderInspector`, `LibraryMoveCoordinator` (`preview`, `moveToPickedFolder(deduplicate:)`, `moveToAppStorage`, `cancelRunningMove`, `rebindPickedFolder`, `abandonPickedFolder`, `hasPendingMove`), `LibraryMoveProgress`, `LibraryMoveOutcome`. `PVLibrary` re-exports `PVFileSystem`, so `import PVLibrary` suffices.
- Produces: `LibraryStorageView` (pushed from Settings), `LibraryStorageViewModel`, `LibraryFolderPicker` (private representable), `LibraryFolderUnavailableAlert` view modifier used by `MainView`.

No unit tests (PVUI tests are not run by agents; keep every decision in the view model so it reads like a state machine). Mirror the container styling of `BackupRestoreView.swift` (same folder) for the page; use `SettingsRow` for rows and `ThemedToggle` for the saves toggle.

- [ ] **Step 1: View model** (`LibraryStorageViewModel.swift`)

```swift
//
//  LibraryStorageViewModel.swift
//  PVSwiftUI
//
//  State for Settings › Library › Storage Location: pick → inspect → confirm → move → relaunch, plus the
//  recovery actions when the picked folder is unavailable. tvOS has no folder picker; the view is iOS-only.
//

#if !os(tvOS)
import Foundation
import Observation
import PVLibrary
import PVLogging

@MainActor
@Observable
final class LibraryStorageViewModel {
    enum Step: Equatable {
        case idle
        case inspecting
        case confirming(LibraryFolderInspection, LibraryMovePreview)
        case moving(LibraryMoveProgress)
        case relaunchRequired
        case failed(String)
    }

    private(set) var step: Step = .idle
    /// "Also move saves" in the confirmation sheet. Forced to the source folder's value when leaving a picked folder (D11).
    var includeSaves = false
    let location = LibraryLocation.current
    let launchAxis = LibraryLocation.launchAxis
    let launchState = LibraryLocation.pickedFolderAtLaunch
    let folder = PickedLibraryFolderStore.shared.load()
    private(set) var hasPendingMove = LibraryMoveCoordinator.shared.hasPendingMove
    private var pendingURL: URL?
    private var runID = UUID()

    /// Picked-folder moves are refused while iCloud Drive mode is on (phase 5) and from the App Group (D11).
    var canChooseFolder: Bool { location == .appStorage || location == .pickedFolder }
    var canMoveToAppStorage: Bool { location == .appGroup || location == .pickedFolder }
    var includeSavesIsLocked: Bool { launchAxis == .pickedFolder }

    var locationTitle: String {
        switch location {
        case .appStorage: return "App storage"
        case .appGroup: return "App Group (legacy)"
        case .iCloudDrive: return "iCloud Drive"
        case .pickedFolder: return folder?.displayName ?? "Chosen folder"
        }
    }

    var locationDetail: String {
        switch location {
        case .pickedFolder:
            if case .unavailable(let reason) = launchState { return "Unavailable: \(reason)" }
            return launchState.url?.path ?? ""
        case .iCloudDrive: return "Turn off iCloud Drive mode in Cloud Sync Settings to choose a folder."
        case .appGroup: return "Move to App storage first to choose a folder."
        case .appStorage: return "On My iPhone › Provenance"
        }
    }

    // MARK: - Pick → inspect → confirm

    func folderPicked(_ url: URL) {
        step = .inspecting
        includeSaves = includeSavesIsLocked ? (folder?.includesSaves ?? false) : includeSaves
        let saves = includeSaves
        Task.detached(priority: .userInitiated) {
            do {
                let inspection = try LibraryFolderInspector().inspect(url)
                let preview = try LibraryMoveCoordinator.shared.preview(destinationRoot: inspection.url, includeSaves: saves)
                await MainActor.run { self.pendingURL = inspection.url; self.step = .confirming(inspection, preview) }
            } catch {
                await MainActor.run { self.step = .failed(error.localizedDescription) }
            }
        }
    }

    func refreshPreview() {
        guard case .confirming(let inspection, _) = step else { return }
        let saves = includeSaves
        Task.detached(priority: .userInitiated) {
            let preview = try? LibraryMoveCoordinator.shared.preview(destinationRoot: inspection.url, includeSaves: saves)
            await MainActor.run {
                if let preview, case .confirming = self.step { self.step = .confirming(inspection, preview) }
            }
        }
    }

    func dismissConfirmation() {
        pendingURL = nil
        step = .idle
    }

    /// Starts the move (or the join when the folder already has a manifest).
    func confirmMove() {
        guard case .confirming(let inspection, _) = step, let url = pendingURL else { return }
        run { progress in
            try await LibraryMoveCoordinator.shared.moveToPickedFolder(url, displayName: url.lastPathComponent, includeSaves: self.includeSaves,
                                                                       deduplicate: inspection.hasManifest, progress: progress)
        }
    }

    func moveToAppStorage() {
        run { progress in try await LibraryMoveCoordinator.shared.moveToAppStorage(progress: progress) }
    }

    func cancel() {
        LibraryMoveCoordinator.shared.cancelRunningMove()
    }

    private func run(_ move: @escaping @Sendable (@escaping @Sendable (LibraryMoveProgress) -> Void) async throws -> LibraryMoveOutcome) {
        let token = UUID()
        runID = token
        step = .moving(LibraryMoveProgress(phase: .copying, filesDone: 0, filesTotal: 0, bytesDone: 0, bytesTotal: 0))
        Task { @MainActor in
            do {
                let outcome = try await move { report in
                    Task { @MainActor in
                        if self.runID == token { self.step = .moving(report) }
                    }
                }
                runID = UUID()
                hasPendingMove = LibraryMoveCoordinator.shared.hasPendingMove
                switch outcome {
                case .switched: step = .relaunchRequired
                case .cancelled: step = .failed("Move cancelled. Nothing was changed.")
                case .cleanedUp: step = .idle
                }
            } catch {
                runID = UUID()
                hasPendingMove = LibraryMoveCoordinator.shared.hasPendingMove
                step = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Recovery (folder unavailable at launch)

    func rebind(to url: URL) {
        do {
            try LibraryMoveCoordinator.shared.rebindPickedFolder(to: url, displayName: url.lastPathComponent)
            step = .relaunchRequired
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    func abandon() {
        do {
            try LibraryMoveCoordinator.shared.abandonPickedFolder()
            step = .relaunchRequired
        } catch {
            step = .failed(error.localizedDescription)
        }
    }
}
#endif
```

- [ ] **Step 2: The view** (`LibraryStorageView.swift`). Structure, top to bottom; copy per spec § "Settings UI":

```swift
#if !os(tvOS)
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PVLibrary
import PVThemes
import PVUIBase

struct LibraryStorageView: View {
    @State private var model = LibraryStorageViewModel()
    @State private var showsPicker = false
    @State private var showsRecoveryPicker = false

    var body: some View {
        List {
            Section("Current location") {
                SettingsRow(title: model.locationTitle, subtitle: model.locationDetail, icon: .sfSymbol("folder"), showChevron: false)
                if model.hasPendingMove {
                    Text("A move is waiting for a relaunch. Quit and reopen Provenance to finish it.")
                        .font(.footnote)
                }
            }

            if model.launchState.isUnavailable {
                Section("Library folder unavailable") {
                    Button("Choose Folder…") { showsRecoveryPicker = true }
                    Button("Use App Storage") { model.abandon() }
                    Text("Your games stay in the library and show as missing until the folder is back or you rescan.")
                        .font(.footnote)
                }
            }

            Section("Choose a location") {
                Button { showsPicker = true } label: {
                    SettingsRow(title: "Choose a folder…", subtitle: "Share ROMs and BIOS files with iCube and iFly through a folder in Files.",
                                icon: .sfSymbol("folder.badge.plus"))
                }
                .disabled(!model.canChooseFolder || model.hasPendingMove)
                Button { model.moveToAppStorage() } label: {
                    SettingsRow(title: "Use App storage", subtitle: "Copy the library back into On My iPhone › Provenance.",
                                icon: .sfSymbol("iphone"))
                }
                .disabled(!model.canMoveToAppStorage || model.hasPendingMove)
                NavigationLink(destination: CloudSyncSettingsView()) {
                    SettingsRow(title: "iCloud Drive", subtitle: "Managed in Cloud Sync Settings.", icon: .sfSymbol("icloud"))
                }
            } footer: {
                Text("Core settings files always stay in On My iPhone › Provenance.")
            }

            if model.location == .pickedFolder {
                Section {
                    Button { NotificationCenter.default.post(name: .PVReimportLibrary, object: nil) } label: {
                        SettingsRow(title: "Rescan Library", subtitle: "Pick up files other apps added to or removed from the folder.",
                                    icon: .sfSymbol("arrow.clockwise"))
                    }
                }
            }
        }
        .navigationTitle("Storage Location")
        .sheet(isPresented: $showsPicker) { LibraryFolderPicker { model.folderPicked($0) } }
        .sheet(isPresented: $showsRecoveryPicker) { LibraryFolderPicker { model.rebind(to: $0) } }
        .sheet(isPresented: Binding(get: { if case .confirming = model.step { return true }; return false },
                                    set: { if !$0 { model.dismissConfirmation() } })) {
            LibraryMoveConfirmationSheet(model: model)
        }
        .overlay { if case .moving(let progress) = model.step { LibraryMoveProgressOverlay(progress: progress, cancel: model.cancel) } }
        .alert("Library moved", isPresented: Binding(get: { model.step == .relaunchRequired }, set: { _ in })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Quit and reopen Provenance to finish. The old files are removed on the next launch.")
        }
        .alert("Couldn't move the library", isPresented: Binding(get: { if case .failed = model.step { return true }; return false },
                                                                 set: { if !$0 { model.dismissConfirmation() } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if case .failed(let message) = model.step { Text(message) }
        }
    }
}

/// `UIDocumentPickerViewController(forOpeningContentTypes: [.folder])`: returns a security-scoped URL.
private struct LibraryFolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}

/// What will move, the space it needs, the saves toggle, and the warnings for the folder kind (D16).
private struct LibraryMoveConfirmationSheet: View {
    @Bindable var model: LibraryStorageViewModel

    var body: some View {
        if case .confirming(let inspection, let preview) = model.step {
            NavigationStack {
                List {
                    Section(inspection.hasManifest ? "Join this library" : "Move the library") {
                        Text(inspection.url.lastPathComponent).font(.headline)
                        Text(inspection.hasManifest
                             ? "This folder is already a Provenance library. Your files are added to it; files it already has are not copied twice."
                             : "ROMs, BIOS and System files move into this folder.")
                        LabeledContent("Files", value: "\(preview.fileCount)")
                        LabeledContent("Needs", value: ByteCountFormatter.string(fromByteCount: preview.requiredBytes, countStyle: .file))
                        LabeledContent("Free", value: ByteCountFormatter.string(fromByteCount: preview.availableBytes, countStyle: .file))
                    }
                    Section {
                        ThemedToggle(isOn: $model.includeSaves) {
                            SettingsRow(title: "Also move saves", subtitle: "Save states, battery saves, screenshots, cheats and patches. Off by default: other apps' cores use different formats.",
                                        showChevron: false)
                        }
                        .disabled(model.includeSavesIsLocked)
                        .onChange(of: model.includeSaves) { model.refreshPreview() }
                    }
                    if inspection.kind == .otherAppDocuments {
                        Section { Text("This folder belongs to another app. It disappears if that app is deleted.").foregroundStyle(.orange) }
                    }
                    if inspection.kind == .iCloudDrive {
                        Section { Text("Files in iCloud Drive may need to download before a game can start.") }
                    }
                    if !preview.fits {
                        Section { Text("Not enough free space in this folder.").foregroundStyle(.red) }
                    }
                }
                .navigationTitle("Storage Location")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.dismissConfirmation() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(inspection.hasManifest ? "Join" : "Move") { model.confirmMove() }.disabled(!preview.fits)
                    }
                }
            }
        }
    }
}

private struct LibraryMoveProgressOverlay: View {
    let progress: LibraryMoveProgress
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress.fraction)
            Text(progress.currentPath ?? "Preparing…").font(.footnote).lineLimit(1)
            Text("\(progress.filesDone) of \(progress.filesTotal) files")
            if progress.phase == .copying {
                Button("Cancel", role: .cancel, action: cancel)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}

/// Shown once per launch, from `MainView`, when the stored picked folder could not be opened (D9).
struct LibraryFolderUnavailableAlert: ViewModifier {
    @State private var isPresented = LibraryLocation.pickedFolderAtLaunch.isUnavailable
    @State private var showsPicker = false
    @State private var showsRelaunch = false
    @State private var model = LibraryStorageViewModel()

    func body(content: Content) -> some View {
        content
            .alert("Library folder unavailable", isPresented: $isPresented) {
                Button("Choose Folder…") { showsPicker = true }
                Button("Use App Storage") { model.abandon(); showsRelaunch = true }
                Button("Later", role: .cancel) {}
            } message: {
                if case .unavailable(let reason) = LibraryLocation.pickedFolderAtLaunch { Text(reason) }
            }
            .sheet(isPresented: $showsPicker) { LibraryFolderPicker { model.rebind(to: $0); showsRelaunch = true } }
            .alert("Relaunch required", isPresented: $showsRelaunch) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Quit and reopen Provenance to use the new location.")
            }
    }
}
#endif
```

- [ ] **Step 3: Wire the row, the search entry and the launch alert.**

In `LibrarySection2` (`SettingsSwiftUI.swift`), as the first row inside `#if !os(tvOS)`:

```swift
            NavigationLink(destination: LibraryStorageView()) {
                SettingsRow(title: "Storage Location",
                            subtitle: "App storage, iCloud Drive, or a folder you choose in Files.",
                            icon: .sfSymbol("externaldrive"))
            }
```

In `SettingsSearchIndex+Entries.swift`, next to `library.migration`:

```swift
        entry("library.storage", "Storage Location", "App storage, iCloud Drive, or a folder you choose in Files.",
              .general, SettingsSectionTitle.libraryManagement, keywords: ["folder", "files", "storage", "move", "share", "icube", "ifly", "roms", "bios"], tvOS: false),
```

(use whatever parameter the `entry(...)` helper already takes for "not on tvOS"; read the helper's signature first).

In `MainView.swift`, apply `.modifier(LibraryFolderUnavailableAlert())` to the outermost view inside `body` under `#if !os(tvOS)`.

- [ ] **Step 4: Lint and commit**

```bash
for f in PVUI/Sources/PVSwiftUI/Settings/ViewModels/LibraryStorageViewModel.swift PVUI/Sources/PVSwiftUI/Settings/Views/LibraryStorageView.swift PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift PVUI/Sources/PVSwiftUI/Settings/SettingsSearchIndex+Entries.swift "PVUI/Sources/PVSwiftUI/App Delegate/MainUI/MainView.swift"; do swiftlint lint --path "$f"; done
git add PVUI/Sources/PVSwiftUI/Settings/ViewModels/LibraryStorageViewModel.swift PVUI/Sources/PVSwiftUI/Settings/Views/LibraryStorageView.swift PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift PVUI/Sources/PVSwiftUI/Settings/SettingsSearchIndex+Entries.swift "PVUI/Sources/PVSwiftUI/App Delegate/MainUI/MainView.swift"
git -c commit.gpgsign=false commit -m "feat(settings): Storage Location screen with folder picker and recovery"
```

### Task 11: Rescan triggers and missing-file status for a picked folder

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/RescanThrottle.swift`
- Create: `PVUI/Sources/PVUIBase/Game Library/LibraryRescanRequester.swift`
- Modify: `PVUI/Sources/PVSwiftUI/App Delegate/PVAppDelegate.swift` (`applicationWillEnterForeground`, the `.PVReimportLibrary` handler)
- Test: `PVLibrary/Tests/PVLibraryTests/RescanThrottleTests.swift`

**Interfaces:**
- Consumes: `LibraryLocation.current`, `GameFileStatusService.shared.refreshAllStatuses()` (PVLibrary, exists), `.PVReimportLibrary`.
- Produces: `RescanThrottle` (pure), `LibraryRescanRequester.shared.requestRescan()`.

- [ ] **Step 1: Write the failing throttle test**

```swift
//
//  RescanThrottleTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class RescanThrottleTests: XCTestCase {
    func testFiresOnceThenWaitsForTheInterval() {
        var throttle = RescanThrottle(interval: 60)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        XCTAssertTrue(throttle.shouldFire(now: start))
        XCTAssertFalse(throttle.shouldFire(now: start.addingTimeInterval(59)))
        XCTAssertTrue(throttle.shouldFire(now: start.addingTimeInterval(60)))
        XCTAssertFalse(throttle.shouldFire(now: start.addingTimeInterval(61)))
    }

    func testDefaultIntervalIsAMinute() {
        XCTAssertEqual(RescanThrottle.defaultInterval, 60)
    }
}
```

- [ ] **Step 2: Implement**

`RescanThrottle.swift` (PVFileSystem):

```swift
//
//  RescanThrottle.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Rate limit for library rescans triggered by foregrounding or iCloud metadata updates (D17).
//

import Foundation

public struct RescanThrottle: Sendable {
    public static let defaultInterval: TimeInterval = 60

    private let interval: TimeInterval
    private var last: Date?

    public init(interval: TimeInterval = RescanThrottle.defaultInterval) {
        self.interval = interval
    }

    /// `true` at most once per `interval`.
    public mutating func shouldFire(now: Date = Date()) -> Bool {
        if let last, now.timeIntervalSince(last) < interval { return false }
        last = now
        return true
    }
}
```

`LibraryRescanRequester.swift` (PVUIBase):

```swift
//
//  LibraryRescanRequester.swift
//  PVUIBase
//
//  Posts `.PVReimportLibrary` (the existing "Scan ROM Directories" path) at most once a minute, for the
//  triggers a picked folder needs: foregrounding and iCloud metadata updates (D17).
//

import Foundation
import PVLibrary
import PVLogging

@MainActor
public final class LibraryRescanRequester {
    public static let shared = LibraryRescanRequester()

    private var throttle = RescanThrottle()

    private init() {}

    /// Only while the library lives in a picked folder; App storage has no outside writers.
    public func requestRescan(reason: String) {
        guard LibraryLocation.current == .pickedFolder else { return }
        guard throttle.shouldFire() else {
            DLOG("LibraryRescan: \(reason) throttled")
            return
        }
        ILOG("LibraryRescan: \(reason)")
        NotificationCenter.default.post(name: .PVReimportLibrary, object: nil)
    }
}
```

In `PVAppDelegate.applicationWillEnterForeground`, inside the existing `Task { @MainActor in ... }` add `LibraryRescanRequester.shared.requestRescan(reason: "foreground")` under `#if !os(tvOS)`.

In the `.PVReimportLibrary` handler (`_initLibraryNotificationHandlers`), right after `await updatesController.importROMDirectories()`:

```swift
                        if LibraryLocation.current == .pickedFolder {
                            // Review Focus 3: a ROM another app removed shows as missing, never as gone.
                            _ = await GameFileStatusService.shared.refreshAllStatuses()
                        }
```

- [ ] **Step 3: Lint and commit**

```bash
for f in PVLibrary/Sources/PVFileSystem/RescanThrottle.swift "PVUI/Sources/PVUIBase/Game Library/LibraryRescanRequester.swift" "PVUI/Sources/PVSwiftUI/App Delegate/PVAppDelegate.swift" PVLibrary/Tests/PVLibraryTests/RescanThrottleTests.swift; do swiftlint lint --path "$f"; done
git add PVLibrary/Sources/PVFileSystem/RescanThrottle.swift "PVUI/Sources/PVUIBase/Game Library/LibraryRescanRequester.swift" "PVUI/Sources/PVSwiftUI/App Delegate/PVAppDelegate.swift" PVLibrary/Tests/PVLibraryTests/RescanThrottleTests.swift
git -c commit.gpgsign=false commit -m "feat(library): rescan a picked folder on foreground and mark missing files"
```

---

## Batch D — Shared library: join, remap, iCloud watcher, docs (Tasks 9, 10, 12, 13)

### Task 9: MD5 de-duplication when joining a shared library

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/LibraryMove/SharedLibraryIndex.swift`
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift` (`Entry.State.deduplicated`)
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift` (store `md5Provider`; copy loop; rollback)
- Test: `PVLibrary/Tests/PVLibraryTests/SharedLibraryIndexTests.swift`, `LibraryMoveEngineTests.swift`, `LibraryMoveCleanupTests.swift`

**Interfaces:**
- Consumes: `LibraryMoveRequest.deduplicateByMD5`, `LibraryMoveJournal.deduplicateByMD5/.remaps` (Task 6), `MD5Provider`.
- Produces: `SharedLibraryIndex(root:folders:fileManager:md5Provider:) throws`, `mutating func match(size:md5:excluding:) -> String?`; `LibraryMoveJournal.Entry.State.deduplicated` (raw `"deduplicated"`).

- [ ] **Step 1: Write the failing index tests**

```swift
//
//  SharedLibraryIndexTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class SharedLibraryIndexTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = try LibraryMoveTestSupport.makeTempDirectory(named: "SharedLibraryIndexTests")
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(root)
    }

    private func index() throws -> SharedLibraryIndex {
        try SharedLibraryIndex(root: root, folders: ["ROMs", "BIOS"], fileManager: .default, md5Provider: FileManager.default)
    }

    func testMatchesBySizeThenMD5UnderAnotherName() throws {
        try LibraryMoveTestSupport.write(root, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        try LibraryMoveTestSupport.write(root, "ROMs/com.provenance.snes/Other.sfc", "diff bytes")
        var index = try index()
        let md5 = try XCTUnwrap(FileManager.default.md5ForFile(at: root.appendingPathComponent("ROMs/com.provenance.snes/Game (USA).sfc"), fromOffset: 0))
        XCTAssertEqual(index.match(size: 10, md5: md5, excluding: "ROMs/com.provenance.snes/Game.sfc"), "ROMs/com.provenance.snes/Game (USA).sfc")
        XCTAssertNil(index.match(size: 10, md5: "0000", excluding: "ROMs/x"))
        XCTAssertNil(index.match(size: 3, md5: md5, excluding: "ROMs/x"))
    }

    func testTheSamePathIsNeverAMatch() throws {
        try LibraryMoveTestSupport.write(root, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        var index = try index()
        let md5 = try XCTUnwrap(FileManager.default.md5ForFile(at: root.appendingPathComponent("ROMs/com.provenance.snes/Game.sfc"), fromOffset: 0))
        XCTAssertNil(index.match(size: 10, md5: md5, excluding: "ROMs/com.provenance.snes/Game.sfc"))
    }

    func testOnlyTheListedFoldersAreIndexed() throws {
        try LibraryMoveTestSupport.write(root, "Save States/x/s.svs", "same bytes")
        try LibraryMoveTestSupport.write(root, "Conflicts/ROMs/x/y.sfc", "same bytes")
        var index = try index()
        XCTAssertNil(index.match(size: 10, md5: "any", excluding: ""))
    }

    func testMissingFoldersAreFine() throws {
        XCTAssertNoThrow(try index())
    }
}
```

- [ ] **Step 2: Write `SharedLibraryIndex.swift`**

```swift
//
//  SharedLibraryIndex.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The destination's `ROMs/` and `BIOS/` files grouped by size, with MD5s computed only on a size match, so
//  joining a shared library can recognise a ROM it already holds under another name (D15).
//

import Foundation
import PVHashing

struct SharedLibraryIndex {
    private let root: URL
    private let md5Provider: any MD5Provider
    /// Size → relative paths under `root`.
    private var bySize: [Int64: [String]] = [:]
    /// Relative path → MD5, filled on demand.
    private var md5s: [String: String] = [:]

    init(root: URL, folders: [String], fileManager: FileManager, md5Provider: any MD5Provider) throws {
        self.root = root
        self.md5Provider = md5Provider
        for folder in folders {
            let top = root.appendingPathComponent(folder, isDirectory: true)
            guard fileManager.fileExists(atPath: top.path),
                  let enumerator = fileManager.enumerator(at: top, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true, let relative = LibraryMovePlanner.relativePath(of: url, under: root) else { continue }
                bySize[Int64(values.fileSize ?? 0), default: []].append(relative)
            }
        }
    }

    /// A file of the same size and MD5 at a path other than `excluding`, or `nil`.
    mutating func match(size: Int64, md5: String, excluding relativePath: String) -> String? {
        for candidate in bySize[size] ?? [] where candidate != relativePath {
            if md5s[candidate] == nil {
                md5s[candidate] = md5Provider.md5ForFile(at: root.appendingPathComponent(candidate), fromOffset: 0) ?? ""
            }
            if md5s[candidate] == md5 { return candidate }
        }
        return nil
    }
}
```

- [ ] **Step 3: Journal state and engine.** In `LibraryMoveJournal.Entry.State` add:

```swift
            /// Joining a shared library: the destination already holds the file under `destinationPath`; nothing was
            /// copied, and `LibraryMoveJournal.remaps` points the record at it. Cleanup deletes the source like `identical`.
            case deduplicated
```

In the engine: keep `md5Provider` as a stored `let` (set in `init`). In `copyPhase`, before the batch loop:

```swift
        var sharedIndex: SharedLibraryIndex? = (journal.deduplicateByMD5 ?? false)
            ? try SharedLibraryIndex(root: destinationRoot, folders: Array(LibraryMoveFolders.md5Verified), fileManager: fileManager, md5Provider: md5Provider)
            : nil
```

Inside the per-item `do`, before `copier.transfer`:

```swift
                    if sharedIndex != nil, LibraryMoveFileCopier.needsMD5(item.relativePath), !exists(item.relativePath, under: destinationRoot),
                       let md5 = md5Provider.md5ForFile(at: sourceRoot.appendingPathComponent(item.relativePath), fromOffset: 0),
                       let shared = sharedIndex?.match(size: item.size, md5: md5, excluding: item.relativePath) {
                        journal.entries[item.relativePath] = .init(size: item.size, md5: md5, modified: item.modified, state: .deduplicated, destinationPath: shared)
                        journal.remaps = (journal.remaps ?? [:]).merging([item.relativePath: shared]) { _, new in new }
                        bytesDone += item.size
                    } else if let entry = try copier.transfer(item, from: sourceRoot, to: destinationRoot, onConflict: .displaceExisting) {
                        // … existing body …
                    }
```

(`sharedIndex` is a `var` because `match` is `mutating`; write it as `if var index = sharedIndex, … let shared = index.match(…) { sharedIndex = index; … }` if the compiler objects to mutating through the optional.)

In `rollback`, change the loop filter to `where entry.state != .identical && entry.state != .deduplicated` (nothing of ours is at the shared path). `deleteSources` already verifies `entry.destinationPath ?? relativePath` by size, so a de-duplicated source is deleted once the shared copy verifies.

- [ ] **Step 4: Engine and cleanup tests.** Append to `LibraryMoveEngineTests.swift`:

```swift
    // MARK: - Join (phase 4)

    private func joinRequest(deduplicate: Bool = true) -> LibraryMoveRequest {
        LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: source, destinationRoot: destination,
                           folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder(), deduplicateByMD5: deduplicate)
    }

    func testJoinRecordsASharedCopyUnderAnotherNameInsteadOfCopying() async throws {
        try write(destination, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        try write(source, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        try write(source, "ROMs/com.provenance.snes/New.sfc", "new")
        XCTAssertEqual(try await engine().start(joinRequest()), .switched)
        XCTAssertFalse(exists(destination, "ROMs/com.provenance.snes/Game.sfc"))
        XCTAssertEqual(read(destination, "ROMs/com.provenance.snes/New.sfc"), "new")
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.entries["ROMs/com.provenance.snes/Game.sfc"]?.state, .deduplicated)
        XCTAssertEqual(journal.entries["ROMs/com.provenance.snes/Game.sfc"]?.destinationPath, "ROMs/com.provenance.snes/Game (USA).sfc")
        XCTAssertEqual(journal.remaps, ["ROMs/com.provenance.snes/Game.sfc": "ROMs/com.provenance.snes/Game (USA).sfc"])
        XCTAssertEqual(journal.entries["ROMs/com.provenance.snes/New.sfc"]?.state, .copied)
    }

    func testSamePathStillGoesThroughTheIdenticalRule() async throws {
        try write(destination, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        try write(source, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        _ = try await engine().start(joinRequest())
        XCTAssertEqual(try XCTUnwrap(store.load()).entries["ROMs/com.provenance.snes/Game.sfc"]?.state, .identical)
        XCTAssertNil(try XCTUnwrap(store.load()).remaps)
    }

    func testWithoutDeduplicationTheFileIsCopied() async throws {
        try write(destination, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        try write(source, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        _ = try await engine().start(joinRequest(deduplicate: false))
        XCTAssertEqual(read(destination, "ROMs/com.provenance.snes/Game.sfc"), "same bytes")
    }

    func testSavesAreNeverDeduplicated() async throws {
        try write(destination, "Save States/Other/s.svs", "same bytes")
        try write(source, "Save States/Game/s.svs", "same bytes")
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: source, destinationRoot: destination,
                                         folders: LibraryMoveFolders.shared + LibraryMoveFolders.saves, keepCopy: false,
                                         destinationFolder: pickedFolder(), deduplicateByMD5: true)
        _ = try await engine().start(request)
        XCTAssertEqual(read(destination, "Save States/Game/s.svs"), "same bytes")
    }

    func testRollbackLeavesTheSharedCopyAlone() async throws {
        try write(destination, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        try write(source, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        var journal = LibraryMoveJournal(request: joinRequest())
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 10, md5: nil, modified: nil, state: .deduplicated, destinationPath: "ROMs/com.provenance.snes/Game (USA).sfc")
        try store.save(journal)
        try await engine().rollback(journal, destinationRoot: destination)
        XCTAssertEqual(read(destination, "ROMs/com.provenance.snes/Game (USA).sfc"), "same bytes")
    }
```

Append to `LibraryMoveCleanupTests.swift` (use its existing fixture names):

```swift
    func testCleanupDeletesADeduplicatedSourceOnceTheSharedCopyVerifies() async throws {
        try write(source, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        try write(destination, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        var journal = LibraryMoveJournal(request: .init(source: .appStorage, destination: .pickedFolder, sourceRoot: source, destinationRoot: destination,
                                                        folders: ["ROMs"], keepCopy: false))
        journal.phase = .switched
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 10, md5: nil, modified: try LibraryMoveTestSupport.modificationDate(source, "ROMs/com.provenance.snes/Game.sfc"),
                                                                     state: .deduplicated, destinationPath: "ROMs/com.provenance.snes/Game (USA).sfc")
        try store.save(journal)
        XCTAssertEqual(try await engine().resume(journal, sourceRoot: source, destinationRoot: destination), .cleanedUp)
        XCTAssertFalse(exists(source, "ROMs/com.provenance.snes/Game.sfc"))
        XCTAssertEqual(read(destination, "ROMs/com.provenance.snes/Game (USA).sfc"), "same bytes")
    }
```

- [ ] **Step 5: Lint and commit**

```bash
for f in PVLibrary/Sources/PVFileSystem/LibraryMove/SharedLibraryIndex.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift PVLibrary/Tests/PVLibraryTests/SharedLibraryIndexTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveEngineTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCleanupTests.swift; do swiftlint lint --path "$f"; done
git add PVLibrary/Sources/PVFileSystem/LibraryMove/SharedLibraryIndex.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift PVLibrary/Tests/PVLibraryTests/SharedLibraryIndexTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveEngineTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCleanupTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): de-duplicate by MD5 when joining a shared library"
```

### Task 10: Record remaps before cleanup

**Files:**
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift` (`setPathRemapApplier`, the gate in `resumeIfNeeded`)
- Create: `PVLibrary/Sources/PVLibrary/Database/LibraryPathRemapper.swift`
- Modify: `PVLibrary/Sources/PVLibrary/Database/PVGameLibrary.swift` (register the applier before `resumeIfNeeded()`)
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift`, `PVLibrary/Tests/PVLibraryTests/LibraryPathRemapperTests.swift`

**Interfaces:**
- Consumes: `LibraryMoveJournal.remaps` (Task 6/9).
- Produces: `LibraryMoveCoordinator.PathRemapApplier = @Sendable ([String: String]) async throws -> Void`, `setPathRemapApplier(_:)`; `LibraryPathRemapper.romPath(forPartialPath:)`, `LibraryPathRemapper.apply(_:) async throws`.

- [ ] **Step 1: Write the failing coordinator tests** (append; `Recorder` gains `var remaps: [[String: String]] = []`)

```swift
    // MARK: - Remaps (phase 4)

    private func switchedJoinJournal() throws -> LibraryMoveJournal {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        try write(picked, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        var journal = LibraryMoveJournal(request: .init(source: .appStorage, destination: .pickedFolder, sourceRoot: local, destinationRoot: picked,
                                                        folders: ["ROMs"], keepCopy: false, destinationFolder: folderA()))
        journal.phase = .switched
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 10, md5: nil, modified: try LibraryMoveTestSupport.modificationDate(local, "ROMs/com.provenance.snes/Game.sfc"),
                                                                     state: .deduplicated, destinationPath: "ROMs/com.provenance.snes/Game (USA).sfc")
        journal.remaps = ["ROMs/com.provenance.snes/Game.sfc": "ROMs/com.provenance.snes/Game (USA).sfc"]
        try store.save(journal)
        return journal
    }

    func testRemapsAreAppliedBeforeCleanupDeletesSources() async throws {
        _ = try switchedJoinJournal()
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        let record = recorder
        c.setPathRemapApplier { remaps in record.remaps.append(remaps) }
        XCTAssertEqual(await c.resumeIfNeeded(progress: nil), .cleanedUp)
        XCTAssertEqual(recorder.remaps, [["ROMs/com.provenance.snes/Game.sfc": "ROMs/com.provenance.snes/Game (USA).sfc"]])
        XCTAssertFalse(exists(local, "ROMs/com.provenance.snes/Game.sfc"))
    }

    func testCleanupWaitsWhenTheRemapApplierThrows() async throws {
        // Review Focus 4: a record that still names the old path must not lose its file.
        _ = try switchedJoinJournal()
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        struct Boom: Error {}
        c.setPathRemapApplier { _ in throw Boom() }
        XCTAssertNil(await c.resumeIfNeeded(progress: nil))
        XCTAssertTrue(c.hasPendingMove)
        XCTAssertTrue(exists(local, "ROMs/com.provenance.snes/Game.sfc"))
    }

    func testCleanupWaitsWhenNoApplierIsRegistered() async throws {
        _ = try switchedJoinJournal()
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        XCTAssertNil(await c.resumeIfNeeded(progress: nil))
        XCTAssertTrue(exists(local, "ROMs/com.provenance.snes/Game.sfc"))
    }

    func testAJournalWithoutRemapsNeedsNoApplier() async throws {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        var journal = LibraryMoveJournal(request: .init(source: .appStorage, destination: .pickedFolder, sourceRoot: local, destinationRoot: picked,
                                                        folders: ["ROMs"], keepCopy: false, destinationFolder: folderA()))
        journal.phase = .switched
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 3, md5: nil, modified: try LibraryMoveTestSupport.modificationDate(local, "ROMs/com.provenance.snes/Game.sfc"), state: .copied, destinationPath: nil)
        try store.save(journal)
        XCTAssertEqual(await coordinator(launched: .pickedFolder, launchedFolder: folderA()).resumeIfNeeded(progress: nil), .cleanedUp)
    }
```

- [ ] **Step 2: Coordinator hook.** Add to `LibraryMoveCoordinator`:

```swift
    public typealias PathRemapApplier = @Sendable ([String: String]) async throws -> Void

    private let remapLock = NSLock()
    private var remapApplier: PathRemapApplier?

    /// Registers what rewrites the database when a join de-duplicated files (`LibraryPathRemapper` in PVLibrary).
    /// `PVGameLibrary.init` calls this before `resumeIfNeeded()`.
    public func setPathRemapApplier(_ applier: @escaping PathRemapApplier) {
        remapLock.lock()
        remapApplier = applier
        remapLock.unlock()
    }

    private func currentRemapApplier() -> PathRemapApplier? {
        remapLock.lock()
        defer { remapLock.unlock() }
        return remapApplier
    }
```

In `resumeIfNeeded`, inside `if journal.phase != .copying { ... }` and before the `carryNewTopLevelEntries` line:

```swift
            if let remaps = journal.remaps, !remaps.isEmpty {
                // D15: records must point at the shared copies before their sources are deleted.
                guard let applier = currentRemapApplier() else {
                    ELOG("LibraryMove: \(remaps.count) record remaps are pending but no applier is registered; cleanup waits")
                    return nil
                }
                do {
                    try await applier(remaps)
                } catch {
                    ELOG("LibraryMove: applying record remaps failed: \(error.localizedDescription); cleanup waits")
                    return nil
                }
            }
```

- [ ] **Step 3: Remapper** (`LibraryPathRemapper.swift`, PVLibrary; pattern from `PVGameLibrary+Migration.fixPartialPaths`)

```swift
//
//  LibraryPathRemapper.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  After joining a shared library, records whose file was found under another name point at that
//  name (D15). Idempotent: a record already renamed matches nothing.
//

import Foundation
import PVFileSystem
import PVLogging
import PVRealm
import RealmSwift

public enum LibraryPathRemapper {
    private static let romsPrefix = "ROMs/"

    /// `PVGame.romPath` is the partial path without its `ROMs/` prefix (`GameImporterDatabaseService`).
    public static func romPath(forPartialPath partialPath: String) -> String {
        partialPath.hasPrefix(romsPrefix) ? String(partialPath.dropFirst(romsPrefix.count)) : partialPath
    }

    /// Rewrites every `PVFile.partialPath` in `remaps` and the owning `PVGame.romPath`.
    public static func apply(_ remaps: [String: String]) async throws {
        try await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            let files = realm.objects(PVFile.self).filter("partialPath IN %@", Array(remaps.keys))
            var count = 0
            try realm.write {
                for file in files {
                    guard let newPath = remaps[file.partialPath] else { continue }
                    let oldRomPath = romPath(forPartialPath: file.partialPath)
                    file.partialPath = newPath
                    for game in realm.objects(PVGame.self).filter("romPath == %@", oldRomPath) {
                        game.romPath = romPath(forPartialPath: newPath)
                    }
                    count += 1
                }
            }
            ILOG("LibraryMove: remapped \(count) of \(remaps.count) records to shared copies")
        }
    }
}
```

In `PVGameLibrary.init`, before `await LibraryMoveCoordinator.shared.resumeIfNeeded()`:

```swift
            LibraryMoveCoordinator.shared.setPathRemapApplier { try await LibraryPathRemapper.apply($0) }
```

- [ ] **Step 4: Remapper test** (`LibraryPathRemapperTests.swift`; the Realm write is exercised on device by the user)

```swift
//
//  LibraryPathRemapperTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVLibrary

final class LibraryPathRemapperTests: XCTestCase {
    func testRomPathDropsTheROMsPrefixOnly() {
        XCTAssertEqual(LibraryPathRemapper.romPath(forPartialPath: "ROMs/com.provenance.snes/Game (USA).sfc"), "com.provenance.snes/Game (USA).sfc")
        XCTAssertEqual(LibraryPathRemapper.romPath(forPartialPath: "com.provenance.snes/Game.sfc"), "com.provenance.snes/Game.sfc")
        XCTAssertEqual(LibraryPathRemapper.romPath(forPartialPath: "BIOS/x.bin"), "BIOS/x.bin")
    }
}
```

- [ ] **Step 5: Lint and commit**

```bash
for f in PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift PVLibrary/Sources/PVLibrary/Database/LibraryPathRemapper.swift PVLibrary/Sources/PVLibrary/Database/PVGameLibrary.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift PVLibrary/Tests/PVLibraryTests/LibraryPathRemapperTests.swift; do swiftlint lint --path "$f"; done
git add PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift PVLibrary/Sources/PVLibrary/Database/LibraryPathRemapper.swift PVLibrary/Sources/PVLibrary/Database/PVGameLibrary.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift PVLibrary/Tests/PVLibraryTests/LibraryPathRemapperTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): point records at shared copies before cleanup"
```

### Task 12: iCloud-located picked folder: metadata watcher and placeholder downloads

**Files:**
- Create: `PVLibrary/Sources/PVLibrary/Cloud Sync/iCloud/PickedFolderCloudWatcher.swift`
- Modify: `PVUI/Sources/PVSwiftUI/App Delegate/PVAppDelegate.swift` (start it after the library is initialised, where `_initLibraryNotificationHandlers()` is called)
- Test: none runnable without iCloud; the predicate and the folder filter are static functions with a test in `PVLibrary/Tests/PVLibraryTests/PickedFolderCloudWatcherTests.swift`.

**Interfaces:**
- Consumes: `LibraryLocation.pickedFolderAtLaunch.url`, `LibraryMoveFolders.shared`, `LibraryRescanRequester` (Task 11).
- Produces: `PickedFolderCloudWatcher.startIfNeeded(onChange: @escaping @MainActor () -> Void)`.

- [ ] **Step 1: Test**

```swift
import XCTest
@testable import PVLibrary

final class PickedFolderCloudWatcherTests: XCTestCase {
    func testPredicateScopesToTheFolder() {
        let predicate = PickedFolderCloudWatcher.predicate(rootPath: "/x/Lib")
        XCTAssertTrue(predicate.evaluate(with: ["kMDItemPath": "/x/Lib/ROMs/a"]))
        XCTAssertFalse(predicate.evaluate(with: ["kMDItemPath": "/x/Other/ROMs/a"]))
    }

    func testOnlySharedFoldersAreDownloaded() {
        XCTAssertTrue(PickedFolderCloudWatcher.shouldDownload(relativePath: "ROMs/com.provenance.snes/Game.sfc"))
        XCTAssertTrue(PickedFolderCloudWatcher.shouldDownload(relativePath: "BIOS/x.bin"))
        XCTAssertFalse(PickedFolderCloudWatcher.shouldDownload(relativePath: "Save States/x/s.svs"))
        XCTAssertFalse(PickedFolderCloudWatcher.shouldDownload(relativePath: "Conflicts/ROMs/x"))
    }
}
```

- [ ] **Step 2: Implement** (mirror `SwiftCloudDrive/MetadataMonitor.swift`; external-documents scope because the folder is outside our container)

```swift
//
//  PickedFolderCloudWatcher.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  An iCloud Drive folder picked as the library: iCube or iFly may add files that arrive as cloud-only
//  placeholders. The query starts their download under the shared folders and asks for a rescan when
//  anything changes (D17). Nothing here runs for a local folder or on tvOS.
//

import Foundation
import PVFileSystem
import PVLogging

public final class PickedFolderCloudWatcher: @unchecked Sendable {
    public static let shared = PickedFolderCloudWatcher()

    private var query: NSMetadataQuery?
    private var root: URL?
    private var onChange: (@MainActor () -> Void)?

    private init() {}

    static func predicate(rootPath: String) -> NSPredicate {
        NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, rootPath)
    }

    /// Only the shared folders: a placeholder under the saves folders belongs to another app's cores.
    static func shouldDownload(relativePath: String) -> Bool {
        LibraryMoveFolders.isShared(partialPath: relativePath)
    }

    /// Starts watching when the library is a picked folder that lives in iCloud Drive. Safe to call once per launch.
    @MainActor
    public func startIfNeeded(onChange: @escaping @MainActor () -> Void) {
        #if os(tvOS)
        return
        #else
        guard query == nil, LibraryLocation.current == .pickedFolder, let root = LibraryLocation.pickedFolderAtLaunch.url,
              (try? root.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true else { return }
        self.root = root
        self.onChange = onChange
        let query = NSMetadataQuery()
        query.notificationBatchingInterval = 3
        query.searchScopes = [NSMetadataQueryUbiquitousExternalDocumentsScope, NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = Self.predicate(rootPath: root.standardizedFileURL.path)
        NotificationCenter.default.addObserver(self, selector: #selector(handle(_:)), name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(handle(_:)), name: .NSMetadataQueryDidUpdate, object: query)
        self.query = query
        query.start()
        ILOG("PickedFolderCloudWatcher: watching \(root.lastPathComponent)")
        #endif
    }

    @objc private func handle(_ notification: Notification) {
        guard let query, let root else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        var started = 0
        for case let item as NSMetadataItem in query.results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                  let relative = LibraryMovePlanner.relativePath(of: url, under: root), Self.shouldDownload(relativePath: relative),
                  let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String,
                  status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded else { continue }
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                started += 1
            } catch {
                WLOG("PickedFolderCloudWatcher: could not start downloading \(relative): \(error.localizedDescription)")
            }
        }
        if started > 0 { ILOG("PickedFolderCloudWatcher: started \(started) downloads") }
        let change = onChange
        Task { @MainActor in change?() }
    }
}
```

`LibraryMovePlanner.relativePath(of:under:)` is `static` but internal; make it `public static` (it already handles `/var` vs `/private/var`).

In `PVAppDelegate`, right after `_initLibraryNotificationHandlers()` is called during launch (find the call site), under `#if !os(tvOS)`:

```swift
        PickedFolderCloudWatcher.shared.startIfNeeded {
            LibraryRescanRequester.shared.requestRescan(reason: "iCloud metadata update")
        }
```

- [ ] **Step 3: Lint and commit**

```bash
for f in "PVLibrary/Sources/PVLibrary/Cloud Sync/iCloud/PickedFolderCloudWatcher.swift" PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMovePlanner.swift "PVUI/Sources/PVSwiftUI/App Delegate/PVAppDelegate.swift" PVLibrary/Tests/PVLibraryTests/PickedFolderCloudWatcherTests.swift; do swiftlint lint --path "$f"; done
git add "PVLibrary/Sources/PVLibrary/Cloud Sync/iCloud/PickedFolderCloudWatcher.swift" PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMovePlanner.swift "PVUI/Sources/PVSwiftUI/App Delegate/PVAppDelegate.swift" PVLibrary/Tests/PVLibraryTests/PickedFolderCloudWatcherTests.swift
git -c commit.gpgsign=false commit -m "feat(library): watch an iCloud picked folder and download shared files"
```

### Task 13: Spec amendments and CLAUDE.md

**Files:**
- Modify: `docs/superpowers/specs/2026-10-11-library-storage-locations-design.md`
- Modify: `CLAUDE.md` (the "Library storage" bullet under "Code conventions")

- [ ] **Step 1: Spec.** Under "Data model", after the phase 3 bullet, add a "*Revised 2026-10-12 while building phases 3 and 4*" block that records D8–D18 from this plan in the spec's own voice (one short paragraph each; copy the decision text, drop the plan cross-references). Under "Open questions", resolve 1 (extensions never resolve the bookmark, D18) and 4 (unchanged: bookmarks resolved with no security-scope option on the iOS SDK; Mac verified by the user). Under "Folder layout contract", add the "Contract notes for iFly" list below verbatim as a sub-list. Mark phases 3 and 4 **Done** in "Suggested phasing" with this plan's path.

- [ ] **Step 2: CLAUDE.md.** Extend the "Library storage" bullet with: picked folders (`.pickedFolder`, bookmark in `Defaults[.libraryPickedFolder]`, resolved once per launch by `LibraryLocation.pickedFolderAtLaunch`); two roots (`rootURL` for ROMs/BIOS/System, `savesRootURL` for the rest); `LibraryFolderInspector` gates a pick; journal version 2; joining de-duplicates by MD5 and the remap applier must be registered before `resumeIfNeeded()`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-10-11-library-storage-locations-design.md CLAUDE.md
git -c commit.gpgsign=false commit -m "docs(storage): record phase 3/4 decisions and the iFly contract notes"
```

---

## Dispatch order

Sequential batches, one sonnet agent each, in the main worktree on `develop`. Each batch's prompt carries: this plan's path, the task numbers, the Global Constraints verbatim, and "DO NOT git reset / rebase / push / stash / touch other branches; stage by explicit path only".

| Batch | Tasks | Why together |
|---|---|---|
| A | 1, 2, 3, 4, 5 | Pure `PVFileSystem` types; every later task names them. |
| B | 6, 7 | Engine then coordinator; both edit the move tests. |
| C | 8, 11 | PVUI; Task 11 also touches `PVAppDelegate`. |
| D | 9, 10, 12, 13 | Join path, then docs. Task 12 touches `PVAppDelegate` after C is in. |

After each batch the user runs the test command from Global Constraints; failures come back to the next agent as the first item. One opus review after D, then a fix wave, then push.

## Contract notes for iFly (additive; the layout itself is unchanged)

1. Manifest JSON: `{"version":1,"createdBy":"<bundle id>","createdAt":"<ISO 8601>"}`. Readers ignore unknown keys, accept a missing `createdAt`, and treat a `version` above what they know as still joinable. Whoever creates the library writes it; nobody rewrites it.
2. `Conflicts/` may appear at the root of a shared folder: Provenance's move engine files name clashes there (`Conflicts/ROMs/<system>/<name>`, `-2`, `-3` suffixes). Ignore it when scanning.
3. Hidden temp files `.<name>.librarymove-partial` and `.provenance-write-probe-<uuid>` can appear briefly. Skip hidden files.
4. `Save States/`, `Battery States/`, `Screenshots/`, `Cheats/`, `Patches/` may be present when the user opted to move saves. They are Provenance-core formats; ignore them.
5. Provenance never deletes a file it did not copy into the folder, never deletes `ROMs/<system>/` folders of systems it does not know, and reads only the system folders it supports.
