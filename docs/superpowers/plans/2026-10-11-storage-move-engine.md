# Storage Move Engine (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A journaled, verified, resumable, cancellable engine that moves the library between storage locations, first used for App Group → App storage, which retires the ad-hoc `ROMLocationMigrator.oldPaths` folder mover.

**Architecture:** Everything lives in the `PVFileSystem` target of the PVLibrary package (pure Foundation + PVHashing, no Realm). `LibraryLocation` gains String raw values and a stored setting that wins over the legacy `useAppGroups` toggle; `URL.documentsPath` / `URL.cachesPath` consult the same precedence so the app-files root and the library root never disagree. `LibraryMoveEngine` (an actor) runs plan → copy+verify → switch, and on the next launch cleanup (delta sweep + delete). Progress is persisted in `move-journal.json` in the app's own Application Support directory and re-read on every launch by `LibraryMoveCoordinator.resumeIfNeeded()`, which replaces the `migrateIfNeeded()` call in `PVGameLibrary.init`. The location is fixed per process (like `URL.documentsPath` already is), so a switch takes effect at the next launch; the UI hook tells the user to quit and reopen. Records are untouched: `PVFile` resolves `partialPath` against the roots.

**Tech Stack:** Swift 5 language mode on the Swift 6 toolchain, Swift concurrency (actor, `async`), `Codable` JSON, `Defaults` (sindresorhus) keys in `PVSettings`, PVHashing's `MD5Provider` (`FileManager` conforms), XCTest in `PVLibraryTests`.

**Spec:** `docs/superpowers/specs/2026-10-11-library-storage-locations-design.md` — trust the revised "Data model" section. Phase 2 is item 2 of "Suggested phasing". Decisions and gotchas from phase 1: `~/.claude/projects/-Users-jmattiello-Workspace-Provenance-Provenance/memory/handoff-oct11-2026-storage-locations.md`.

## Global Constraints

- iOS 17+ / tvOS 17+. The PV* packages also declare macOS 14+ and visionOS 1+, so every new file must compile on all four; use `#if os(tvOS)` guards, never availability checks for APIs that exist on iOS 17.
- **tvOS is a no-op.** `LibraryLocation.current` is always `.appStorage` on tvOS, `LibraryMoveCoordinator.resumeIfNeeded()` returns `nil` without touching disk, and the debug UI row is `#if !os(tvOS)`. The engine itself is platform-neutral Foundation code and compiles everywhere.
- No magic strings at call sites: folder names live in `LibraryMoveFolders`, the journal file name in `LibraryMoveJournalStore`, notification names in one `Notification.Name` extension (`PVLibrary/Sources/PVFileSystem/LibraryLocation.swift`), the Defaults key in `PVSettingsModel.swift`. `LibraryLocation` raw values are pinned by a test and are part of the on-disk contract (journal + UserDefaults): never rename them.
- The Realm database is never moved. It lives at `<App Group container>/<default|lite>.realm` (`RealmConfiguration.realmFileURL`), outside the `Documents/` folders this engine touches. The planner also skips hidden entries and any top-level entry whose name contains `.realm`, as a belt-and-braces guard.
- No new `Cores/` projects, no submodule edits, no `project.pbxproj` edits. The workspace builds PVLibrary from `Package.swift`; `PVLibrary/PVLibrary.xcodeproj` does not list PVFileSystem sources, so new files under `PVLibrary/Sources/PVFileSystem/` need no project edits (phase 1's `LibraryLocation.swift` landed the same way).
- Tests mandatory for every new type; they use temp directories and injected roots/closures only — never the real App Group, iCloud container or `Defaults` (except the pure `resolve(...)` table tests).
- SwiftLint: line length 200; `type_body_length` warning at 300; `function_body_length` warning at 200. Run `swiftlint lint --path <file>` on every changed Swift file.
- Conventional commits, subject < 72 chars, body ends with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Commit with `git -c commit.gpgsign=false commit`.
- **Working tree rules (the main tree has the user's unrelated uncommitted edits: DeltaSkin files, `Cores/Dolphin/dolphin-ios`, `Cores/Mupen64Plus/.../GBI.cpp`, `PVEmulatorCore+RunLoop.swift`, `PVAppDelegate+MetricKit.swift`, `Package.resolved`).** Stage only the files this plan names, by explicit path (`git add <path> <path>`). Never `git add -A`, `git add .`, `git stash`, `git reset`, `git rebase`, `git checkout -- <file>`, `git push`, or touch a branch. Commit on `develop`; the coordinator pushes.
- Test command. First, once per session, create the realm xcconfig in the scratchpad (Xcode 26.6 needs it; CI's Xcode doesn't mind it):

  ```bash
  SCRATCH=/private/tmp/claude-501/-Users-jmattiello-Workspace-Provenance-Provenance/1193bd65-8807-4a37-9a5c-5e4fd9b9aae3/scratchpad
  mkdir -p "$SCRATCH"
  printf 'OTHER_CFLAGS = $(inherited) -Wno-invalid-specialization\nOTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-invalid-specialization\n' > "$SCRATCH/realm.xcconfig"
  ```

  Then, per task (`<Class>` is the test class; drop `-only-testing` for the full run):

  ```bash
  cd /Users/jmattiello/Workspace/Provenance/Provenance/PVLibrary && xcodebuild test \
    -workspace .swiftpm/xcode/package.xcworkspace -scheme PVLibrary-UnitTests \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -collect-test-diagnostics never \
    CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation \
    -xcconfig "$SCRATCH/realm.xcconfig" -only-testing:PVLibraryTests/<Class> 2>&1 | tee "$SCRATCH/<Class>.log" | grep -E "Test Case|error:|\*\* TEST" | tail -40
  ```

  A targeted run takes 2–10 minutes (the first build of the session is the slow one). Never run two `xcodebuild`s against the same derived data at once. "Run the test and verify it fails" in a TDD step means: compile error (`cannot find ... in scope`) or assertion failure, both count — just confirm the failure is the one you expect, not an unrelated one.
- Never edit `PVLibrary/Sources/PVLibrary/Database/PVGameLibrary+Migration.swift` except in Task 8, and keep `fixOrphanedFiles()` / `fixPartialPaths()` intact: `PVAppDelegate.swift` calls them.

## Review Focus

Behaviour the spec implies but no single sentence covers; each gets a test in the owning task.

1. **Same-volume copy needs the full size free before the source is deleted.** App Group and app Documents share one volume; the destination must hold a second copy until cleanup. The planner's space check demands `totalBytes + headroom` and fails with `.insufficientSpace` (Task 3).
2. **A source file vanishes between plan and copy** (the user deletes it in Files.app while the copy runs). The engine skips it with a warning; it never fails the move (Task 5).
3. **A save written after its file was journaled** (a battery save written in the window between switch and relaunch, when the process still writes to the old root). The cleanup delta sweep notices the size or mtime change and copies it before deleting (Task 6).
4. **A journal from another build**: unknown `version`, unknown `LibraryLocation` raw value, or truncated JSON. `load()` returns `nil` and deletes the file; launch continues (Task 2).
5. **The source container is gone at resume** (`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil`, e.g. the entitlement changed). The coordinator logs, keeps the journal, and returns `nil`; it never switches or deletes (Task 7).

## Design decisions (settled here; implementers don't reopen them)

**D1 — Stored setting arrives now, as `Defaults[.libraryLocation]: String?`.** Key `"libraryLocation"` in `PVSettingsModel.swift` next to `useAppGroups`. Nothing seeds it at launch; only the engine's switch writes it. Precedence in `LibraryLocation.resolve`: iCloud Drive (sync on + Drive mode) still wins and is still derived from the iCloud settings (phase 5 moves it into the stored value); otherwise the stored value; otherwise the legacy `useAppGroups` toggle. The switch writes both `libraryLocation = "appStorage"` and `useAppGroups = false`, so an older build (which only knows `useAppGroups`) stays consistent after a TestFlight downgrade.

**D2 — The appGroup/appStorage axis is fixed per process.** `LibraryLocation.storedAtLaunch` is a `static let` read once; `URL.documentsPath` and `URL.cachesPath` use `LibraryLocation.usesAppGroupContainer` (stored value if present, else `useAppGroups`), so the app-files root and the library root agree by construction. A switch therefore takes effect at the next launch. This is deliberate: it keeps the running process on one coherent root (no half-moved state for the resolver or the cores), and the delta sweep at cleanup picks up anything written in the meantime. The iCloud Drive axis stays live, as in phase 1.

**D3 — Cleanup runs on the launch after the switch.** Phases: `copying` → `switched` (settings written, relaunch prompted) → `cleaning` (next launch: delta sweep, delete journaled sources, remove emptied folders) → journal deleted. Nothing is deleted while the process that did the copy is still running against the old root.

**D4 — Journal location and format.** `<Application Support>/LibraryMove/move-journal.json` in the app's own container (`FileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, ...)`), never the App Group. JSON via `Codable`, atomic writes, flushed every 25 verified files and at every phase change. Entries are keyed by path relative to the root (`ROMs/com.provenance.snes/Game.sfc`), never by absolute path, because app container paths change across app updates. Roots are re-derived from the `LibraryLocation` values at resume.

**D5 — Verification.** Size for every file; MD5 (via `MD5Provider`, `FileManager.default` in production) for files under `ROMs/` and `BIOS/`. Mismatch → remove the destination copy and retry once → `.verificationFailed(relativePath:)`, journal kept so a later attempt resumes.

**D6 — Conflicts and duplicates.** Destination already has the file: identical (same size **and** same MD5, in every folder; amended after the final review) → `identical`, nothing copied, source still deleted at cleanup. Different → copy phase: the destination's own file is moved aside to `<destinationRoot>/Conflicts/<relativePath>` (then `-2`, `-3`, … suffix before the extension if that exists too) and the live source file takes the real path, recorded as `displaced` with `displacedPath` (amended after the final review; the original text sent the incoming file to Conflicts). Post-switch sweep: the incoming file goes to `Conflicts/` as `conflict` with `destinationPath`. A destination file is never deleted or overwritten.

**D7 — Folder set for leaving the App Group.** Everything the app writes under the group's `Documents/`, i.e. the union of today's `oldPaths`, the `Paths` accessors and the inbox: `ROMs, BIOS, System, Battery States, Battery Saves, Save States, Screenshots, Cheats, Patches, Conflicts, RetroArch, Imports`. (`Battery Saves` is the misspelt folder `oldPaths` created; the real one is `Battery States`. It is moved 1:1 so nothing is lost.) Top-level entries outside this list are logged and left behind. The spec's "which files move" table (saves optional, Imports stays) applies to a *picked folder* and is phase 3's concern.

**D8 — Cancel.** Honoured between files, only before the switch. Rollback deletes destination files whose entry is `copied` or `conflict` (never `identical`, which pre-existed), removes directories it created that are now empty, deletes the journal, returns `.cancelled`. After the switch, cancel is a no-op.

**D9 — Minimal UI hook.** `FeatureFlagsDebugView`'s `useAppGroups` toggle row is replaced by a read-only "Library location" row plus, when the current location is `.appGroup`, a "Move to App storage" button that drives `LibraryMoveCoordinator.shared.moveToAppStorage` and then shows an alert "Move complete. Quit and reopen Provenance to finish." The "RESET TO DEFAULT" block must NOT touch `libraryLocation` or `useAppGroups` (amended after the final review: resetting stranded an App Group user's library). Flipping `useAppGroups` by hand no longer moves anything (the engine owns moves), which is why the raw toggle goes away. The full Settings › Library › Storage UI is a later phase.

## File map

| Path | Responsibility |
|---|---|
| `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift` | add `libraryLocation` key |
| `PVLibrary/Sources/PVFileSystem/LibraryLocation.swift` | raw values, stored precedence, `usesAppGroupContainer`, `switchStored(to:)`, notification name |
| `PVLibrary/Sources/PVFileSystem/Paths.swift` | `documentsPath`/`cachesPath` use `LibraryLocation.usesAppGroupContainer` |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift` | folders, request, phase, progress, outcome, error |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift` | journal model + `LibraryMoveJournalStore` |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMovePlanner.swift` | enumerate folders, totals, free-space check |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveFileCopier.swift` | copy one file, verify, conflict naming |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift` | actor: start / resume / cancel |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine+Cleanup.swift` | delta sweep + delete |
| `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift` | real roots, launch resume, public entry point |
| `PVLibrary/Sources/PVLibrary/Database/PVGameLibrary+Migration.swift` | delete `oldPaths` and the folder mover |
| `PVLibrary/Sources/PVLibrary/Database/PVGameLibrary.swift` | call `resumeIfNeeded()` |
| `PVUI/Sources/PVSwiftUI/Settings/Views/FeatureFlagsDebugView.swift` | debug UI hook |
| `PVLibrary/Tests/PVLibraryTests/LibraryLocationTests.swift` | extended |
| `PVLibrary/Tests/PVLibraryTests/LibraryMoveJournalTests.swift`, `LibraryMovePlannerTests.swift`, `LibraryMoveFileCopierTests.swift`, `LibraryMoveEngineTests.swift`, `LibraryMoveCleanupTests.swift`, `LibraryMoveCoordinatorTests.swift` | new |
| `docs/superpowers/specs/2026-10-11-library-storage-locations-design.md`, `CLAUDE.md` | doc updates |

---

### Task 1: Stored `libraryLocation` setting and root precedence — `sonnet`

**Files:**
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift` (the `// MARK: File syste` block, ~line 687)
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryLocation.swift`
- Modify: `PVLibrary/Sources/PVFileSystem/Paths.swift:21-47`
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryLocationTests.swift`

**Interfaces:**
- Produces: `LibraryLocation: String, Sendable, CaseIterable` with raw values `"appStorage"`, `"appGroup"`, `"iCloudDrive"`; `static func resolve(stored: LibraryLocation?, useAppGroups: Bool, iCloudSync: Bool, iCloudDriveMode: Bool) -> LibraryLocation`; `static let storedAtLaunch: LibraryLocation?`; `static var usesAppGroupContainer: Bool`; `func rootURL(localDocuments: URL, appGroupDocuments: URL?, iCloudDocuments: URL?, usesAppGroupContainer: Bool) -> URL`; `static func switchStored(to: LibraryLocation)`; `Notification.Name.libraryLocationDidChange`; `LibraryLocation.requiresRelaunchUserInfoKey`; `Defaults.Keys.libraryLocation: Key<String?>`.

- [ ] **Step 1: Write the failing tests** — replace the "Settings to location" and "Root" sections of `LibraryLocationTests.swift` with:

```swift
    // MARK: - Settings to location

    func testRawValuesArePinned() {
        // Stored in UserDefaults and in move-journal.json: renaming one breaks resume and downgrade.
        XCTAssertEqual(LibraryLocation.appStorage.rawValue, "appStorage")
        XCTAssertEqual(LibraryLocation.appGroup.rawValue, "appGroup")
        XCTAssertEqual(LibraryLocation.iCloudDrive.rawValue, "iCloudDrive")
        XCTAssertEqual(LibraryLocation.allCases.count, 3)
    }

    func testICloudDriveNeedsSyncAndDriveMode() {
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: false, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: true, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: false, iCloudSync: false, iCloudDriveMode: true), .appStorage)
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: false, iCloudSync: true, iCloudDriveMode: false), .appStorage)
    }

    func testAppGroupWithoutICloudDrive() {
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: true, iCloudSync: false, iCloudDriveMode: false), .appGroup)
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: true, iCloudSync: true, iCloudDriveMode: false), .appGroup)
    }

    func testDefaultIsAppStorage() {
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: false, iCloudSync: false, iCloudDriveMode: false), .appStorage)
    }

    func testStoredLocationWinsOverLegacyToggle() {
        XCTAssertEqual(LibraryLocation.resolve(stored: .appStorage, useAppGroups: true, iCloudSync: false, iCloudDriveMode: false), .appStorage)
        XCTAssertEqual(LibraryLocation.resolve(stored: .appGroup, useAppGroups: false, iCloudSync: false, iCloudDriveMode: false), .appGroup)
    }

    func testICloudDriveStillWinsOverStoredLocation() {
        XCTAssertEqual(LibraryLocation.resolve(stored: .appStorage, useAppGroups: false, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
    }

    func testStoredICloudDriveIsIgnoredUntilPhase5() {
        // Phase 5 moves the iCloud axis into the stored value; until then a stored iCloudDrive falls back to the legacy toggle.
        XCTAssertEqual(LibraryLocation.resolve(stored: .iCloudDrive, useAppGroups: true, iCloudSync: false, iCloudDriveMode: false), .appGroup)
    }

    // MARK: - Root

    private let local = URL(fileURLWithPath: "/docs", isDirectory: true)
    private let group = URL(fileURLWithPath: "/group/Documents", isDirectory: true)
    private let iCloud = URL(fileURLWithPath: "/icloud/Documents", isDirectory: true)

    func testAppStorageRootIsLocalDocumentsEvenWhenAGroupExists() {
        XCTAssertEqual(LibraryLocation.appStorage.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: iCloud, usesAppGroupContainer: false), local)
    }

    func testAppGroupRootIsTheGroupDocumentsAndFallsBackToLocal() {
        XCTAssertEqual(LibraryLocation.appGroup.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, usesAppGroupContainer: true), group)
        XCTAssertEqual(LibraryLocation.appGroup.rootURL(localDocuments: local, appGroupDocuments: nil, iCloudDocuments: nil, usesAppGroupContainer: true), local)
    }

    func testICloudDriveRootFallsBackToTheAppFilesRoot() {
        XCTAssertEqual(LibraryLocation.iCloudDrive.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: iCloud, usesAppGroupContainer: false), iCloud)
        XCTAssertEqual(LibraryLocation.iCloudDrive.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, usesAppGroupContainer: false), local)
        // Phase 1 behaviour kept: an App Group user without an iCloud container stays in the group.
        XCTAssertEqual(LibraryLocation.iCloudDrive.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, usesAppGroupContainer: true), group)
    }

    func testAppFilesRootFollowsTheSameAxisAsTheLibraryRoot() {
        // documentsPath is fixed at launch from the same precedence LibraryLocation uses.
        #if os(tvOS)
        XCTAssertEqual(URL.documentsPath, URL.cachesPathLocal)
        #else
        let expected = LibraryLocation.usesAppGroupContainer ? (URL.documentsPathAppGroup ?? URL.documentsPathLocal) : URL.documentsPathLocal
        XCTAssertEqual(URL.documentsPath, expected)
        #endif
    }
```

Keep `testLibraryAccessorsUseTheCurrentRoot` and the "Stored partial paths" section unchanged.

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command with `<Class>` = `LibraryLocationTests`. Expected: compile errors (`extra argument 'stored'`, `rawValue` not found).

- [ ] **Step 3: Add the Defaults key** in `PVSettingsModel.swift`, replacing the `// MARK: File syste` block:

```swift
// MARK: File system
public extension Defaults.Keys {
    /// Legacy App Group toggle. `libraryLocation` wins when set; the move engine mirrors it so older builds agree.
    static let useAppGroups = Key<Bool>("useAppGroups", default: false)

    /// `LibraryLocation.rawValue` chosen by the move engine (PVFileSystem). `nil` until the first move;
    /// the location is then derived from `useAppGroups` and the iCloud settings.
    static let libraryLocation = Key<String?>("libraryLocation", default: nil)
}
```

- [ ] **Step 4: Rewrite `LibraryLocation.swift`**

```swift
//
//  LibraryLocation.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Where the library's files live: ROMs, BIOS, System, save states, battery saves,
//  screenshots, cheats and patches (everything under `Paths` built on
//  `URL.documentsiCloudOrLocalPath`). The app's own files (Imports, core configs) stay
//  under `URL.documentsPath`, which follows the same App Group precedence.
//
//  The appGroup/appStorage axis is fixed per process (`storedAtLaunch`), like
//  `URL.documentsPath`: a switch written by `LibraryMoveEngine` takes effect at the next
//  launch. The iCloud Drive axis is still derived live from the iCloud settings (phase 5).
//  Spec: docs/superpowers/specs/2026-10-11-library-storage-locations-design.md
//

import Foundation
import Defaults
import PVSettings

public enum LibraryLocation: String, Sendable, CaseIterable {
    /// The app's Documents (Caches on tvOS). The default.
    case appStorage
    /// The App Group container's Documents (legacy; a valid move source, never a destination).
    case appGroup
    /// The iCloud Drive ubiquity container's Documents.
    case iCloudDrive

    /// userInfo key of `.libraryLocationDidChange`: `true` when the new location applies at the next launch.
    public static let requiresRelaunchUserInfoKey = "requiresRelaunch"

    /// The `libraryLocation` setting as it was when this process first asked. Read once so the
    /// library root and `URL.documentsPath` can't drift apart mid-session.
    static let storedAtLaunch: LibraryLocation? = Defaults[.libraryLocation].flatMap(LibraryLocation.init(rawValue:))

    /// `true` when this process' Documents and Caches live in the App Group container.
    /// The stored location wins; the legacy `useAppGroups` toggle is the fallback.
    public static var usesAppGroupContainer: Bool {
        #if os(tvOS)
        return false
        #else
        if let stored = storedAtLaunch { return stored == .appGroup }
        return Defaults[.useAppGroups]
        #endif
    }

    /// The location the current settings select.
    public static var current: LibraryLocation {
        #if os(tvOS)
        return .appStorage
        #else
        return resolve(stored: storedAtLaunch,
                       useAppGroups: Defaults[.useAppGroups],
                       iCloudSync: Defaults[.iCloudSync],
                       iCloudDriveMode: Defaults[.iCloudSyncMode].isICloudDrive)
        #endif
    }

    /// iCloud Drive mode only applies while iCloud sync is on, and wins over everything else.
    /// A stored location (written by the move engine) wins over the legacy `useAppGroups` toggle.
    /// A stored `.iCloudDrive` is not honoured until phase 5 moves the iCloud axis into the setting.
    static func resolve(stored: LibraryLocation?, useAppGroups: Bool, iCloudSync: Bool, iCloudDriveMode: Bool) -> LibraryLocation {
        if iCloudSync && iCloudDriveMode { return .iCloudDrive }
        if let stored, stored != .iCloudDrive { return stored }
        return useAppGroups ? .appGroup : .appStorage
    }

    /// The folder the library's subfolders (`ROMs/`, `BIOS/`, …) live in.
    /// Call on a background thread: the iCloud container lookup can block.
    public var rootURL: URL {
        #if os(tvOS)
        return URL.cachesPath
        #else
        return rootURL(localDocuments: URL.documentsPathLocal,
                       appGroupDocuments: URL.documentsPathAppGroup,
                       iCloudDocuments: self == .iCloudDrive ? URL.iCloudDocumentsDirectory : nil,
                       usesAppGroupContainer: Self.usesAppGroupContainer)
        #endif
    }

    /// Each location names its own root. iCloud Drive without a container falls back to the
    /// app-files root (the group's Documents for an App Group user, else local Documents).
    func rootURL(localDocuments: URL, appGroupDocuments: URL?, iCloudDocuments: URL?, usesAppGroupContainer: Bool) -> URL {
        switch self {
        case .appStorage:
            return localDocuments
        case .appGroup:
            return appGroupDocuments ?? localDocuments
        case .iCloudDrive:
            return iCloudDocuments ?? (usesAppGroupContainer ? appGroupDocuments : nil) ?? localDocuments
        }
    }

    /// Records `location` as the library location. Only `LibraryMoveEngine` calls this, after the
    /// copy is verified. Mirrors the legacy toggle so a build that only knows `useAppGroups` agrees.
    /// Takes effect at the next launch (see `storedAtLaunch`).
    public static func switchStored(to location: LibraryLocation) {
        Defaults[.libraryLocation] = location.rawValue
        Defaults[.useAppGroups] = (location == .appGroup)
        NotificationCenter.default.post(name: .libraryLocationDidChange, object: nil,
                                        userInfo: [requiresRelaunchUserInfoKey: true])
    }
}

public extension Notification.Name {
    /// Posted by `LibraryLocation.switchStored(to:)`. userInfo: `LibraryLocation.requiresRelaunchUserInfoKey`.
    static let libraryLocationDidChange = Notification.Name("PVLibraryLocationDidChangeNotification")
}
```

- [ ] **Step 5: Route `documentsPath` / `cachesPath` through the same precedence** in `Paths.swift`. Replace lines 21-47 (`USE_APP_GROUPS`, `documentsPath`, `cachesPath`) with:

```swift
    /// Legacy accessor; prefer `LibraryLocation.usesAppGroupContainer`, which also honours the stored location.
    static var USE_APP_GROUPS: Bool {
        return LibraryLocation.usesAppGroupContainer
    }

    /// The app-files root (Imports, core configs, the resolver's local base). Fixed at launch.
    static let documentsPath: URL = {
#if os(tvOS)
        return cachesPath
#else
        if LibraryLocation.usesAppGroupContainer {
            return documentsPathAppGroup ?? documentsPathLocal
        } else {
            return documentsPathLocal
        }
#endif
    }()

    static let cachesPath: URL = {
        #if os(tvOS)
        return cachesPathLocal
        #else
        if LibraryLocation.usesAppGroupContainer {
            return cachesPathAppGroup ?? cachesPathLocal
        } else {
            return cachesPathLocal
        }
        #endif
    }()
```

(`Paths.swift` already imports `Defaults` and `PVSettings`; `LibraryLocation` is in the same module.)

- [ ] **Step 6: Run the tests to verify they pass**

Run with `<Class>` = `LibraryLocationTests`. Expected: all tests in the class pass, including the untouched partial-path tests.

- [ ] **Step 7: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryLocation.swift
swiftlint lint --path PVLibrary/Sources/PVFileSystem/Paths.swift
git add PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift PVLibrary/Sources/PVFileSystem/LibraryLocation.swift PVLibrary/Sources/PVFileSystem/Paths.swift PVLibrary/Tests/PVLibraryTests/LibraryLocationTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): stored libraryLocation setting with root precedence" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Move journal model and store — `sonnet`

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift`
- Create: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift`
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryMoveJournalTests.swift`

**Interfaces:**
- Consumes: `LibraryLocation` (Task 1).
- Produces: `LibraryMoveFolders`, `LibraryMoveRequest`, `LibraryMovePhase`, `LibraryMoveProgress`, `LibraryMoveOutcome`, `LibraryMoveError`, `LibraryMoveJournal` (+ `Entry`, `Entry.State`), `LibraryMoveJournalStore` (`url`, `static defaultURL()`, `load()`, `save(_:)`, `delete()`), `LibraryMoveJournal.init(request:)`.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  LibraryMoveJournalTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryMoveJournalTests: XCTestCase {
    private var dir: URL!
    private var store: LibraryMoveJournalStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryMoveJournalTests/\(UUID().uuidString)", isDirectory: true)
        store = LibraryMoveJournalStore(url: dir.appendingPathComponent("nested/move-journal.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeJournal() -> LibraryMoveJournal {
        let request = LibraryMoveRequest(source: .appGroup, destination: .appStorage,
                                         sourceRoot: URL(fileURLWithPath: "/src"), destinationRoot: URL(fileURLWithPath: "/dst"),
                                         folders: LibraryMoveFolders.appGroupExit, keepCopy: false)
        // Whole-second dates: the journal round-trips through ISO-8601 without fractions, and the test compares for equality.
        var journal = LibraryMoveJournal(request: request, now: Date(timeIntervalSince1970: 1_700_000_000))
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 42, md5: "abc", modified: Date(timeIntervalSince1970: 1_700_000_000), state: .copied, destinationPath: nil)
        journal.entries["Save States/Game/s.svs"] = .init(size: 7, md5: nil, modified: nil, state: .conflict, destinationPath: "Conflicts/Save States/Game/s.svs")
        return journal
    }

    func testLoadWithoutAFileIsNil() {
        XCTAssertNil(store.load())
    }

    func testSaveCreatesIntermediateDirectoriesAndRoundTrips() throws {
        let journal = makeJournal()
        try store.save(journal)
        let loaded = store.load()
        XCTAssertEqual(loaded, journal)
        XCTAssertEqual(loaded?.phase, .copying)
        XCTAssertEqual(loaded?.version, LibraryMoveJournal.currentVersion)
    }

    func testDeleteRemovesTheFileAndIsIdempotent() throws {
        try store.save(makeJournal())
        try store.delete()
        XCTAssertNil(store.load())
        XCTAssertNoThrow(try store.delete())
    }

    func testCorruptJournalIsDiscarded() throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: store.url)
        XCTAssertNil(store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url.path), "a journal that can't be read is removed so launch doesn't retry it forever")
    }

    func testUnknownLocationRawValueIsDiscarded() throws {
        try store.save(makeJournal())
        let text = try String(contentsOf: store.url, encoding: .utf8).replacingOccurrences(of: "\"appGroup\"", with: "\"pickedFolder\"")
        try text.write(to: store.url, atomically: true, encoding: .utf8)
        XCTAssertNil(store.load())
    }

    func testNewerVersionIsDiscarded() throws {
        var journal = makeJournal()
        journal.version = LibraryMoveJournal.currentVersion + 1
        try store.save(journal)
        XCTAssertNil(store.load())
    }

    func testStateRawValuesArePinned() {
        XCTAssertEqual(LibraryMovePhase.copying.rawValue, "copying")
        XCTAssertEqual(LibraryMovePhase.switched.rawValue, "switched")
        XCTAssertEqual(LibraryMovePhase.cleaning.rawValue, "cleaning")
        XCTAssertEqual(LibraryMoveJournal.Entry.State.copied.rawValue, "copied")
        XCTAssertEqual(LibraryMoveJournal.Entry.State.identical.rawValue, "identical")
        XCTAssertEqual(LibraryMoveJournal.Entry.State.conflict.rawValue, "conflict")
    }

    func testAppGroupExitFolderSetIsPinned() {
        XCTAssertEqual(LibraryMoveFolders.appGroupExit,
                       ["ROMs", "BIOS", "System", "Battery States", "Battery Saves", "Save States", "Screenshots", "Cheats", "Patches", "Conflicts", "RetroArch", "Imports"])
        XCTAssertEqual(LibraryMoveFolders.md5Verified, ["ROMs", "BIOS"])
        XCTAssertEqual(LibraryMoveFolders.conflicts, "Conflicts")
    }
}
```

- [ ] **Step 2: Run to verify failure** — `<Class>` = `LibraryMoveJournalTests`. Expected: `cannot find 'LibraryMoveJournalStore' in scope`.

- [ ] **Step 3: Create `LibraryMoveTypes.swift`**

```swift
//
//  LibraryMoveTypes.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Value types shared by the move engine, its journal and its callers.
//  Spec: docs/superpowers/specs/2026-10-11-library-storage-locations-design.md ("Moving between locations").
//

import Foundation

/// The library folders a move carries. Names are the ones `Paths` builds under the library root.
public enum LibraryMoveFolders {
    /// Everything the app writes under the App Group container's `Documents/`: the union of the
    /// retired `oldPaths` list, the `Paths` accessors and the import inbox. `Battery Saves` is the
    /// misspelt folder `oldPaths` used to create; it moves 1:1 so nothing is lost.
    public static let appGroupExit: [String] = [
        "ROMs", "BIOS", "System", "Battery States", "Battery Saves", "Save States",
        "Screenshots", "Cheats", "Patches", "Conflicts", "RetroArch", "Imports"
    ]

    /// Folders whose files are MD5-verified after copying (size alone for the rest).
    public static let md5Verified: Set<String> = ["ROMs", "BIOS"]

    /// Where an incoming file goes when the destination already has a different file of that name.
    public static let conflicts = "Conflicts"

    /// Top-level names the planner never moves, whatever the folder list says.
    static let neverMoved: Set<String> = ["move-journal.json"]
    static let realmMarker = ".realm"
}

/// What to move. Roots are passed in so the engine can be tested against temp directories.
public struct LibraryMoveRequest: Sendable, Equatable {
    public let source: LibraryLocation
    public let destination: LibraryLocation
    public let sourceRoot: URL
    public let destinationRoot: URL
    public let folders: [String]
    /// Leave the source files in place after the switch ("Keep a copy in the old location").
    public let keepCopy: Bool

    public init(source: LibraryLocation, destination: LibraryLocation, sourceRoot: URL, destinationRoot: URL, folders: [String], keepCopy: Bool) {
        self.source = source
        self.destination = destination
        self.sourceRoot = sourceRoot
        self.destinationRoot = destinationRoot
        self.folders = folders
        self.keepCopy = keepCopy
    }
}

/// Where a move is. Persisted in the journal, so the raw values are a contract.
public enum LibraryMovePhase: String, Codable, Sendable {
    /// Files are being copied and verified. Cancel rolls back.
    case copying
    /// The settings name the destination; it applies at the next launch. Sources are still intact.
    case switched
    /// The launch after the switch: delta sweep, then delete journaled sources.
    case cleaning
}

public struct LibraryMoveProgress: Sendable, Equatable {
    public let phase: LibraryMovePhase
    public let filesDone: Int
    public let filesTotal: Int
    public let bytesDone: Int64
    public let bytesTotal: Int64
    public let currentPath: String?

    public var fraction: Double {
        bytesTotal > 0 ? Double(bytesDone) / Double(bytesTotal) : (filesTotal > 0 ? Double(filesDone) / Double(filesTotal) : 1)
    }
}

public enum LibraryMoveOutcome: Sendable, Equatable {
    /// Copy verified and the setting written; the new location applies at the next launch.
    case switched
    /// The post-switch cleanup finished and the journal is gone.
    case cleanedUp
    /// Cancelled before the switch; the destination was rolled back.
    case cancelled
    /// There was no journal to resume.
    case nothingToDo
}

public enum LibraryMoveError: Error, Equatable, LocalizedError {
    case unsupportedMove(from: LibraryLocation, to: LibraryLocation)
    case rootUnavailable(LibraryLocation)
    case insufficientSpace(required: Int64, available: Int64)
    case verificationFailed(relativePath: String)
    case moveInProgress
    case journalMismatch

    public var errorDescription: String? {
        switch self {
        case .unsupportedMove(let from, let to): return "Moving the library from \(from.rawValue) to \(to.rawValue) is not supported yet."
        case .rootUnavailable(let location): return "The \(location.rawValue) folder is not available."
        case .insufficientSpace(let required, let available): return "Not enough free space: \(required) bytes needed, \(available) available."
        case .verificationFailed(let path): return "\(path) did not copy correctly."
        case .moveInProgress: return "A library move is already running."
        case .journalMismatch: return "The saved move does not match this launch's library location."
        }
    }
}
```

- [ ] **Step 4: Create `LibraryMoveJournal.swift`**

```swift
//
//  LibraryMoveJournal.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  `move-journal.json`: which files of a move are done, so an interrupted move resumes on the
//  next launch and cleanup deletes only what was copied. Lives in the app's own Application
//  Support directory (never the App Group). Entries are keyed by path relative to the root
//  because app container paths change across app updates; roots are re-derived at resume.
//

import Foundation
import PVLogging

public struct LibraryMoveJournal: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public struct Entry: Codable, Sendable, Equatable {
        public enum State: String, Codable, Sendable {
            /// Copied to the destination and verified.
            case copied
            /// The destination already had an identical file; nothing was copied.
            case identical
            /// The destination had a different file; the incoming copy went to `destinationPath` under `Conflicts/`.
            case conflict
        }

        public var size: Int64
        public var md5: String?
        public var modified: Date?
        public var state: State
        /// Relative to the destination root. Set for `.conflict`, otherwise the key is the destination path.
        public var destinationPath: String?

        public init(size: Int64, md5: String?, modified: Date?, state: State, destinationPath: String?) {
            self.size = size
            self.md5 = md5
            self.modified = modified
            self.state = state
            self.destinationPath = destinationPath
        }
    }

    public var version: Int
    public var id: UUID
    public var source: LibraryLocation
    public var destination: LibraryLocation
    public var folders: [String]
    public var keepCopy: Bool
    public var phase: LibraryMovePhase
    public var createdAt: Date
    public var updatedAt: Date
    /// Relative source path → what happened to it.
    public var entries: [String: Entry]

    public init(request: LibraryMoveRequest, now: Date = Date()) {
        version = Self.currentVersion
        id = UUID()
        source = request.source
        destination = request.destination
        folders = request.folders
        keepCopy = request.keepCopy
        phase = .copying
        createdAt = now
        updatedAt = now
        entries = [:]
    }
}

extension LibraryLocation: Codable {}

/// Loads and saves the one journal. Atomic writes; a journal that can't be decoded is deleted.
public struct LibraryMoveJournalStore: Sendable {
    public static let fileName = "move-journal.json"
    static let directoryName = "LibraryMove"

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `<Application Support>/LibraryMove/move-journal.json` in this app's container.
    public static func defaultURL(fileManager: FileManager = .default) throws -> URL {
        let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return support.appendingPathComponent(directoryName, isDirectory: true).appendingPathComponent(fileName, isDirectory: false)
    }

    public func load() -> LibraryMoveJournal? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let journal = try? decoder.decode(LibraryMoveJournal.self, from: data), journal.version <= LibraryMoveJournal.currentVersion {
            return journal
        }
        WLOG("LibraryMove: discarding unreadable journal at \(url.path)")
        try? delete()
        return nil
    }

    public func save(_ journal: LibraryMoveJournal) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(journal).write(to: url, options: .atomic)
    }

    public func delete() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
```

Note: `Entry.modified` round-trips through ISO-8601 at one-second precision; tests use whole-second dates (`Date(timeIntervalSince1970: 1_700_000_000)`), and the engine compares mtimes after truncating to seconds (Task 6).

- [ ] **Step 5: Run to verify pass** — `<Class>` = `LibraryMoveJournalTests`. Expected: 8 passes.

- [ ] **Step 6: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift
git add PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveTypes.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveJournal.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveJournalTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): library move journal and shared move types" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Planner — enumerate, total, free-space check — `sonnet`

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMovePlanner.swift`
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryMovePlannerTests.swift`

**Interfaces:**
- Consumes: `LibraryMoveFolders`, `LibraryMoveError` (Task 2).
- Produces: `LibraryMovePlan { items: [Item]; totalBytes }`, `LibraryMovePlan.Item { relativePath, size, modified }`, `LibraryMovePlanner(fileManager:availableCapacity:)`, `func plan(root: URL, folders: [String]) throws -> LibraryMovePlan`, `func checkSpace(for plan: LibraryMovePlan, at destinationRoot: URL) throws`, `static func requiredBytes(for bytes: Int64) -> Int64`, `static let minimumHeadroomBytes`.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  LibraryMovePlannerTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryMovePlannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryMovePlannerTests/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func seed(_ relativePath: String, _ bytes: Int) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
    }

    func testPlansOnlyTheListedFoldersRecursively() throws {
        try seed("ROMs/com.provenance.snes/Game.sfc", 10)
        try seed("ROMs/com.provenance.nes/Sub/Deep.nes", 5)
        try seed("BIOS/scph1001.bin", 3)
        try seed("Imports/pending.zip", 1)
        try seed("Skins/other.deltaskin", 100)
        try seed("stray.txt", 100)

        let plan = try LibraryMovePlanner().plan(root: root, folders: ["ROMs", "BIOS"])

        XCTAssertEqual(plan.items.map(\.relativePath).sorted(),
                       ["BIOS/scph1001.bin", "ROMs/com.provenance.nes/Sub/Deep.nes", "ROMs/com.provenance.snes/Game.sfc"])
        XCTAssertEqual(plan.totalBytes, 18)
        XCTAssertNotNil(plan.items.first?.modified)
    }

    func testMissingFoldersAreSkippedNotErrors() throws {
        try seed("BIOS/a.bin", 1)
        let plan = try LibraryMovePlanner().plan(root: root, folders: ["ROMs", "BIOS", "Nope"])
        XCTAssertEqual(plan.items.map(\.relativePath), ["BIOS/a.bin"])
    }

    func testHiddenFilesRealmFilesAndTheJournalAreNeverPlanned() throws {
        try seed("ROMs/.DS_Store", 1)
        try seed("ROMs/com.provenance.snes/.hidden", 1)
        try seed("ROMs/com.provenance.snes/Game.sfc", 2)
        try seed("ROMs/default.realm", 9)
        try seed("ROMs/default.realm.lock", 9)
        try seed("ROMs/move-journal.json", 9)
        let plan = try LibraryMovePlanner().plan(root: root, folders: ["ROMs"])
        XCTAssertEqual(plan.items.map(\.relativePath), ["ROMs/com.provenance.snes/Game.sfc"])
    }

    func testRelativePathsSurviveThePrivateVarSymlink() throws {
        // On device the root is /var/... but enumeration can yield /private/var/...; both must strip to the same relative path.
        try seed("ROMs/x/Game.sfc", 1)
        let resolved = root.resolvingSymlinksInPath()
        let plan = try LibraryMovePlanner().plan(root: resolved, folders: ["ROMs"])
        XCTAssertEqual(plan.items.map(\.relativePath), ["ROMs/x/Game.sfc"])
    }

    func testRequiredBytesAddsHeadroom() {
        XCTAssertEqual(LibraryMovePlanner.requiredBytes(for: 0), LibraryMovePlanner.minimumHeadroomBytes)
        XCTAssertEqual(LibraryMovePlanner.requiredBytes(for: 1_000), 1_000 + LibraryMovePlanner.minimumHeadroomBytes)
        let big: Int64 = 100 * 1024 * 1024 * 1024 // 100 GB → 5% is larger than the minimum headroom
        XCTAssertEqual(LibraryMovePlanner.requiredBytes(for: big), big + big / 20)
    }

    func testCheckSpaceThrowsWhenTheDestinationIsTooSmall() throws {
        try seed("ROMs/Game.sfc", 1_000)
        let planner = LibraryMovePlanner(availableCapacity: { _ in 500 })
        let plan = try planner.plan(root: root, folders: ["ROMs"])
        XCTAssertThrowsError(try planner.checkSpace(for: plan, at: root)) { error in
            XCTAssertEqual(error as? LibraryMoveError, .insufficientSpace(required: LibraryMovePlanner.requiredBytes(for: 1_000), available: 500))
        }
    }

    func testCheckSpacePassesWithRoom() throws {
        try seed("ROMs/Game.sfc", 1_000)
        let planner = LibraryMovePlanner(availableCapacity: { _ in .max })
        XCTAssertNoThrow(try planner.checkSpace(for: try planner.plan(root: root, folders: ["ROMs"]), at: root))
    }

    func testDefaultCapacityReadsTheVolume() throws {
        XCTAssertGreaterThan(try LibraryMovePlanner().availableCapacity(root), 0)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `<Class>` = `LibraryMovePlannerTests`. Expected: `cannot find 'LibraryMovePlanner' in scope`.

- [ ] **Step 3: Create `LibraryMovePlanner.swift`**

```swift
//
//  LibraryMovePlanner.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Step 1 of a move: list the regular files under the chosen folders, total their size and
//  check the destination volume can hold a second copy (the source is deleted only after the
//  switch, so for a same-volume move the full size must be free).
//

import Foundation
import PVLogging

public struct LibraryMovePlan: Sendable, Equatable {
    public struct Item: Sendable, Equatable {
        /// Relative to the root, e.g. `ROMs/com.provenance.snes/Game.sfc`.
        public let relativePath: String
        public let size: Int64
        public let modified: Date?
    }

    public let items: [Item]
    public var totalBytes: Int64 { items.reduce(0) { $0 + $1.size } }
}

public struct LibraryMovePlanner: Sendable {
    /// Free space must cover the plan plus the larger of this and 5% of the plan.
    public static let minimumHeadroomBytes: Int64 = 200 * 1024 * 1024

    private let fileManager: FileManager
    /// Free bytes on the volume holding the URL. Injected for tests.
    public let availableCapacity: @Sendable (URL) throws -> Int64

    public init(fileManager: FileManager = .default,
                availableCapacity: @escaping @Sendable (URL) throws -> Int64 = LibraryMovePlanner.volumeCapacity) {
        self.fileManager = fileManager
        self.availableCapacity = availableCapacity
    }

    public static func requiredBytes(for bytes: Int64) -> Int64 {
        bytes + max(minimumHeadroomBytes, bytes / 20)
    }

    /// `volumeAvailableCapacityForImportantUsage`: what iOS would free up for user-initiated work.
    public static func volumeCapacity(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        return values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
    }

    /// Regular files under `root/<folder>` for each folder that exists. Hidden entries, anything
    /// whose name contains `.realm`, and the journal file name are never planned.
    public func plan(root: URL, folders: [String]) throws -> LibraryMovePlan {
        var items: [LibraryMovePlan.Item] = []
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        for folder in folders {
            let folderURL = root.appendingPathComponent(folder, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
                WLOG("LibraryMove: cannot enumerate \(folderURL.path)")
                continue
            }
            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
                let name = url.lastPathComponent
                if name.contains(LibraryMoveFolders.realmMarker) || LibraryMoveFolders.neverMoved.contains(name) { continue }
                guard let relative = Self.relativePath(of: url, under: root) else { continue }
                items.append(.init(relativePath: relative, size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate))
            }
        }
        return LibraryMovePlan(items: items.sorted { $0.relativePath < $1.relativePath })
    }

    public func checkSpace(for plan: LibraryMovePlan, at destinationRoot: URL) throws {
        let required = Self.requiredBytes(for: plan.totalBytes)
        let available = try availableCapacity(destinationRoot)
        guard available >= required else {
            throw LibraryMoveError.insufficientSpace(required: required, available: available)
        }
    }

    /// Strips `root` from `url`, accepting either side in its raw or symlink-resolved form (`/var` vs `/private/var`).
    static func relativePath(of url: URL, under root: URL) -> String? {
        let candidates = [url.standardizedFileURL.path, url.resolvingSymlinksInPath().path]
        let bases = [root.standardizedFileURL.path, root.resolvingSymlinksInPath().path].map { $0.hasSuffix("/") ? $0 : $0 + "/" }
        for path in candidates {
            for base in bases where path.hasPrefix(base) {
                return String(path.dropFirst(base.count))
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run to verify pass** — `<Class>` = `LibraryMovePlannerTests`. Expected: 8 passes. If `testRelativePathsSurviveThePrivateVarSymlink` fails on the simulator because `temporaryDirectory` has no symlink, it still must pass (both forms are equal then); investigate only if it fails.

- [ ] **Step 5: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMovePlanner.swift
git add PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMovePlanner.swift PVLibrary/Tests/PVLibraryTests/LibraryMovePlannerTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): library move planner with free-space check" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: File copier — copy, verify, conflicts — `sonnet`

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveFileCopier.swift`
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryMoveFileCopierTests.swift`

**Interfaces:**
- Consumes: `LibraryMoveFolders`, `LibraryMoveJournal.Entry`, `LibraryMoveError` (Task 2), `LibraryMovePlan.Item` (Task 3), `MD5Provider` (PVHashing).
- Produces: `LibraryMoveFileCopier(fileManager:md5Provider:)`, `func transfer(_ item: LibraryMovePlan.Item, from sourceRoot: URL, to destinationRoot: URL) throws -> LibraryMoveJournal.Entry?` (`nil` when the source vanished), `func verify(_ url: URL, expectedSize: Int64, expectedMD5: String?) -> Bool`, `static func needsMD5(_ relativePath: String) -> Bool`, `static func conflictPath(for relativePath: String, under destinationRoot: URL, fileManager: FileManager) -> String`.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  LibraryMoveFileCopierTests.swift
//  PVLibraryTests
//

import XCTest
import PVHashing
@testable import PVFileSystem

/// MD5 that returns whatever the test says, so verification failures can be forced.
private final class StubMD5: MD5Provider, @unchecked Sendable {
    var answers: [String: String] = [:]   // path suffix → md5
    var fallback: (URL) -> String? = { FileManager.default.md5ForFile(at: $0, fromOffset: 0) }
    func md5ForFile(at url: URL, fromOffset offset: UInt) -> String? {
        for (suffix, md5) in answers where url.path.hasSuffix(suffix) { return md5 }
        return fallback(url)
    }
}

final class LibraryMoveFileCopierTests: XCTestCase {
    private var src: URL!
    private var dst: URL!

    override func setUpWithError() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryMoveFileCopierTests/\(UUID().uuidString)", isDirectory: true)
        src = base.appendingPathComponent("src", isDirectory: true)
        dst = base.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: src.deletingLastPathComponent())
    }

    private func write(_ root: URL, _ relativePath: String, _ text: String) throws -> LibraryMovePlan.Item {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return .init(relativePath: relativePath, size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate)
    }

    private func read(_ root: URL, _ relativePath: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func testCopiesIntoAFreshDestinationAndRecordsMD5ForROMs() throws {
        let item = try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom bytes")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .copied)
        XCTAssertEqual(entry?.size, item.size)
        XCTAssertEqual(entry?.md5, FileManager.default.md5ForFile(at: src.appendingPathComponent(item.relativePath), fromOffset: 0))
        XCTAssertEqual(read(dst, "ROMs/com.provenance.snes/Game.sfc"), "rom bytes")
        XCTAssertEqual(read(src, "ROMs/com.provenance.snes/Game.sfc"), "rom bytes", "the source is left for cleanup")
    }

    func testSizeOnlyFoldersSkipMD5() throws {
        let item = try write(src, "Save States/Game/s.svs", "state")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .copied)
        XCTAssertNil(entry?.md5)
        XCTAssertTrue(LibraryMoveFileCopier.needsMD5("ROMs/x/y"))
        XCTAssertTrue(LibraryMoveFileCopier.needsMD5("BIOS/x"))
        XCTAssertFalse(LibraryMoveFileCopier.needsMD5("Save States/x"))
    }

    func testIdenticalDestinationIsRecordedNotCopied() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "same")
        _ = try write(dst, "ROMs/a/Game.sfc", "same")
        let before = try dst.appendingPathComponent(item.relativePath).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .identical)
        let after = try dst.appendingPathComponent(item.relativePath).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        XCTAssertEqual(before, after, "an identical destination file is not rewritten")
    }

    func testDifferentDestinationSendsTheIncomingFileToConflicts() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "incoming")
        _ = try write(dst, "ROMs/a/Game.sfc", "existing")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.state, .conflict)
        XCTAssertEqual(entry?.destinationPath, "Conflicts/ROMs/a/Game.sfc")
        XCTAssertEqual(read(dst, "ROMs/a/Game.sfc"), "existing", "the destination is never overwritten")
        XCTAssertEqual(read(dst, "Conflicts/ROMs/a/Game.sfc"), "incoming")
    }

    func testSecondConflictGetsANumberedName() throws {
        _ = try write(dst, "ROMs/a/Game.sfc", "existing")
        _ = try write(dst, "Conflicts/ROMs/a/Game.sfc", "earlier conflict")
        let item = try write(src, "ROMs/a/Game.sfc", "incoming")
        let entry = try LibraryMoveFileCopier().transfer(item, from: src, to: dst)
        XCTAssertEqual(entry?.destinationPath, "Conflicts/ROMs/a/Game-2.sfc")
        XCTAssertEqual(read(dst, "Conflicts/ROMs/a/Game-2.sfc"), "incoming")
    }

    func testSameSizeDifferentContentInAnMD5FolderIsAConflict() throws {
        let item = try write(src, "BIOS/bios.bin", "aaaa")
        _ = try write(dst, "BIOS/bios.bin", "bbbb")
        XCTAssertEqual(try LibraryMoveFileCopier().transfer(item, from: src, to: dst)?.state, .conflict)
    }

    func testVanishedSourceReturnsNil() throws {
        let item = LibraryMovePlan.Item(relativePath: "ROMs/gone.sfc", size: 3, modified: nil)
        XCTAssertNil(try LibraryMoveFileCopier().transfer(item, from: src, to: dst))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dst.appendingPathComponent("ROMs/gone.sfc").path))
    }

    func testVerificationFailureRemovesThePartialCopyAndThrows() throws {
        let item = try write(src, "ROMs/a/Game.sfc", "rom")
        let md5 = StubMD5()
        md5.answers["dst/ROMs/a/Game.sfc"] = "deadbeef"   // the destination hashes "wrong" every time
        XCTAssertThrowsError(try LibraryMoveFileCopier(md5Provider: md5).transfer(item, from: src, to: dst)) { error in
            XCTAssertEqual(error as? LibraryMoveError, .verificationFailed(relativePath: "ROMs/a/Game.sfc"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: dst.appendingPathComponent("ROMs/a/Game.sfc").path))
    }

    func testVerifyChecksSizeAndOptionalMD5() throws {
        let item = try write(dst, "ROMs/a/Game.sfc", "rom")
        let url = dst.appendingPathComponent(item.relativePath)
        let copier = LibraryMoveFileCopier()
        XCTAssertTrue(copier.verify(url, expectedSize: 3, expectedMD5: nil))
        XCTAssertFalse(copier.verify(url, expectedSize: 4, expectedMD5: nil))
        XCTAssertTrue(copier.verify(url, expectedSize: 3, expectedMD5: FileManager.default.md5ForFile(at: url, fromOffset: 0)))
        XCTAssertFalse(copier.verify(url, expectedSize: 3, expectedMD5: "nope"))
        XCTAssertFalse(copier.verify(dst.appendingPathComponent("missing"), expectedSize: 0, expectedMD5: nil))
    }
}
```

- [ ] **Step 2: Run to verify failure** — `<Class>` = `LibraryMoveFileCopierTests`. Expected: `cannot find 'LibraryMoveFileCopier' in scope`.

- [ ] **Step 3: Create `LibraryMoveFileCopier.swift`**

```swift
//
//  LibraryMoveFileCopier.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Moves one planned file: copy, verify (size always; MD5 under ROMs/ and BIOS/), and the
//  conflict rule (never overwrite; a different file of the same name goes to Conflicts/).
//  The source is left in place; cleanup deletes it after the switch.
//

import Foundation
import PVHashing
import PVLogging

public struct LibraryMoveFileCopier: Sendable {
    private let fileManager: FileManager
    private let md5Provider: any MD5Provider

    public init(fileManager: FileManager = .default, md5Provider: any MD5Provider = FileManager.default) {
        self.fileManager = fileManager
        self.md5Provider = md5Provider
    }

    public static func needsMD5(_ relativePath: String) -> Bool {
        guard let top = relativePath.split(separator: "/", maxSplits: 1).first else { return false }
        return LibraryMoveFolders.md5Verified.contains(String(top))
    }

    /// Copies `item` from `sourceRoot` to `destinationRoot` and verifies the copy.
    /// - Returns: the journal entry, or `nil` when the source no longer exists (skipped, not an error).
    /// - Throws: `LibraryMoveError.verificationFailed` after one retry; file-system errors as thrown.
    public func transfer(_ item: LibraryMovePlan.Item, from sourceRoot: URL, to destinationRoot: URL) throws -> LibraryMoveJournal.Entry? {
        let source = sourceRoot.appendingPathComponent(item.relativePath)
        guard fileManager.fileExists(atPath: source.path) else {
            WLOG("LibraryMove: \(item.relativePath) disappeared before it was copied; skipping")
            return nil
        }
        let values = try source.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = Int64(values.fileSize ?? 0)
        let md5 = Self.needsMD5(item.relativePath) ? md5Provider.md5ForFile(at: source, fromOffset: 0) : nil

        let destination = destinationRoot.appendingPathComponent(item.relativePath)
        var destinationPath: String?
        var target = destination
        var state = LibraryMoveJournal.Entry.State.copied
        if fileManager.fileExists(atPath: destination.path) {
            if verify(destination, expectedSize: size, expectedMD5: md5) {
                return .init(size: size, md5: md5, modified: values.contentModificationDate, state: .identical, destinationPath: nil)
            }
            destinationPath = Self.conflictPath(for: item.relativePath, under: destinationRoot, fileManager: fileManager)
            target = destinationRoot.appendingPathComponent(destinationPath!)
            state = .conflict
        }

        try copyVerified(from: source, to: target, size: size, md5: md5, relativePath: item.relativePath)
        return .init(size: size, md5: md5, modified: values.contentModificationDate, state: state, destinationPath: destinationPath)
    }

    /// `true` when the file at `url` exists with `expectedSize` bytes and, when given, `expectedMD5`.
    public func verify(_ url: URL, expectedSize: Int64, expectedMD5: String?) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true else { return false }
        guard Int64(values.fileSize ?? -1) == expectedSize else { return false }
        guard let expectedMD5 else { return true }
        return md5Provider.md5ForFile(at: url, fromOffset: 0)?.lowercased() == expectedMD5.lowercased()
    }

    /// `Conflicts/<relativePath>`, then `Conflicts/<dir>/<name>-2.<ext>`, `-3`, … until free.
    public static func conflictPath(for relativePath: String, under destinationRoot: URL, fileManager: FileManager) -> String {
        let base = "\(LibraryMoveFolders.conflicts)/\(relativePath)"
        if !fileManager.fileExists(atPath: destinationRoot.appendingPathComponent(base).path) { return base }
        let ns = base as NSString
        let ext = ns.pathExtension
        let stem = ns.deletingPathExtension
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem)-\(n)" : "\(stem)-\(n).\(ext)"
            if !fileManager.fileExists(atPath: destinationRoot.appendingPathComponent(candidate).path) { return candidate }
            n += 1
        }
    }

    private func copyVerified(from source: URL, to target: URL, size: Int64, md5: String?, relativePath: String) throws {
        try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        for attempt in 1...2 {
            if fileManager.fileExists(atPath: target.path) { try fileManager.removeItem(at: target) }
            try fileManager.copyItem(at: source, to: target)
            if verify(target, expectedSize: size, expectedMD5: md5) { return }
            WLOG("LibraryMove: verification of \(relativePath) failed (attempt \(attempt))")
        }
        try? fileManager.removeItem(at: target)
        throw LibraryMoveError.verificationFailed(relativePath: relativePath)
    }
}
```

- [ ] **Step 4: Run to verify pass** — `<Class>` = `LibraryMoveFileCopierTests`. Expected: 9 passes.

- [ ] **Step 5: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveFileCopier.swift
git add PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveFileCopier.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveFileCopierTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): verified file copier with Conflicts/ rule" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Engine — start, resume, cancel (up to the switch) — `sonnet`

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift`
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryMoveEngineTests.swift`

**Interfaces:**
- Consumes: Tasks 2–4.
- Produces: `actor LibraryMoveEngine` with `init(journalStore:fileManager:md5Provider:planner:switchLocation:)`, `func start(_ request: LibraryMoveRequest, progress: (@Sendable (LibraryMoveProgress) -> Void)?) async throws -> LibraryMoveOutcome`, `func resume(_ journal: LibraryMoveJournal, sourceRoot: URL, destinationRoot: URL, progress:) async throws -> LibraryMoveOutcome`, `func cancel()`, `var isRunning: Bool`. Internal: `static let journalFlushInterval = 25`, `func copyPhase(...)`, `func performSwitch(...)`, `func rollback(...)`. Task 6 adds `cleanupPhase` in an extension; `resume` dispatches to it when `journal.phase != .copying` — in this task that branch throws `LibraryMoveError.journalMismatch` as a placeholder-free stand-in that Task 6 replaces (the test in Task 6 pins the real behaviour).

- [ ] **Step 1: Write the failing tests**

```swift
//
//  LibraryMoveEngineTests.swift
//  PVLibraryTests
//

import XCTest
import PVHashing
@testable import PVFileSystem

final class LibraryMoveEngineTests: XCTestCase {
    private var base: URL!
    private var src: URL!
    private var dst: URL!
    private var store: LibraryMoveJournalStore!
    private final class Switch: @unchecked Sendable { var calls: [LibraryLocation] = [] }
    private var switched: Switch!

    /// Progress closures are `@Sendable`, so they can't mutate captured `var`s; collect through a box instead.
    private final class ProgressBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _reports: [LibraryMoveProgress] = []
        var reports: [LibraryMoveProgress] { lock.lock(); defer { lock.unlock() }; return _reports }
        func append(_ p: LibraryMoveProgress) { lock.lock(); _reports.append(p); lock.unlock() }
    }
    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = false
        /// Sets the flag; returns `true` only for the call that flipped it.
        func trip() -> Bool { lock.lock(); defer { lock.unlock() }; if _value { return false }; _value = true; return true }
    }
    private final class IntBox: @unchecked Sendable { var value: Int? }

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryMoveEngineTests/\(UUID().uuidString)", isDirectory: true)
        src = base.appendingPathComponent("group/Documents", isDirectory: true)
        dst = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
        store = LibraryMoveJournalStore(url: base.appendingPathComponent("support/LibraryMove/move-journal.json"))
        switched = Switch()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    private func engine(md5: any MD5Provider = FileManager.default, capacity: Int64 = .max) -> LibraryMoveEngine {
        let s = switched!
        return LibraryMoveEngine(journalStore: store, md5Provider: md5,
                                 planner: LibraryMovePlanner(availableCapacity: { _ in capacity }),
                                 switchLocation: { s.calls.append($0) })
    }

    private func request(keepCopy: Bool = false) -> LibraryMoveRequest {
        .init(source: .appGroup, destination: .appStorage, sourceRoot: src, destinationRoot: dst, folders: LibraryMoveFolders.appGroupExit, keepCopy: keepCopy)
    }

    @discardableResult
    private func write(_ root: URL, _ relativePath: String, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func read(_ root: URL, _ relativePath: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    // MARK: start

    func testStartCopiesVerifiesSwitchesAndLeavesTheJournalInSwitchedPhase() async throws {
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(src, "BIOS/scph1001.bin", "bios")
        try write(src, "Save States/Game/s.svs", "state")
        try write(src, "Skins/leave.me", "not moved")

        let seen = ProgressBox()
        let outcome = try await engine().start(request()) { seen.append($0) }

        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(switched.calls, [.appStorage])
        XCTAssertEqual(read(dst, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertEqual(read(dst, "BIOS/scph1001.bin"), "bios")
        XCTAssertEqual(read(dst, "Save States/Game/s.svs"), "state")
        XCTAssertNil(read(dst, "Skins/leave.me"))
        XCTAssertEqual(read(src, "ROMs/com.provenance.snes/Game.sfc"), "rom", "sources stay until cleanup on the next launch")

        let journal = store.load()
        XCTAssertEqual(journal?.phase, .switched)
        XCTAssertEqual(journal?.entries.count, 3)
        XCTAssertEqual(journal?.entries["ROMs/com.provenance.snes/Game.sfc"]?.state, .copied)
        XCTAssertNotNil(journal?.entries["ROMs/com.provenance.snes/Game.sfc"]?.md5)
        XCTAssertEqual(seen.reports.last?.phase, .switched)
        XCTAssertEqual(seen.reports.last?.filesDone, 3)
        XCTAssertEqual(seen.reports.last?.filesTotal, 3)
    }

    func testStartWithNothingToMoveStillSwitches() async throws {
        let outcome = try await engine().start(request(), progress: nil)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(switched.calls, [.appStorage])
        XCTAssertEqual(store.load()?.phase, .switched)
    }

    func testStartRejectsUnsupportedPairsBeforeTouchingDisk() async throws {
        let bad = LibraryMoveRequest(source: .appStorage, destination: .iCloudDrive, sourceRoot: src, destinationRoot: dst, folders: ["ROMs"], keepCopy: false)
        do {
            _ = try await engine().start(bad, progress: nil)
            XCTFail("expected unsupportedMove")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .unsupportedMove(from: .appStorage, to: .iCloudDrive))
        }
        XCTAssertNil(store.load())
    }

    func testStartRefusesWhenSpaceIsShort() async throws {
        try write(src, "ROMs/a.sfc", "rom")
        do {
            _ = try await engine(capacity: 10).start(request(), progress: nil)
            XCTFail("expected insufficientSpace")
        } catch let error as LibraryMoveError {
            guard case .insufficientSpace = error else { return XCTFail("\(error)") }
        }
        XCTAssertNil(store.load(), "no journal is written when the plan is refused")
        XCTAssertTrue(switched.calls.isEmpty)
    }

    func testStartRefusesWhileAJournalExists() async throws {
        var journal = LibraryMoveJournal(request: request())
        journal.phase = .copying
        try store.save(journal)
        do {
            _ = try await engine().start(request(), progress: nil)
            XCTFail("expected moveInProgress")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .moveInProgress)
        }
    }

    func testVerificationFailureStopsBeforeTheSwitchAndKeepsTheJournal() async throws {
        try write(src, "ROMs/a/Bad.sfc", "rom")
        try write(src, "BIOS/ok.bin", "bios")
        let md5 = FailingMD5(badSuffix: "app/Documents/ROMs/a/Bad.sfc")
        do {
            _ = try await engine(md5: md5).start(request(), progress: nil)
            XCTFail("expected verificationFailed")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .verificationFailed(relativePath: "ROMs/a/Bad.sfc"))
        }
        XCTAssertTrue(switched.calls.isEmpty)
        let journal = store.load()
        XCTAssertEqual(journal?.phase, .copying)
        XCTAssertEqual(journal?.entries["BIOS/ok.bin"]?.state, .copied, "verified files before the failure stay journaled so the retry resumes")
        XCTAssertNil(journal?.entries["ROMs/a/Bad.sfc"])
    }

    func testVanishedSourceIsSkippedNotFatal() async throws {
        // Review Focus 2: the planner saw a file that is gone by copy time.
        try write(src, "ROMs/a/Here.sfc", "rom")
        let gone = try write(src, "ROMs/a/Gone.sfc", "rom")
        let planner = LibraryMovePlanner(availableCapacity: { _ in .max })
        let plan = try planner.plan(root: src, folders: ["ROMs"])
        XCTAssertEqual(plan.items.count, 2)
        try FileManager.default.removeItem(at: gone)

        let s = switched!
        let e = LibraryMoveEngine(journalStore: store, planner: planner, switchLocation: { s.calls.append($0) })
        let outcome = try await e.start(request(), progress: nil)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(store.load()?.entries.keys.sorted(), ["ROMs/a/Here.sfc"])
    }

    // MARK: resume

    func testResumeAfterCrashMidCopyRecopiesOnlyWhatIsNotVerified() async throws {
        try write(src, "ROMs/a/Done.sfc", "done")
        try write(src, "ROMs/a/Partial.sfc", "full content")
        try write(src, "ROMs/a/Missing.sfc", "missing")
        // Simulate the crash: Done.sfc copied + journaled, Partial.sfc half-written and not journaled, Missing.sfc untouched.
        try write(dst, "ROMs/a/Done.sfc", "done")
        try write(dst, "ROMs/a/Partial.sfc", "full")
        var journal = LibraryMoveJournal(request: request())
        let doneURL = src.appendingPathComponent("ROMs/a/Done.sfc")
        journal.entries["ROMs/a/Done.sfc"] = .init(size: 4, md5: FileManager.default.md5ForFile(at: doneURL, fromOffset: 0), modified: nil, state: .copied, destinationPath: nil)
        try store.save(journal)

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(dst, "ROMs/a/Partial.sfc"), "full content", "a partial destination file is recopied, not treated as a conflict")
        XCTAssertEqual(read(dst, "ROMs/a/Missing.sfc"), "missing")
        XCTAssertNil(read(dst, "Conflicts/ROMs/a/Partial.sfc"))
        let after = store.load()
        XCTAssertEqual(after?.phase, .switched)
        XCTAssertEqual(after?.entries.count, 3)
        XCTAssertEqual(switched.calls, [.appStorage])
    }

    func testResumeIsIdempotentWhenEverythingIsAlreadyCopied() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        _ = try await engine().start(request(), progress: nil)
        let first = store.load()!
        // Simulate a relaunch that never reached cleanup: phase is .switched, resume must not recopy or re-switch.
        let outcome = try await engine().resume(first, sourceRoot: src, destinationRoot: dst, progress: nil)
        XCTAssertNotEqual(outcome, .switched)
        XCTAssertEqual(switched.calls.count, 1)
    }

    // MARK: cancel

    func testCancelBeforeSwitchRollsBackCopiesButKeepsPreexistingIdenticalFiles() async throws {
        for i in 0..<60 { try write(src, "ROMs/a/Game\(i).sfc", "rom \(i)") }
        try write(src, "ROMs/a/Same.sfc", "same")
        try write(dst, "ROMs/a/Same.sfc", "same")
        try write(dst, "ROMs/a/Game3.sfc", "different")

        let e = engine()
        let cancelled = Flag()
        let outcome = try await e.start(request()) { p in
            if p.filesDone >= 10, cancelled.trip() { Task { await e.cancel() } }
        }

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertTrue(switched.calls.isEmpty)
        XCTAssertNil(store.load())
        XCTAssertEqual(read(dst, "ROMs/a/Same.sfc"), "same", "identical pre-existing files are untouched")
        XCTAssertEqual(read(dst, "ROMs/a/Game3.sfc"), "different", "the destination's own file is untouched")
        XCTAssertNil(read(dst, "Conflicts/ROMs/a/Game3.sfc"), "the conflict copy is rolled back")
        let copied = (try? FileManager.default.contentsOfDirectory(atPath: dst.appendingPathComponent("ROMs/a").path)) ?? []
        XCTAssertEqual(Set(copied), ["Same.sfc", "Game3.sfc"], "every file the engine copied is gone")
        for i in 0..<60 { XCTAssertEqual(read(src, "ROMs/a/Game\(i).sfc"), "rom \(i)", "sources are never touched by a cancel") }
    }

    func testCancelAfterSwitchIsIgnored() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        let e = engine()
        _ = try await e.start(request(), progress: nil)
        await e.cancel()
        XCTAssertEqual(store.load()?.phase, .switched)
        XCTAssertEqual(read(dst, "ROMs/a/Game.sfc"), "rom")
    }

    func testJournalIsFlushedEveryTwentyFiveFiles() async throws {
        for i in 0..<30 { try write(src, "ROMs/a/Game\(i).sfc", "rom \(i)") }
        let e = engine()
        let snapshot = IntBox()
        let store = self.store!
        _ = try await e.start(request()) { p in
            if p.filesDone == LibraryMoveEngine.journalFlushInterval, snapshot.value == nil { snapshot.value = store.load()?.entries.count }
        }
        XCTAssertEqual(snapshot.value, LibraryMoveEngine.journalFlushInterval)
    }
}

/// Real MD5 everywhere except one destination path, which always hashes wrong.
final class FailingMD5: MD5Provider, @unchecked Sendable {
    let badSuffix: String
    init(badSuffix: String) { self.badSuffix = badSuffix }
    func md5ForFile(at url: URL, fromOffset offset: UInt) -> String? {
        url.path.hasSuffix(badSuffix) ? "00000000000000000000000000000000" : FileManager.default.md5ForFile(at: url, fromOffset: offset)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `<Class>` = `LibraryMoveEngineTests`. Expected: `cannot find 'LibraryMoveEngine' in scope`.

- [ ] **Step 3: Create `LibraryMoveEngine.swift`**

```swift
//
//  LibraryMoveEngine.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Plan → copy+verify → switch, journaled so it resumes after a crash and cancellable (with
//  rollback) until the switch. Cleanup (delete sources) is `LibraryMoveEngine+Cleanup.swift`
//  and runs on the launch after the switch.
//  Spec: docs/superpowers/specs/2026-10-11-library-storage-locations-design.md
//

import Foundation
import PVHashing
import PVLogging

public actor LibraryMoveEngine {
    /// The journal is written after this many verified files (and at every phase change).
    static let journalFlushInterval = 25

    /// Pairs the engine knows how to move. Phase 5 adds iCloud Drive both ways.
    static let supportedMoves: Set<[LibraryLocation]> = [[.appGroup, .appStorage]]

    let journalStore: LibraryMoveJournalStore
    let fileManager: FileManager
    let planner: LibraryMovePlanner
    let copier: LibraryMoveFileCopier
    /// Writes the setting that names the destination. `LibraryLocation.switchStored(to:)` in production.
    let switchLocation: @Sendable (LibraryLocation) throws -> Void

    public private(set) var isRunning = false
    private var cancelRequested = false

    public init(journalStore: LibraryMoveJournalStore,
                fileManager: FileManager = .default,
                md5Provider: any MD5Provider = FileManager.default,
                planner: LibraryMovePlanner = LibraryMovePlanner(),
                switchLocation: @escaping @Sendable (LibraryLocation) throws -> Void) {
        self.journalStore = journalStore
        self.fileManager = fileManager
        self.planner = planner
        self.copier = LibraryMoveFileCopier(fileManager: fileManager, md5Provider: md5Provider)
        self.switchLocation = switchLocation
    }

    /// Ask the running copy to stop. Honoured between files, only before the switch.
    public func cancel() {
        cancelRequested = true
    }

    // MARK: - Start

    public func start(_ request: LibraryMoveRequest,
                      progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        guard Self.supportedMoves.contains([request.source, request.destination]) else {
            throw LibraryMoveError.unsupportedMove(from: request.source, to: request.destination)
        }
        guard !isRunning, journalStore.load() == nil else { throw LibraryMoveError.moveInProgress }

        let plan = try planner.plan(root: request.sourceRoot, folders: request.folders)
        try planner.checkSpace(for: plan, at: request.destinationRoot)

        var journal = LibraryMoveJournal(request: request)
        try journalStore.save(journal)
        ILOG("LibraryMove: starting \(request.source.rawValue) → \(request.destination.rawValue): \(plan.items.count) files, \(plan.totalBytes) bytes")
        return try await run(&journal, plan: plan, sourceRoot: request.sourceRoot, destinationRoot: request.destinationRoot, progress: progress)
    }

    // MARK: - Resume

    /// Continues a journaled move. `copying` → finish the copy and switch. Anything later → cleanup.
    public func resume(_ journal: LibraryMoveJournal, sourceRoot: URL, destinationRoot: URL,
                       progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        guard !isRunning else { throw LibraryMoveError.moveInProgress }
        var journal = journal
        switch journal.phase {
        case .copying:
            let plan = try planner.plan(root: sourceRoot, folders: journal.folders)
            ILOG("LibraryMove: resuming copy, \(journal.entries.count) of \(plan.items.count) files already journaled")
            return try await run(&journal, plan: plan, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)
        case .switched, .cleaning:
            return try await cleanup(&journal, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)
        }
    }

    // MARK: - Copy phase

    private func run(_ journal: inout LibraryMoveJournal, plan: LibraryMovePlan, sourceRoot: URL, destinationRoot: URL,
                     progress: (@Sendable (LibraryMoveProgress) -> Void)?) async throws -> LibraryMoveOutcome {
        isRunning = true
        cancelRequested = false
        defer { isRunning = false }

        let copied = try await copyPhase(&journal, plan: plan, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)
        guard copied else {
            try rollback(journal, destinationRoot: destinationRoot)
            return .cancelled
        }
        try performSwitch(&journal)
        progress?(progressReport(journal, plan: plan, filesDone: plan.items.count, bytesDone: plan.totalBytes, current: nil))
        return .switched
    }

    /// Copies every planned file that the journal doesn't already record as verified.
    /// - Returns: `false` when cancelled (the caller rolls back).
    func copyPhase(_ journal: inout LibraryMoveJournal, plan: LibraryMovePlan, sourceRoot: URL, destinationRoot: URL,
                   progress: (@Sendable (LibraryMoveProgress) -> Void)?) async throws -> Bool {
        var filesDone = 0
        var bytesDone: Int64 = 0
        var sinceFlush = 0
        for item in plan.items {
            if cancelRequested {
                ILOG("LibraryMove: cancelled after \(filesDone) files")
                return false
            }
            if let existing = journal.entries[item.relativePath], destinationIntact(existing, relativePath: item.relativePath, destinationRoot: destinationRoot) {
                filesDone += 1
                bytesDone += existing.size
                continue
            }
            // A destination file that is not journaled is a partial copy from the interrupted run,
            // unless it verifies — `transfer` records that as `identical` rather than a conflict.
            if journal.entries[item.relativePath] == nil {
                try removePartialCopy(item, destinationRoot: destinationRoot)
            }
            let entry: LibraryMoveJournal.Entry?
            do {
                entry = try copier.transfer(item, from: sourceRoot, to: destinationRoot)
            } catch {
                // Keep what was verified so far: the next attempt resumes instead of recopying.
                journal.updatedAt = Date()
                try? journalStore.save(journal)
                throw error
            }
            if let entry {
                journal.entries[item.relativePath] = entry
                bytesDone += entry.size
            }
            filesDone += 1
            sinceFlush += 1
            if sinceFlush >= Self.journalFlushInterval {
                journal.updatedAt = Date()
                try journalStore.save(journal)
                sinceFlush = 0
            }
            progress?(progressReport(journal, plan: plan, filesDone: filesDone, bytesDone: bytesDone, current: item.relativePath))
            await Task.yield()
        }
        journal.updatedAt = Date()
        try journalStore.save(journal)
        return true
    }

    /// A journaled entry still holds: its destination file exists with the recorded size.
    private func destinationIntact(_ entry: LibraryMoveJournal.Entry, relativePath: String, destinationRoot: URL) -> Bool {
        let path = entry.destinationPath ?? relativePath
        return copier.verify(destinationRoot.appendingPathComponent(path), expectedSize: entry.size, expectedMD5: nil)
    }

    /// An unjournaled destination file whose size differs from the source is a torn copy: remove it so
    /// `transfer` copies afresh instead of filing it under Conflicts/. Same-size files are left for `transfer` to verify.
    private func removePartialCopy(_ item: LibraryMovePlan.Item, destinationRoot: URL) throws {
        let destination = destinationRoot.appendingPathComponent(item.relativePath)
        guard let values = try? destination.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true else { return }
        if Int64(values.fileSize ?? -1) != item.size {
            WLOG("LibraryMove: removing torn copy \(item.relativePath)")
            try fileManager.removeItem(at: destination)
        }
    }

    private func progressReport(_ journal: LibraryMoveJournal, plan: LibraryMovePlan, filesDone: Int, bytesDone: Int64, current: String?) -> LibraryMoveProgress {
        .init(phase: journal.phase, filesDone: filesDone, filesTotal: plan.items.count, bytesDone: bytesDone, bytesTotal: plan.totalBytes, currentPath: current)
    }

    // MARK: - Switch

    func performSwitch(_ journal: inout LibraryMoveJournal) throws {
        try switchLocation(journal.destination)
        journal.phase = .switched
        journal.updatedAt = Date()
        try journalStore.save(journal)
        ILOG("LibraryMove: switched to \(journal.destination.rawValue); cleanup runs at the next launch")
    }

    // MARK: - Rollback (cancel before switch)

    /// Deletes what this move put in the destination: `copied` files at their path and `conflict`
    /// copies at their Conflicts/ path. `identical` files pre-existed and stay. Then the journal goes.
    func rollback(_ journal: LibraryMoveJournal, destinationRoot: URL) throws {
        for (relativePath, entry) in journal.entries where entry.state != .identical {
            let url = destinationRoot.appendingPathComponent(entry.destinationPath ?? relativePath)
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
        // Cancel is checked before each transfer, so there is no half-written file to remove. Only tidy
        // folders this move wrote into (plus Conflicts/), never a pre-existing empty folder of the destination.
        let touched = Set(journal.entries.keys.compactMap { $0.split(separator: "/", maxSplits: 1).first.map(String.init) })
        removeEmptyDirectories(under: destinationRoot, folders: Array(touched) + [LibraryMoveFolders.conflicts])
        try journalStore.delete()
    }

    /// Removes now-empty directories below `root/<folder>` bottom-up, then the folder itself if it is empty.
    func removeEmptyDirectories(under root: URL, folders: [String]) {
        for folder in folders {
            let top = root.appendingPathComponent(folder, isDirectory: true)
            guard let enumerator = fileManager.enumerator(at: top, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { continue }
            var directories: [URL] = []
            for case let url as URL in enumerator where (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                directories.append(url)
            }
            for dir in (directories + [top]).sorted(by: { $0.path.count > $1.path.count }) {
                if let contents = try? fileManager.contentsOfDirectory(atPath: dir.path), contents.isEmpty {
                    try? fileManager.removeItem(at: dir)
                }
            }
        }
    }
}
```

In this task also add a temporary `cleanup` so the file compiles — put it at the bottom of `LibraryMoveEngine.swift`, and Task 6 moves the real one into the extension file:

```swift
extension LibraryMoveEngine {
    func cleanup(_ journal: inout LibraryMoveJournal, sourceRoot: URL, destinationRoot: URL,
                 progress: (@Sendable (LibraryMoveProgress) -> Void)?) async throws -> LibraryMoveOutcome {
        // Task 6 replaces this with the delta sweep + delete; until then a switched journal is left alone.
        ILOG("LibraryMove: cleanup not implemented yet; journal left in phase \(journal.phase.rawValue)")
        return .nothingToDo
    }
}
```

- [ ] **Step 4: Run to verify pass** — `<Class>` = `LibraryMoveEngineTests`. Expected: 12 passes. `testResumeIsIdempotentWhenEverythingIsAlreadyCopied` passes via the stand-in (`.nothingToDo != .switched`). If `testCancelBeforeSwitchRollsBack...` is flaky because cancel lands after the loop finishes, raise the file count in the test from 60 to 200; the `await Task.yield()` between files is what gives `cancel()` its chance.

- [ ] **Step 5: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift
git add PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveEngineTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): journaled move engine with resume and cancel" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Engine cleanup — delta sweep, delete journaled sources, keep-copy — `sonnet`

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine+Cleanup.swift`
- Modify: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift` (delete the stand-in `cleanup` extension at the bottom)
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryMoveCleanupTests.swift`

**Interfaces:**
- Consumes: Task 5's `copyPhase`, `removeEmptyDirectories`, `journalStore`, `copier`, `planner`, `fileManager`.
- Produces: `func cleanup(_ journal: inout LibraryMoveJournal, sourceRoot: URL, destinationRoot: URL, progress:) async throws -> LibraryMoveOutcome` returning `.cleanedUp`; `static func changedSinceJournal(_ item: LibraryMovePlan.Item, entry: LibraryMoveJournal.Entry) -> Bool`.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  LibraryMoveCleanupTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryMoveCleanupTests: XCTestCase {
    private var base: URL!
    private var src: URL!
    private var dst: URL!
    private var store: LibraryMoveJournalStore!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryMoveCleanupTests/\(UUID().uuidString)", isDirectory: true)
        src = base.appendingPathComponent("group/Documents", isDirectory: true)
        dst = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
        store = LibraryMoveJournalStore(url: base.appendingPathComponent("support/move-journal.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    private func engine() -> LibraryMoveEngine {
        LibraryMoveEngine(journalStore: store, planner: LibraryMovePlanner(availableCapacity: { _ in .max }), switchLocation: { _ in })
    }

    private func request(keepCopy: Bool = false) -> LibraryMoveRequest {
        .init(source: .appGroup, destination: .appStorage, sourceRoot: src, destinationRoot: dst, folders: LibraryMoveFolders.appGroupExit, keepCopy: keepCopy)
    }

    @discardableResult
    private func write(_ root: URL, _ relativePath: String, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func read(_ root: URL, _ relativePath: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func exists(_ root: URL, _ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    /// Runs a full move up to the switch, as the first launch would.
    private func switchedJournal() async throws -> LibraryMoveJournal {
        _ = try await engine().start(request(), progress: nil)
        return try XCTUnwrap(store.load())
    }

    func testCleanupDeletesJournaledSourcesAndEmptiedFoldersAndTheJournal() async throws {
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(src, "Save States/Game/s.svs", "state")
        try write(src, "Skins/leave.me", "not ours")
        let journal = try await switchedJournal()

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertFalse(exists(src, "ROMs/com.provenance.snes/Game.sfc"))
        XCTAssertFalse(exists(src, "ROMs"), "emptied folders are removed")
        XCTAssertFalse(exists(src, "Save States"))
        XCTAssertEqual(read(src, "Skins/leave.me"), "not ours", "unlisted folders are untouched")
        XCTAssertEqual(read(dst, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertNil(store.load())
    }

    func testCleanupDeltaSweepCopiesFilesWrittenAfterTheSwitch() async throws {
        // Review Focus 3: the old process kept writing to the source until the user relaunched.
        try write(src, "ROMs/a/Game.sfc", "rom")
        try write(src, "Battery States/Game/Game.srm", "save v1")
        let journal = try await switchedJournal()
        try write(src, "Battery States/Game/Game.srm", "save v2 longer")          // changed after journaling
        try write(src, "Save States/Game/new.svs", "written in the window")       // brand new

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(dst, "Battery States/Game/Game.srm"), "save v1", "the verified copy is never overwritten")
        XCTAssertEqual(read(dst, "Conflicts/Battery States/Game/Game.srm"), "save v2 longer", "the newer source goes to Conflicts/ for the user to pick")
        XCTAssertEqual(read(dst, "Save States/Game/new.svs"), "written in the window")
        XCTAssertFalse(exists(src, "Battery States"))
        XCTAssertFalse(exists(src, "Save States"))
    }

    func testChangedSinceJournalUsesSizeThenSecondPrecisionMtime() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = LibraryMoveJournal.Entry(size: 10, md5: nil, modified: t, state: .copied, destinationPath: nil)
        XCTAssertFalse(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 10, modified: t.addingTimeInterval(0.4)), entry: entry), "sub-second drift from ISO-8601 round-trip is not a change")
        XCTAssertTrue(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 11, modified: t), entry: entry))
        XCTAssertTrue(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 10, modified: t.addingTimeInterval(2)), entry: entry))
        XCTAssertFalse(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 10, modified: nil), entry: entry), "no mtime available: trust the size")
    }

    func testKeepCopyLeavesSourcesButStillFinishes() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        _ = try await engine().start(request(keepCopy: true), progress: nil)
        let journal = try XCTUnwrap(store.load())

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(src, "ROMs/a/Game.sfc"), "rom")
        XCTAssertEqual(read(dst, "ROMs/a/Game.sfc"), "rom")
        XCTAssertNil(store.load())
    }

    func testCleanupOnlyDeletesSourcesTheJournalRecords() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        let journal = try await switchedJournal()
        // A file in a listed folder that is neither journaled nor copyable (unreadable copy would throw) is not the case here;
        // instead: a hidden file the planner never saw must survive.
        try write(src, "ROMs/a/.nomedia", "hidden")

        _ = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(read(src, "ROMs/a/.nomedia"), "hidden")
        XCTAssertTrue(exists(src, "ROMs/a"), "a folder that still holds something is kept")
    }

    func testCleanupSurvivesBeingInterruptedAndResumed() async throws {
        try write(src, "ROMs/a/One.sfc", "1")
        try write(src, "ROMs/a/Two.sfc", "2")
        var journal = try await switchedJournal()
        // Simulate a crash mid-cleanup: phase already .cleaning, One.sfc already deleted from the source.
        journal.phase = .cleaning
        try store.save(journal)
        try FileManager.default.removeItem(at: src.appendingPathComponent("ROMs/a/One.sfc"))

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertFalse(exists(src, "ROMs"))
        XCTAssertEqual(read(dst, "ROMs/a/One.sfc"), "1")
        XCTAssertEqual(read(dst, "ROMs/a/Two.sfc"), "2")
        XCTAssertNil(store.load())
    }
}
```

- [ ] **Step 2: Run to verify failure** — `<Class>` = `LibraryMoveCleanupTests`. Expected: assertion failures (`.nothingToDo` instead of `.cleanedUp`) and `changedSinceJournal` not found.

- [ ] **Step 3: Delete the stand-in `cleanup` extension** from the bottom of `LibraryMoveEngine.swift` and create `LibraryMoveEngine+Cleanup.swift`:

```swift
//
//  LibraryMoveEngine+Cleanup.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The launch after the switch. The old process may have kept writing to the source until the
//  user relaunched, so first a delta sweep copies anything new or changed (a changed file whose
//  verified copy exists goes to Conflicts/, never over it), then every journaled source is
//  deleted (unless "keep a copy"), emptied folders are removed and the journal is dropped.
//  Idempotent: a crash mid-cleanup resumes here with the same journal.
//

import Foundation
import PVLogging

extension LibraryMoveEngine {
    func cleanup(_ journal: inout LibraryMoveJournal, sourceRoot: URL, destinationRoot: URL,
                 progress: (@Sendable (LibraryMoveProgress) -> Void)?) async throws -> LibraryMoveOutcome {
        isRunning = true
        defer { isRunning = false }

        if journal.phase != .cleaning {
            journal.phase = .cleaning
            journal.updatedAt = Date()
            try journalStore.save(journal)
        }

        // Delta sweep: whatever the plan sees now that the journal doesn't, or that changed since.
        let plan = try planner.plan(root: sourceRoot, folders: journal.folders)
        let delta = plan.items.filter { item in
            guard let entry = journal.entries[item.relativePath] else { return true }
            return Self.changedSinceJournal(item, entry: entry)
        }
        if !delta.isEmpty {
            // Straight to `transfer`, not `copyPhase`: its torn-copy heuristic would see "destination size differs
            // from the (changed) source" and delete the verified copy. `transfer` files the newer source under Conflicts/.
            ILOG("LibraryMove: delta sweep copying \(delta.count) files written after the switch")
            var swept = 0
            for item in delta {
                if let entry = try copier.transfer(item, from: sourceRoot, to: destinationRoot) {
                    journal.entries[item.relativePath] = entry
                }
                swept += 1
                progress?(.init(phase: .cleaning, filesDone: swept, filesTotal: delta.count, bytesDone: 0, bytesTotal: 0, currentPath: item.relativePath))
                await Task.yield()
            }
            journal.updatedAt = Date()
            try journalStore.save(journal)
        }

        if journal.keepCopy {
            ILOG("LibraryMove: keeping a copy at the source as requested")
        } else {
            var deleted = 0
            for relativePath in journal.entries.keys {
                let url = sourceRoot.appendingPathComponent(relativePath)
                guard fileManager.fileExists(atPath: url.path) else { continue }
                try fileManager.removeItem(at: url)
                deleted += 1
            }
            removeEmptyDirectories(under: sourceRoot, folders: journal.folders)
            ILOG("LibraryMove: deleted \(deleted) source files")
        }

        try journalStore.delete()
        progress?(.init(phase: .cleaning, filesDone: journal.entries.count, filesTotal: journal.entries.count,
                        bytesDone: 0, bytesTotal: 0, currentPath: nil))
        return .cleanedUp
    }

    /// Size first; then modification time at one-second precision (the journal stores ISO-8601 seconds).
    static func changedSinceJournal(_ item: LibraryMovePlan.Item, entry: LibraryMoveJournal.Entry) -> Bool {
        if item.size != entry.size { return true }
        guard let now = item.modified, let then = entry.modified else { return false }
        return now.timeIntervalSince1970.rounded(.down) != then.timeIntervalSince1970.rounded(.down)
    }
}
```

`isRunning` is `public private(set)` in Task 5; change it to `public internal(set) var isRunning = false` so this extension (same module, different file) can set it. `cancelRequested` stays private — cleanup is not cancellable by design (D8).

- [ ] **Step 4: Run both engine test classes** — `-only-testing:PVLibraryTests/LibraryMoveCleanupTests -only-testing:PVLibraryTests/LibraryMoveEngineTests`. Expected: all pass. `testResumeIsIdempotentWhenEverythingIsAlreadyCopied` (Task 5) now sees `.cleanedUp`, which still satisfies `XCTAssertNotEqual(outcome, .switched)`.

- [ ] **Step 5: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine+Cleanup.swift
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift
git add PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine+Cleanup.swift PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveEngine.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCleanupTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): post-switch cleanup with delta sweep" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Coordinator — real roots, launch resume, public entry point — `sonnet`

**Files:**
- Create: `PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift`
- Test: `PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift`

**Interfaces:**
- Consumes: `LibraryMoveEngine` (Tasks 5–6), `LibraryLocation.switchStored(to:)` / `LibraryLocation.current` (Task 1), `URL.documentsPathAppGroup` / `URL.documentsPathLocal` (Paths.swift).
- Produces: `final class LibraryMoveCoordinator: @unchecked Sendable` with `static let shared`, `init(journalStore:rootProvider:launchedLocation:switchLocation:planner:md5Provider:)`, `static func defaultRoot(for:) -> URL?`, `func resumeIfNeeded(progress:) async -> LibraryMoveOutcome?`, `func moveToAppStorage(keepCopy:progress:) async throws -> LibraryMoveOutcome`, `func cancel() async`, `var hasPendingMove: Bool`.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  LibraryMoveCoordinatorTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryMoveCoordinatorTests: XCTestCase {
    private var base: URL!
    private var group: URL!
    private var local: URL!
    private var store: LibraryMoveJournalStore!
    private final class Recorder: @unchecked Sendable { var switches: [LibraryLocation] = [] }
    private var recorder: Recorder!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryMoveCoordinatorTests/\(UUID().uuidString)", isDirectory: true)
        group = base.appendingPathComponent("group/Documents", isDirectory: true)
        local = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        store = LibraryMoveJournalStore(url: base.appendingPathComponent("support/move-journal.json"))
        recorder = Recorder()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    private func coordinator(launched: LibraryLocation, groupAvailable: Bool = true) -> LibraryMoveCoordinator {
        let r = recorder!
        let group = groupAvailable ? self.group : nil
        let local = self.local!
        return LibraryMoveCoordinator(journalStore: store,
                                      rootProvider: { location in
                                          switch location {
                                          case .appGroup: return group
                                          case .appStorage: return local
                                          case .iCloudDrive: return nil
                                          }
                                      },
                                      launchedLocation: { launched },
                                      switchLocation: { r.switches.append($0) },
                                      planner: LibraryMovePlanner(availableCapacity: { _ in .max }))
    }

    @discardableResult
    private func write(_ root: URL, _ relativePath: String, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func read(_ root: URL, _ relativePath: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func testResumeWithoutAJournalIsANoOp() async {
        let outcome = await coordinator(launched: .appGroup).resumeIfNeeded(progress: nil)
        XCTAssertNil(outcome)
        XCTAssertFalse(coordinator(launched: .appGroup).hasPendingMove)
    }

    func testMoveToAppStorageRunsTheEngineAgainstTheRealRoots() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        let c = coordinator(launched: .appGroup)
        let outcome = try await c.moveToAppStorage(keepCopy: false, progress: nil)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(recorder.switches, [.appStorage])
        XCTAssertEqual(read(local, "ROMs/a/Game.sfc"), "rom")
        XCTAssertTrue(c.hasPendingMove, "cleanup is still owed")
    }

    func testMoveToAppStorageRefusesWhenNotInTheAppGroup() async {
        do {
            _ = try await coordinator(launched: .appStorage).moveToAppStorage(keepCopy: false, progress: nil)
            XCTFail("expected unsupportedMove")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .unsupportedMove(from: .appStorage, to: .appStorage))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testResumeFinishesAnInterruptedCopyWhenStillLaunchedOnTheSource() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        var journal = LibraryMoveJournal(request: .init(source: .appGroup, destination: .appStorage, sourceRoot: group, destinationRoot: local,
                                                        folders: LibraryMoveFolders.appGroupExit, keepCopy: false))
        journal.phase = .copying
        try store.save(journal)

        let outcome = await coordinator(launched: .appGroup).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(recorder.switches, [.appStorage])
        XCTAssertEqual(read(local, "ROMs/a/Game.sfc"), "rom")
        XCTAssertEqual(store.load()?.phase, .switched)
    }

    func testResumeCleansUpWhenLaunchedOnTheDestination() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)

        let outcome = await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertNil(read(group, "ROMs/a/Game.sfc"))
        XCTAssertEqual(read(local, "ROMs/a/Game.sfc"), "rom")
        XCTAssertNil(store.load())
    }

    func testSwitchedJournalIsLeftAloneWhenThisLaunchIsStillOnTheSource() async throws {
        // The settings were written but this process still runs on the old root (the user hasn't relaunched,
        // or the settings were reset): never delete sources from here.
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)

        let outcome = await coordinator(launched: .appGroup).resumeIfNeeded(progress: nil)

        XCTAssertNil(outcome)
        XCTAssertEqual(read(group, "ROMs/a/Game.sfc"), "rom")
        XCTAssertEqual(store.load()?.phase, .switched)
    }

    func testMissingSourceContainerKeepsTheJournal() async throws {
        // Review Focus 5.
        var journal = LibraryMoveJournal(request: .init(source: .appGroup, destination: .appStorage, sourceRoot: group, destinationRoot: local,
                                                        folders: LibraryMoveFolders.appGroupExit, keepCopy: false))
        journal.phase = .copying
        try store.save(journal)

        let outcome = await coordinator(launched: .appGroup, groupAvailable: false).resumeIfNeeded(progress: nil)

        XCTAssertNil(outcome)
        XCTAssertNotNil(store.load())
        XCTAssertTrue(recorder.switches.isEmpty)
    }

    func testDefaultRootsAreTheGroupAndLocalDocuments() {
        #if os(tvOS)
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .appGroup))
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .appStorage))
        #else
        XCTAssertEqual(LibraryMoveCoordinator.defaultRoot(for: .appStorage), URL.documentsPathLocal)
        XCTAssertEqual(LibraryMoveCoordinator.defaultRoot(for: .appGroup), URL.documentsPathAppGroup)
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .iCloudDrive), "phase 5")
        #endif
    }
}
```

- [ ] **Step 2: Run to verify failure** — `<Class>` = `LibraryMoveCoordinatorTests`. Expected: `cannot find 'LibraryMoveCoordinator' in scope`.

- [ ] **Step 3: Create `LibraryMoveCoordinator.swift`**

```swift
//
//  LibraryMoveCoordinator.swift
//  PVFileSystem
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  The app-facing side of the move engine: knows the real roots, resumes a journaled move at
//  launch (`PVGameLibrary.init` calls `resumeIfNeeded()`), and starts the one move phase 2
//  supports, App Group → App storage. tvOS: no-op.
//

import Foundation
import PVHashing
import PVLogging

public final class LibraryMoveCoordinator: @unchecked Sendable {
    public static let shared = LibraryMoveCoordinator()

    private let journalStore: LibraryMoveJournalStore?
    private let rootProvider: @Sendable (LibraryLocation) -> URL?
    /// The location this process launched on (`LibraryLocation.current`); decides whether cleanup may run.
    private let launchedLocation: @Sendable () -> LibraryLocation
    private let engine: LibraryMoveEngine?

    public init(journalStore: LibraryMoveJournalStore? = try? LibraryMoveJournalStore(url: LibraryMoveJournalStore.defaultURL()),
                rootProvider: @escaping @Sendable (LibraryLocation) -> URL? = LibraryMoveCoordinator.defaultRoot(for:),
                launchedLocation: @escaping @Sendable () -> LibraryLocation = { LibraryLocation.current },
                switchLocation: @escaping @Sendable (LibraryLocation) throws -> Void = LibraryLocation.switchStored(to:),
                planner: LibraryMovePlanner = LibraryMovePlanner(),
                md5Provider: any MD5Provider = FileManager.default) {
        self.journalStore = journalStore
        self.rootProvider = rootProvider
        self.launchedLocation = launchedLocation
        self.engine = journalStore.map {
            LibraryMoveEngine(journalStore: $0, md5Provider: md5Provider, planner: planner, switchLocation: switchLocation)
        }
    }

    /// The `Documents/` folder of each location. iCloud Drive is phase 5. Always `nil` on tvOS.
    public static func defaultRoot(for location: LibraryLocation) -> URL? {
        #if os(tvOS)
        return nil
        #else
        switch location {
        case .appStorage: return URL.documentsPathLocal
        case .appGroup: return URL.documentsPathAppGroup
        case .iCloudDrive: return nil
        }
        #endif
    }

    /// A journal exists: either a copy to finish or a cleanup owed on the next launch.
    public var hasPendingMove: Bool {
        journalStore?.load() != nil
    }

    /// Call once per launch, off the main thread. Finishes an interrupted copy (then switches), or runs
    /// the cleanup owed after a switch once this process has launched on the destination.
    /// - Returns: the outcome, or `nil` when there was nothing to do or it could not safely run.
    @discardableResult
    public func resumeIfNeeded(progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async -> LibraryMoveOutcome? {
        #if os(tvOS)
        return nil
        #else
        guard let engine, let journal = journalStore?.load() else { return nil }
        guard let sourceRoot = rootProvider(journal.source), let destinationRoot = rootProvider(journal.destination) else {
            ELOG("LibraryMove: a root for \(journal.source.rawValue) → \(journal.destination.rawValue) is unavailable; keeping the journal")
            return nil
        }
        let launched = launchedLocation()
        switch journal.phase {
        case .copying:
            guard launched == journal.source else {
                ELOG("LibraryMove: journal is mid-copy but this launch is on \(launched.rawValue); keeping the journal")
                return nil
            }
        case .switched, .cleaning:
            guard launched == journal.destination else {
                ILOG("LibraryMove: switch recorded but this launch is still on \(launched.rawValue); cleanup waits for a relaunch")
                return nil
            }
        }
        do {
            return try await engine.resume(journal, sourceRoot: sourceRoot, destinationRoot: destinationRoot, progress: progress)
        } catch {
            ELOG("LibraryMove: resume failed: \(error.localizedDescription)")
            return nil
        }
        #endif
    }

    /// Phase 2's one supported move. Verifies, writes the setting, and returns `.switched`;
    /// the caller tells the user to quit and reopen. Cleanup happens on that next launch.
    public func moveToAppStorage(keepCopy: Bool = false,
                                 progress: (@Sendable (LibraryMoveProgress) -> Void)? = nil) async throws -> LibraryMoveOutcome {
        let source = launchedLocation()
        guard source == .appGroup else { throw LibraryMoveError.unsupportedMove(from: source, to: .appStorage) }
        guard let engine else { throw LibraryMoveError.rootUnavailable(.appStorage) }
        guard let sourceRoot = rootProvider(.appGroup) else { throw LibraryMoveError.rootUnavailable(.appGroup) }
        guard let destinationRoot = rootProvider(.appStorage) else { throw LibraryMoveError.rootUnavailable(.appStorage) }
        let request = LibraryMoveRequest(source: .appGroup, destination: .appStorage, sourceRoot: sourceRoot, destinationRoot: destinationRoot,
                                         folders: LibraryMoveFolders.appGroupExit, keepCopy: keepCopy)
        return try await engine.start(request, progress: progress)
    }

    public func cancel() async {
        await engine?.cancel()
    }
}
```

- [ ] **Step 4: Run to verify pass** — `<Class>` = `LibraryMoveCoordinatorTests`. Expected: 8 passes.

- [ ] **Step 5: Lint and commit**

```bash
swiftlint lint --path PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift
git add PVLibrary/Sources/PVFileSystem/LibraryMove/LibraryMoveCoordinator.swift PVLibrary/Tests/PVLibraryTests/LibraryMoveCoordinatorTests.swift
git -c commit.gpgsign=false commit -m "feat(storage): LibraryMoveCoordinator resumes moves at launch" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Retire `oldPaths` and wire the coordinator into launch — `haiku`

**Files:**
- Modify: `PVLibrary/Sources/PVLibrary/Database/PVGameLibrary+Migration.swift:17-237, 412-419`
- Modify: `PVLibrary/Sources/PVLibrary/Database/PVGameLibrary.swift:34-50`

**Interfaces:**
- Consumes: `LibraryMoveCoordinator.shared.resumeIfNeeded()` (Task 7).
- Produces: `ROMLocationMigrator` keeps only `init(fileManager:)`, `fixOrphanedFiles()`, `fixPartialPaths()`.

- [ ] **Step 1: Delete the folder mover from `ROMLocationMigrator`.** In `PVGameLibrary+Migration.swift` remove, in full: the `oldPaths` property (lines 26-68), `printFolderContents()` and `printFolderContents(_:)` (70-82), `migrateIfNeeded()` (84-114), `migrateDirectory(from:to:)` (116-153), `processChunk(_:sourceDir:destDir:)` (155-197), `cleanupSourceDirectory(_:)` (199-237), and the `private extension Array { func chunked ... }` block (412-419). Replace the class doc comment (line 17) with:

```swift
/// Repairs ROM records whose files landed in the wrong place. Moving the library between storage
/// locations is `LibraryMoveCoordinator` (PVFileSystem); the ad-hoc App Group folder mover that
/// used to live here was retired with it.
```

Then remove `import AsyncAlgorithms` (line 13) if nothing else in the file uses it (grep the file for `AsyncStream`, `chunks`, `AsyncChannel`; none expected). Keep `import RxSwift`, `import RealmSwift`, `import PVFileSystem`, `import PVSupport`, `import PVLogging`: `fixOrphanedFiles`, `fixPartialPaths` and the `PVGameLibrary.migrate` extension below use them. Keep the `fileManager` property and `init(fileManager:)` unchanged even though only the removed code read `fileManager`: `PVGameLibrary.init(database:migrator: .init())` depends on the initializer, and the property is the natural injection point for a future test of `fixOrphanedFiles`.

- [ ] **Step 2: Wire the coordinator** in `PVGameLibrary.swift`. Replace the `Task { ... }` block in `init` (lines 39-49) with:

```swift
        // Finish or clean up a journaled library move, then repair misplaced ROM records.
        Task {
            await LibraryMoveCoordinator.shared.resumeIfNeeded()
            if PVFeatureFlags.shared.isEnabled(.romPathMigrator) {
                do {
                    try await self.romMigrator.fixOrphanedFiles()
                    ILOG("ROM record repair completed successfully")
                } catch {
                    ELOG("ROM record repair failed: \(error.localizedDescription)")
                }
            }
        }
```

Add `import PVFileSystem` to the import list at the top of `PVGameLibrary.swift` (PVLibrary already depends on it).

- [ ] **Step 3: Verify nothing else referenced the removed API**

```bash
cd /Users/jmattiello/Workspace/Provenance/Provenance && grep -rn "romMigrator.migrateIfNeeded\|\.oldPaths\|printFolderContents" --include='*.swift' PVLibrary PVUI Provenance ProvenanceTV Extensions | grep -v "/\.build/"
```

Expected: no output. (`SystemDirectoryMigration.migrateIfNeeded` is a different class and stays.)

- [ ] **Step 4: Build-check via the test bundle** — run the test command with `<Class>` = `LibraryLocationTests` (any class works; the point is that PVLibrary and PVLibraryTests compile). Expected: build succeeds, tests pass.

- [ ] **Step 5: Lint and commit**

```bash
swiftlint lint --path "PVLibrary/Sources/PVLibrary/Database/PVGameLibrary+Migration.swift"
swiftlint lint --path PVLibrary/Sources/PVLibrary/Database/PVGameLibrary.swift
git add "PVLibrary/Sources/PVLibrary/Database/PVGameLibrary+Migration.swift" PVLibrary/Sources/PVLibrary/Database/PVGameLibrary.swift
git -c commit.gpgsign=false commit -m "refactor(storage): retire oldPaths folder mover for LibraryMoveCoordinator" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Debug UI hook — location row, move button, relaunch alert — `sonnet`

**Files:**
- Modify: `PVUI/Sources/PVSwiftUI/Settings/Views/FeatureFlagsDebugView.swift:525-545` (reset block) and `:632-650` (`UserDefaultsSection`)

**Interfaces:**
- Consumes: `LibraryLocation.current`, `LibraryMoveCoordinator.shared.moveToAppStorage(keepCopy:progress:)`, `LibraryMoveProgress`, `LibraryMoveOutcome`, `Defaults.Keys.libraryLocation`.

- [ ] **Step 1: Reset the new key with the others.** In the "RESET TO DEFAULT" action (line ~537) add, after `Defaults.Keys.useAppGroups.reset()`:

```swift
                        Defaults.Keys.libraryLocation.reset()
```

- [ ] **Step 2: Replace the `useAppGroups` toggle row.** In `UserDefaultsSection`, delete `@Default(.useAppGroups) var useAppGroups` and the `UserDefaultRow(title: "useAppGroups", ...)` line, and insert `LibraryLocationRow()` as the first row inside the `VStack(spacing: 4)`. Add `import PVFileSystem` to the file's imports if it is not already there. Add this view at the bottom of the file:

```swift
// MARK: - Library location (phase 2 hook; Settings › Library › Storage arrives later)

/// Shows where the library lives and, for legacy App Group users, offers the one move phase 2
/// supports. The location is fixed per launch, so a finished move asks the user to quit and reopen.
private struct LibraryLocationRow: View {
    @State private var location = LibraryLocation.current
    @State private var progress: LibraryMoveProgress?
    @State private var message: String?
    @State private var showsRelaunchAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("libraryLocation")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text(location.rawValue)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }
            #if !os(tvOS)
            if location == .appGroup {
                Button(action: startMove) {
                    Text(progress.map { "MOVING… \(Int($0.fraction * 100))%" } ?? "MOVE TO APP STORAGE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RetroTheme.retroPink.opacity(progress == nil ? 1 : 0.4))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .disabled(progress != nil)
                .buttonStyle(.plain)
            }
            #endif
            if let message {
                Text(message)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .alert("Library moved", isPresented: $showsRelaunchAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Quit and reopen Provenance to finish. The old files are removed on the next launch.")
        }
    }

    private func startMove() {
        progress = .init(phase: .copying, filesDone: 0, filesTotal: 0, bytesDone: 0, bytesTotal: 0, currentPath: nil)
        message = nil
        Task {
            do {
                let outcome = try await LibraryMoveCoordinator.shared.moveToAppStorage { report in
                    Task { @MainActor in progress = report }
                }
                await MainActor.run {
                    progress = nil
                    showsRelaunchAlert = (outcome == .switched)
                    message = outcome == .switched ? "Switched. Relaunch required." : "\(outcome)"
                }
            } catch {
                await MainActor.run {
                    progress = nil
                    message = error.localizedDescription
                }
            }
        }
    }
}
```

`RetroTheme.retroPink` is already used in this file (line ~530). If the file's existing rows use a different container style, match that style instead of the `padding(8)/background` above; the behaviour is what matters.

- [ ] **Step 3: Build iOS and tvOS.** PVUI needs the workspace. Use the focused dev app (fast) for iOS and the generic tvOS simulator build for tvOS:

```bash
cd /Users/jmattiello/Workspace/Provenance/Provenance && make dev-ui 2>&1 | tee "$SCRATCH/dev-ui.log" | grep -E "error:|BUILD" | tail -20
```

If `make dev-ui` is unavailable in this checkout (no `mise`/Tuist), fall back to:

```bash
xcodebuild build -workspace Provenance.xcworkspace -scheme "Provenance-Lite (AppStore)" -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation 2>&1 | tee "$SCRATCH/lite-ios.log" | grep -E "error:|BUILD" | tail -20
```

Then tvOS:

```bash
xcodebuild build -workspace Provenance.xcworkspace -scheme "Provenance-Lite (AppStore)" -destination "generic/platform=tvOS Simulator" CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation 2>&1 | tee "$SCRATCH/lite-tvos.log" | grep -E "error:|BUILD" | tail -20
```

Expected: `BUILD SUCCEEDED` for both. These take 20–60 minutes each on a cold derived data; run them sequentially, never in parallel.

- [ ] **Step 4: Lint and commit**

```bash
swiftlint lint --path PVUI/Sources/PVSwiftUI/Settings/Views/FeatureFlagsDebugView.swift
git add PVUI/Sources/PVSwiftUI/Settings/Views/FeatureFlagsDebugView.swift
git -c commit.gpgsign=false commit -m "feat(settings): debug row to move the library out of the App Group" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: Docs, full test run, lint sweep — `haiku`

**Files:**
- Modify: `docs/superpowers/specs/2026-10-11-library-storage-locations-design.md` (Data model bullets; "Suggested phasing" item 2)
- Modify: `CLAUDE.md` (a new bullet under "### Code conventions" or a new "### Library storage gotchas" heading next to "Metal rendering gotchas")

- [ ] **Step 1: Update the spec.** In "Data model", replace the bullet that begins `**Phase 1 doesn't store the location.**` and its sub-list with:

```markdown
- **The location is stored since phase 2** as `Defaults[.libraryLocation]` (`LibraryLocation.rawValue`, `nil` until the first move). Precedence, in `LibraryLocation.resolve`: iCloud Drive (sync on + Drive mode, still derived from the iCloud settings until phase 5) → the stored value → the legacy `useAppGroups` toggle. The move engine's switch writes both the stored value and `useAppGroups`, so a build that only knows `useAppGroups` agrees after a downgrade.
  - The appGroup/appStorage axis is read once per process (`storedAtLaunch`) and `URL.documentsPath` / `URL.cachesPath` follow the same value (`LibraryLocation.usesAppGroupContainer`), so the app-files root and the library root cannot disagree mid-session. A switch takes effect at the next launch; the UI tells the user to quit and reopen.
  - On tvOS the location is always `.appStorage` and the move engine is a no-op.
```

In "Suggested phasing" change item 2 to end with `**Done** (`docs/superpowers/plans/2026-10-11-storage-move-engine.md`).` and in "Moving between locations" append after step 5:

```markdown
6. **Cleanup timing (phase 2 decision).** Because the location is fixed per process, cleanup runs on the launch after the switch, once the app is on the new root: a delta sweep first copies anything the old process wrote after its files were journaled (a changed file whose verified copy exists goes to `Conflicts/`), then the journaled sources are deleted, emptied folders removed and the journal dropped. The journal lives at `<Application Support>/LibraryMove/move-journal.json` in the app's own container.
```

- [ ] **Step 2: Add the CLAUDE.md gotcha.** Under `### Code conventions`, before `- **Notification names — no magic strings.**`, insert:

```markdown
- **Library storage: `LibraryLocation` owns the roots; never move library folders by hand.** `URL.documentsPath`/`cachesPath` and `LibraryLocation.current` share one launch-fixed precedence (stored `libraryLocation` → legacy `useAppGroups`). Moves go through `LibraryMoveCoordinator` (PVFileSystem `LibraryMove/`): journaled in the app's Application Support, verified (size; MD5 under `ROMs/`+`BIOS/`), switched by writing the setting, and cleaned up on the *next* launch. Flipping `useAppGroups` alone no longer moves files. The Realm file is never part of a move.
```

- [ ] **Step 3: Full PVLibrary test run.** Run the test command without `-only-testing`. Expected: `** TEST SUCCEEDED **`. Pre-existing failures unrelated to this plan (check the class name) are reported in the final summary, not fixed here.

- [ ] **Step 4: Lint sweep of every file this plan touched**

```bash
cd /Users/jmattiello/Workspace/Provenance/Provenance && for f in \
  PVLibrary/Sources/PVFileSystem/LibraryLocation.swift PVLibrary/Sources/PVFileSystem/Paths.swift \
  PVLibrary/Sources/PVFileSystem/LibraryMove/*.swift \
  "PVLibrary/Sources/PVLibrary/Database/PVGameLibrary+Migration.swift" PVLibrary/Sources/PVLibrary/Database/PVGameLibrary.swift \
  PVUI/Sources/PVSwiftUI/Settings/Views/FeatureFlagsDebugView.swift \
  PVLibrary/Tests/PVLibraryTests/LibraryLocationTests.swift PVLibrary/Tests/PVLibraryTests/LibraryMove*Tests.swift; do swiftlint lint --quiet --path "$f"; done
```

Expected: no errors (warnings about pre-existing code in `FeatureFlagsDebugView.swift` are fine).

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-10-11-library-storage-locations-design.md CLAUDE.md
git -c commit.gpgsign=false commit -m "docs(storage): record phase 2 stored-location and cleanup decisions" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Risks / open questions

1. **Pre-relaunch window.** After the switch, the process keeps running on the App Group root; saves written then are caught by the cleanup delta sweep, but a changed file lands in `Conflicts/` rather than replacing the verified copy. That is the conservative choice; a later phase can prefer the newer file for save folders once there is UI to show the user what happened.
2. **`DirectoryWatcher` on `Imports/`.** `Imports` is in the folder set. The debug button is reachable while the importer runs; the planner copies whatever is there, and the inbox files disappear from the group only at cleanup (next launch), so a mid-import file is at worst imported from the old inbox and then also copied. Phase 3's real UI should disable the move while `GameImporter.shared.processingState == .processing`.
3. **Device-only behaviour of the App Group container.** Unit tests use temp roots. The first on-device test is: enable `useAppGroups` in the debug view on a build before this plan, add a ROM, update to a build with this plan, tap "MOVE TO APP STORAGE", relaunch twice, confirm the game launches and `<group>/Documents/ROMs` is gone. Add it to `docs/RELEASE_SMOKE_TESTS.md` when that doc is next touched.
4. **Caches in the App Group.** `URL.cachesPath` also follows the axis; the artwork cache under the group's `Caches/` is simply rebuilt after the switch. Nothing is moved; nothing is deleted.
5. **`LegacyFileMover.moveLegacyPaths()`** has no caller today (dead since some earlier refactor). It is out of scope here; it compares `documentsPath` with the library root and would be the place phase 5 re-examines.
6. **Journal flush granularity.** Every 25 files; a crash loses at most 24 journal entries, which resume re-verifies (not re-copies) because `transfer` records a verified existing destination as `identical`. For a torn file of the right size but wrong content in an MD5 folder, resume detects it via MD5 and files it under `Conflicts/` — a stray `Conflicts/` entry after a crash is possible but harmless. Acceptable for phase 2.
7. **Open: should phase 3's settings UI seed `libraryLocation` for everyone at launch?** Phase 2 deliberately does not (only the engine writes it), so the legacy toggle still means something for users who never moved. Decide when the Storage settings screen is designed.

## What phase 2 does NOT do

- No user-picked folder, bookmarks, folder picker or `.provenance-library.json` manifest (phase 3/4).
- No iCloud Drive as a move source or destination; `LibraryMoveEngine.supportedMoves` has one entry (phase 5).
- No Settings › Library › Storage UI; the only hook is the debug row (D9).
- No change to `FileLocationResolver`, `PVFile.realPath`, `RelativeRoot.createRelativePath` or the other root-computing sites the spec lists as phase 3 work.
- No record rewrites, no Realm schema change, no move of the Realm file.
- No automatic migration of existing App Group users: they stay until they press the button.
- tvOS: nothing changes.
