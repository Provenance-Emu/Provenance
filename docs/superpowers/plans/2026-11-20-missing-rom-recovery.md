# Missing ROM Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a game's ROM file is missing at launch and iCloud cannot supply it, find it on a paired nearby app or saved server, ask once, copy it back to the game's own path, and boot.

**Architecture:** Pure matching, file-restore and hint-store types live in `PVLibrarySharing` and are tested with `swift test`. `PVUIBase` gets a small protocol seam the emulator view controller calls where it would dismiss today. `PVSwiftUI` implements the seam with a service that builds sources without UI, runs the matcher, pulls with `LibraryPuller` and restores. The game row is never re-keyed or duplicated.

**Tech Stack:** Swift 6 concurrency (actors, `async`), Swift Testing in `PVLibrarySharingTests`, `NWBrowser` via the existing `PeerBrowser`, Realm (read only, plus `GameFileStatusService`), `Defaults`.

**Spec:** `docs/superpowers/specs/2026-11-19-missing-rom-recovery-design.md`

## Global Constraints

- iOS 17+ and tvOS 17+; every new file compiles for both. `PVLibrarySharing` also declares macOS and visionOS: no UIKit in it.
- Never overwrite or delete an existing file. Recovery only fills a hole.
- Never re-key, delete or duplicate the `PVGame`. A different version is a stand-in at the old path under the old file name.
- Never add work to a launch whose file is present: no discovery, no source construction, no hint read.
- Only paired peers visible over Bonjour, saved content servers and a saved RomM login. No pairing or sign-in prompt from a launch.
- Name matching is never fuzzy.
- Always Allow covers exact matches only. A stand-in always asks.
- Discovery window 3 s. Per-source catalogue timeout 8 s.
- Use `SystemIdentifier`, not raw `com.provenance.*` strings.
- New PVLibrarySharing Swift files need no project edits (SwiftPM only). Run `python3 Scripts/audits/check_pbxproj_sources.py` after adding PVUI files.
- Shared checkout: commit only this plan's files, by path. Do not touch the uncommitted widget work.
- Tests: `cd PVLibrarySharing && xcrun swift test --filter <Suite>`. Do not run the full PVUI suite per task; one PVUI build per platform at the end (Task 8).

## Review Focus

1. **A file appears at the target path mid-copy** (iCloud finishes late, or the user imports it). Expected: the staged copy is discarded, the existing file wins, the game boots. Test in Task 3.
2. **The same remote file name with different letter case or a different extension** (`Mario Kart 64 (USA).z64` vs `.n64`). Expected: name match, treated as a stand-in, never exact. Test in Task 1.
3. **A source that hangs after accepting the connection.** Expected: dropped after 8 s, listed as unreachable, the other sources still asked. Test in Task 5.
4. **The game is launched again while a recovery for it is running** (double press on tvOS). Expected: one copy; the second call joins the first. Test in Task 5.
5. **A multi-file game with one file present and one missing.** Expected: only the missing file is restored; the present one is untouched. Test in Task 3.

---

### Task 1: Matcher

**Files:**
- Create: `PVLibrarySharing/Sources/PVLibrarySharing/Recovery/MissingGameQuery.swift`
- Create: `PVLibrarySharing/Sources/PVLibrarySharing/Recovery/MissingGameMatcher.swift`
- Test: `PVLibrarySharing/Tests/PVLibrarySharingTests/MissingGameMatcherTests.swift`

**Interfaces:**
- Produces:

```swift
public struct MissingGameFile: Sendable, Equatable, Codable {
    public var name: String      // last path component as recorded by the PVFile
    public var size: Int64       // 0 when unknown
    public var isPrimary: Bool
}
public struct MissingGameQuery: Sendable, Equatable {
    public var md5: String                 // PVGame.md5Hash
    public var system: SystemIdentifier
    public var title: String
    public var files: [MissingGameFile]    // every file of the game, primary first
    public var isSingleFileImage: Bool     // one file, extension not in LocalLibraryEntry.multiFileIndexExtensions
}
public enum RecoveryMatchKind: Sendable, Equatable { case exact, standIn }

public enum MissingGameMatcher {
    /// Tier 1. Items on the query's system whose md5 equals the query's (case-insensitive)
    /// and whose size agrees when both are non-zero. Empty unless `isSingleFileImage`.
    public static func hashMatches(for query: MissingGameQuery, in catalogue: RemoteCatalogue) -> [RemoteLibraryItem]
    /// Tiers 3 and 4, first step. Items on the query's system whose normalised title equals the
    /// normalised game title or primary file name. Best first: equal size, then equal title.
    public static func nameCandidates(for query: MissingGameQuery, in catalogue: RemoteCatalogue) -> [RemoteLibraryItem]
    /// Tiers 3 and 4, second step. nil when the manifest cannot fill the hole at all.
    public static func classify(_ manifest: RemoteManifest, for query: MissingGameQuery) -> RecoveryMatchKind?
    static func normalised(_ name: String) -> String
}
```

- `normalised`: strip the path extension, lowercase, fold diacritics, drop every character that is not a letter or digit. `"Mario Kart 64 (USA).z64"` → `"mariokart64usa"`. Parenthesised tags are kept: region and revision must agree.
- `classify`: `.exact` when every query file has a manifest game file with the same name (case-insensitive) and the same non-zero size. `.standIn` when the query has one file and the manifest has one game file; or when every query file has a same-named manifest file but a size differs or is unknown. Otherwise `nil`.

- [ ] **Step 1: Write the failing tests** (Swift Testing, `@Suite struct MissingGameMatcherTests`). Build catalogues with `RemoteCatalogue`/`RemoteLibraryItem` initialisers as `ECSSourceTests` does.

```swift
@Test func hashMatchIsCaseInsensitive()        // query md5 "ABCD…", item md5 "abcd…" → 1 item
@Test func hashMatchRejectsDifferentSize()     // same md5, sizes 100 vs 200 → []
@Test func hashMatchAcceptsUnknownRemoteSize() // item sizeBytes 0 (ECS) → 1 item
@Test func hashMatchSkipsMultiFileGames()      // isSingleFileImage false → [] even with equal md5
@Test func hashMatchNeverCrossesSystems()      // same md5, item system .SNES, query .N64 → []
@Test func nameCandidatesNormalise()           // title "Mario Kart 64 (USA)" matches file "mario kart 64 (usa).z64"
@Test func nameCandidatesAreNeverFuzzy()       // "Mario Kart 64 (Europe)" and "Mario Kart 64" → []
@Test func nameCandidatesPreferEqualSize()     // two same-name items; the one with equal size is first
@Test func classifyExactForCueBinSet()         // cue+2 bins, all names and sizes equal → .exact
@Test func classifyStandInWhenSizeDiffers()    // same names, one size differs → .standIn
@Test func classifyStandInForDifferentExtension() // query "Game.z64", manifest "Game.n64", one file each → .standIn
@Test func classifyNilForDifferentFileNamesInSet() // cue set, a bin name differs → nil
```

- [ ] **Step 2: Run to verify they fail.** `cd PVLibrarySharing && xcrun swift test --filter MissingGameMatcherTests`. Expected: compile failure, types not defined.
- [ ] **Step 3: Implement the two source files** to the signatures above.
- [ ] **Step 4: Run to verify they pass.** Same command. Expected: 12 tests pass.
- [ ] **Step 5: Commit.** `git add PVLibrarySharing/Sources/PVLibrarySharing/Recovery PVLibrarySharing/Tests/PVLibrarySharingTests/MissingGameMatcherTests.swift && git commit -m "feat(sharing): match a missing game against a remote catalogue"`

---

### Task 2: Source hints

**Files:**
- Create: `PVLibrarySharing/Sources/PVLibrarySharing/Recovery/GameSourceHints.swift`
- Test: `PVLibrarySharing/Tests/PVLibrarySharingTests/GameSourceHintsTests.swift`

**Interfaces:**
- Produces:

```swift
public struct GameSourceHint: Sendable, Equatable, Codable {
    public var app: PeerApp
    public var sourceIdentity: String      // peer id, or the content server's URL string
    public var remoteItemID: String
    public var files: [MissingGameFile]
    public var standInMD5: String?         // set when the file on disk is a different version
}
public actor GameSourceHints {
    public init(fileURL: URL)              // "game-source-hints.json"; the caller picks the folder
    public func hint(forMD5 md5: String) -> GameSourceHint?
    public func record(_ hint: GameSourceHint, forMD5 md5: String)
    public func remove(md5: String)
}
```

- Keys are upper-cased MD5s. Writes are atomic (`Data.write(options: .atomic)`). A missing or unreadable file is an empty store, never an error. The file is read on first use, not in `init`.

- [ ] **Step 1: Write the failing tests.**

```swift
@Test func roundTripsThroughDisk()          // record, new actor on the same URL, hint equal
@Test func keysAreCaseInsensitive()         // record "abc", hint(forMD5: "ABC") non-nil
@Test func corruptFileReadsAsEmpty()        // write "not json" to the URL → hint nil, record still works
@Test func missingFolderIsCreatedOnRecord() // fileURL in a folder that does not exist
```

- [ ] **Step 2: Run to verify they fail.** `xcrun swift test --filter GameSourceHintsTests`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify they pass.**
- [ ] **Step 5: Commit.** `git commit -m "feat(sharing): remember which source a game came from"` (the two files by path).

---

### Task 3: Restorer

**Files:**
- Create: `PVLibrarySharing/Sources/PVLibrarySharing/Recovery/MissingGameRestorer.swift`
- Test: `PVLibrarySharing/Tests/PVLibrarySharingTests/MissingGameRestorerTests.swift`

**Interfaces:**
- Consumes: `PulledGame` (`gameFiles: [URL]`, `folder`), `LibraryStaging.markHandedOff(_:)`, `RecoveryMatchKind`, `MissingGameFile`.
- Produces:

```swift
public struct RestoreTarget: Sendable, Equatable {
    public var file: MissingGameFile
    public var url: URL                    // where the game expects this file
}
public struct RestoreResult: Sendable, Equatable {
    public var restored: [URL]
    public var alreadyPresent: [URL]
}
public enum MissingGameRestorer {
    /// Moves each staged file to its target when nothing is there. Exact: staged and target are
    /// paired by file name (case-insensitive). Stand-in with one target: the single staged game
    /// file goes to the target path whatever its own name. Throws `LibrarySharingError` (add case
    /// `.recoveryFileSetMismatch`) before moving anything when a missing target has no staged file.
    public static func restore(_ pulled: PulledGame, to targets: [RestoreTarget], kind: RecoveryMatchKind,
                               staging: LibraryStaging, fileManager: FileManager = .default) throws -> RestoreResult
}
```

- A move is a copy to a hidden temp file beside the target, then `moveItem` to the target; `moveItem` fails when the target exists, which is the no-overwrite guarantee. On that failure the temp file is removed and the URL is reported in `alreadyPresent`. Parent folders are created. `markHandedOff(pulled.folder)` runs once at the end.

- [ ] **Step 1: Write the failing tests** using a temp directory for both staging and library.

```swift
@Test func restoresMissingFile()                 // target absent → file at target, bytes equal, restored == [target]
@Test func neverOverwritesExistingFile()         // target holds "old" → still "old", alreadyPresent == [target]
@Test func fileAppearingMidRestoreWins()         // create the target after the temp copy via a FileManager subclass hook → target keeps the late file, no temp file left
@Test func restoresOnlyTheMissingFileOfASet()    // cue present, bin missing → cue bytes unchanged, bin restored
@Test func standInTakesTheOldFileName()          // staged "Game.n64", target ".../Game.z64" → file exists at the .z64 path
@Test func mismatchedSetThrowsBeforeMoving()     // exact kind, a missing target has no staged file → throws, nothing created
@Test func leavesNoTempFilesBehind()             // after success and after each failure above
```

- [ ] **Step 2: Run to verify they fail.** `xcrun swift test --filter MissingGameRestorerTests`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify they pass.**
- [ ] **Step 5: Commit.** `git commit -m "feat(sharing): restore a pulled game into its missing files"`

---

### Task 4: Shared source construction and headless discovery

**Files:**
- Create: `PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/LibrarySourceFactory.swift`
- Create: `PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/RecoverySourceDirectory.swift`
- Modify: `PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/NearbyLibrariesModel.swift` (`contentServerSource(for:)` at ~139 and the `switch peer.app` at ~395-406 call the factory; no behaviour change)

**Interfaces:**
- Produces:

```swift
enum LibrarySourceFactory {
    /// The construction that was inline in NearbyPeerModel.init.
    @MainActor static func source(for peer: DiscoveredPeer, identity: PeerIdentity, systems: Set<SystemIdentifier>,
                                  contentServers: [ContentServer]) -> any LibrarySource
    @MainActor static func contentServerSource(for server: ContentServer, identity: PeerIdentity,
                                               systems: Set<SystemIdentifier>) -> ECSSource
}

struct RecoverySource: Sendable {
    let source: any LibrarySource
    let name: String              // shown in prompts and the final alert
    let identity: String          // peer id or server URL string; GameSourceHint.sourceIdentity
    let peerKey: String           // LibraryPuller peerKey
    let rank: Int                 // 0 same device, 1 LAN peer, 2 content server
}
struct RecoverySourceList: Sendable {
    var sources: [RecoverySource]         // sorted by rank
    var needsSignIn: [String]             // names of saved sources that cannot be used without a prompt
    var localNetworkDenied: Bool
}
@MainActor final class RecoverySourceDirectory {
    static let discoveryWindow: Duration = .seconds(3)
    func sources(for system: SystemIdentifier) async -> RecoverySourceList
}
```

- `sources(for:)` starts a `PeerBrowser`, collects `snapshots()` for `discoveryWindow`, stops it, keeps peers for which `LibrarySharingService.shared.trust.peer(withId:)` is non-nil, and adds every saved content server (`NearbyLibrariesModel.contentServersKey`). "Same device" is a peer whose `baseURLs` contain a loopback host. `systems` is `[system]`. An untrusted visible peer is not reported at all; a content server without a Keychain token goes in `needsSignIn`.
- The directory holds its own `PeerBrowser`; it never touches the one in `NearbyLibrariesModel`.

- [ ] **Step 1: Extract the factory** and point both call sites in `NearbyLibrariesModel.swift` at it.
- [ ] **Step 2: Implement `RecoverySourceDirectory`.**
- [ ] **Step 3: Build check.** `swiftlint lint --path PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries`. Expected: no new violations. (Compile is checked in Task 8.)
- [ ] **Step 4: Commit.** `git commit -m "refactor(sharing): build library sources without the browse UI"` (the three files by path).

---

### Task 5: Recovery engine

**Files:**
- Create: `PVLibrarySharing/Sources/PVLibrarySharing/Recovery/MissingGameSearch.swift`
- Test: `PVLibrarySharing/Tests/PVLibrarySharingTests/MissingGameSearchTests.swift`

The ordering, timeout and stop-at-first-exact logic lives here so it is testable with fake sources and no UI.

**Interfaces:**
- Consumes: Task 1 matcher, Task 2 `GameSourceHint`, `LibrarySource`.
- Produces:

```swift
public struct SearchSource: Sendable {
    public var source: any LibrarySource
    public var name: String
    public var identity: String
    public var rank: Int
}
public struct FoundGame: Sendable {
    public var source: SearchSource
    public var item: RemoteLibraryItem
    public var manifest: RemoteManifest?   // nil for a tier 1 hash match; the puller fetches it
    public var kind: RecoveryMatchKind
}
public struct SearchReport: Sendable, Equatable {
    public var asked: [String]             // source names that answered
    public var unreachable: [String]       // timed out or threw
}
public actor MissingGameSearch {
    public static let catalogueTimeout: Duration = .seconds(8)
    public init(catalogueTimeout: Duration = MissingGameSearch.catalogueTimeout)
    /// Sources are asked in the order given, except that a source whose identity equals the hint's
    /// goes first. Returns the first exact match; otherwise the best stand-in seen; otherwise nil.
    public func find(_ query: MissingGameQuery, hint: GameSourceHint?, in sources: [SearchSource],
                     progress: @escaping @Sendable (String) -> Void) async -> (found: FoundGame?, report: SearchReport)
}
```

- Per source: `catalogue` under the timeout (race against `Task.sleep`, cancel the loser). Then tier 1 `hashMatches`; then, with a hint for this source, the item whose `id` equals `hint.remoteItemID` (exact); then `nameCandidates.first` → `pullManifest` → `classify`. One manifest per source at most.
- Catalogues are cached in the actor by `identity` for its lifetime.
- `progress` receives the source name before each source is asked.

- [ ] **Step 1: Write the failing tests** with a `FakeSource` actor conforming to `LibrarySource` (configurable catalogue, manifest, delay, thrown error, call counters).

```swift
@Test func stopsAtFirstExactMatch()              // A exact, B exact → found from A, B.catalogue never called
@Test func hintedSourceIsAskedFirst()            // order [A, B], hint identity B → B.catalogue called first
@Test func hintItemIsExactWithoutNameMatch()     // hint.remoteItemID present in catalogue, md5 nil, title differs → exact
@Test func fallsBackToStandInWhenNoExact()       // A stand-in, B nothing → found kind .standIn from A
@Test func exactLaterBeatsStandInEarlier()       // A stand-in, B exact → found from B
@Test func hangingSourceIsDroppedAfterTimeout()  // A sleeps 5 s, timeout 0.2 s, B exact → found from B, unreachable == ["A"]
@Test func throwingSourceIsUnreachable()         // A throws → report.unreachable == ["A"], asked == ["B"]
@Test func oneManifestPerSource()                // three name candidates → pullManifest called once
@Test func cataloguesAreCachedAcrossCalls()      // find twice → A.catalogue called once
@Test func nothingFoundReportsEverySource()      // found nil, asked == ["A","B"]
```

- [ ] **Step 2: Run to verify they fail.** `xcrun swift test --filter MissingGameSearchTests`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify they pass.**
- [ ] **Step 5: Commit.** `git commit -m "feat(sharing): search known sources for a missing game"`

---

### Task 6: Seam in PVUIBase and the launch hook

**Files:**
- Create: `PVUI/Sources/PVUIBase/PVEmulatorVC/MissingROMRecovery.swift`
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController.swift` (launch guard at ~1038-1047; after the on-demand block at ~1015)
- Modify: `PVSettings` — add `Defaults.Keys.missingROMRecoveryAlwaysAllow` (`Bool`, default `false`) beside the other library keys
- Test: `PVUI/Tests/PVUIBaseTests/MissingROMRecoveryRegistryTests.swift`

**Interfaces:**
- Produces:

```swift
public enum MissingROMRecoveryOutcome: Sendable, Equatable {
    case restored                                   // the file is in place; retry the launch
    case declined                                   // the user said no or cancelled
    case notFound(asked: [String], unreachable: [String], needsSignIn: [String])
    case failed(message: String)
}
public enum MissingROMRecoveryPrompt: Sendable, Equatable {
    case copy(title: String, source: String)                          // Copy / Always Allow / Cancel
    case standIn(title: String, fileName: String, source: String)     // Use It / Cancel
}
public enum MissingROMRecoveryAnswer: Sendable { case allow, alwaysAllow, cancel }

@MainActor public protocol MissingROMRecovering: AnyObject {
    func recover(gameMD5: String,
                 status: @escaping @MainActor (String) -> Void,
                 ask: @escaping @MainActor (MissingROMRecoveryPrompt) async -> MissingROMRecoveryAnswer
    ) async -> MissingROMRecoveryOutcome
}
@MainActor public enum MissingROMRecovery {
    public static var recoverer: (any MissingROMRecovering)?
}
```

- In `createEmulator`: where the guard at ~1038 fails, and `MissingROMRecovery.recoverer` is set, call `recover` once (never when the on-demand download was cancelled by the user). `.restored` → re-resolve with `refreshedGameForROMResolution()` / `resolvedROMURLAfterDownload()` and continue; if the file is still absent, fall through. Any other outcome, or no recoverer → the alert, then today's dismiss and throw.
- `status` drives a `UIAlertController` with a Cancel action, titled "Looking for \(title) on your network"; its message is the status string. Cancel cancels the `Task` running `recover`. `ask` presents a second alert over it.
- Exact copy:
  - Copy prompt: title "\(title)'s file is missing", message "Copy it from \(source)?", actions "Copy", "Always Allow", "Cancel".
  - Stand-in prompt: title "A different version was found", message "\(source) has \(fileName), which may be a different version. Use it? Save states may not load.", actions "Use It", "Cancel".
  - Not found: title "\(title)'s file is missing", message "No nearby library or server has it." followed by lines "Asked: …", "Could not reach: …", "Needs sign-in: …" for each non-empty list.
- The pasteboard copy of the path (`#if !os(tvOS)`) stays.

- [ ] **Step 1: Write the failing test.**

```swift
@MainActor @Test func registryHoldsTheRecoverer()   // set a stub, read it back, set nil
```

- [ ] **Step 2: Add the seam file and the `Defaults` key.**
- [ ] **Step 3: Wire `createEmulator`** as described.
- [ ] **Step 4: Lint.** `swiftlint lint --path PVUI/Sources/PVUIBase/PVEmulatorVC/MissingROMRecovery.swift`.
- [ ] **Step 5: Commit.** `git commit -m "feat(emulator): ask a recoverer before failing a launch with no ROM"`

---

### Task 7: The recovery service

**Files:**
- Create: `PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/MissingROMRecoveryService.swift`
- Modify: the app bootstrap that already starts `LibrarySharingService` (find with `grep -rn "LibrarySharingService.shared" PVUI/Sources Provenance ProvenanceTV | grep -i -E "start|bootstrap"`); add `MissingROMRecovery.recoverer = MissingROMRecoveryService.shared`
- Modify: `PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/LibrarySharingSettingsView.swift` — a "Restore Missing Games Without Asking" toggle bound to `missingROMRecoveryAlwaysAllow`
- Modify: the game context menu (`GameContextMenu`, where `EcosystemHandoffSendAction` was added) — "Restore Missing File", shown only when the game's file is absent

**Interfaces:**
- Consumes: everything from Tasks 1-6; `LibraryPuller(staging:peerKey:)`, `NearbyLibrariesModel.incomingStaging`, `GameFileStatusService.shared.markDownloaded(md5:at:)`, `FileLocationResolver`.
- Produces: `@MainActor final class MissingROMRecoveryService: MissingROMRecovering` with `static let shared`, and `func restore(gameMD5:) async -> MissingROMRecoveryOutcome` for the context menu (presents the same prompts on the key window).

Flow of `recover(gameMD5:status:ask:)`:

1. If a recovery for this MD5 is running, await and return its outcome (a `[String: Task<MissingROMRecoveryOutcome, Never>]`).
2. Read the game on a Realm thread: title, `SystemIdentifier`, and for the primary file and each `relatedFiles` entry the name, size and resolved URL (`FileLocationResolver` from `partialPath`, as `needsCloudKitDownload` does at ~1665). Build `MissingGameQuery` and `[RestoreTarget]`. No game or no system → `.failed`.
3. `RecoverySourceDirectory.sources(for:)`; map to `SearchSource`. `MissingGameSearch` is one instance on the service, so catalogues persist for the session.
4. `find`. Nothing → `.notFound` with the report and `needsSignIn`.
5. Ask: `.exact` → skip when `Defaults[.missingROMRecoveryAlwaysAllow]`, else `.copy`; `.alwaysAllow` sets the key. `.standIn` → always `.standIn`. `.cancel` → `.declined`.
6. `LibraryPuller.pull(item, from: source, manifest:, progress:)`; forward bytes as "Copying from \(name): 42%".
7. `MissingGameRestorer.restore`. Then `GameFileStatusService.shared.markDownloaded(md5:at:)` with the primary URL, under the game's unchanged MD5.
8. Record the hint (`standInMD5` = the item's md5 for a stand-in). The hints file is `game-source-hints.json` in the folder that holds the Realm file.
9. Any thrown error → `.failed(message: error.localizedDescription)`; cancellation → `.declined`. Nothing in the library is touched on either.

- [ ] **Step 1: Implement the service.**
- [ ] **Step 2: Register it at bootstrap; add the toggle and the context menu item.**
- [ ] **Step 3: Fix the stale flag wording** in `docs/development/content-server.md` and the comment in `LibrarySharingService.swift` (~line 20), and add a CHANGELOG entry: "A game whose file is missing is found on your nearby libraries and servers and copied back when you start it."
- [ ] **Step 4: Lint the changed Swift files; run `python3 Scripts/audits/check_pbxproj_sources.py`.** Expected: no findings.
- [ ] **Step 5: Commit.** `git commit -m "feat(library): recover a missing ROM from nearby libraries at launch"`

---

### Task 8: Build both platforms and check in a simulator

- [ ] **Step 1: All package tests.** `cd PVLibrarySharing && xcrun swift test`. Expected: everything passes, including the suites that existed before.
- [ ] **Step 2: Build PVUI for iOS and tvOS** with the `PVUI-UnitTests` scheme recipe in `CLAUDE.md` (`build-for-testing`, iPhone 17 and an Apple TV simulator; the realm-core `-xcconfig` on Xcode 26.6). Expected: both succeed.
- [ ] **Step 3: Simulator check.** Two iOS simulators with `Provenance-Dev-UI`: one shares a library holding a harness ROM (`Scripts/dev/make_harness_rom.py`), the other imports the same ROM, pairs, then has the file deleted from its container. Launch the game. Expected: the Copy prompt, then the game boots; a second delete with Always Allow on boots with no prompt. Delete again with sharing off on the host: the not-found alert lists the host under "Could not reach".
- [ ] **Step 4: Record what was not checked** in `docs/release-3.4.0-todo.md`: Apple TV with a purged game and iCube on a Mac as host; iFly as host (metering); a content server.
- [ ] **Step 5: Commit and push.**

---

### Task 9 (may slip past the release): RomM

**Files:**
- Create: `PVUI/Sources/PVSwiftUI/Settings/Views/NearbyLibraries/RomMRecoverySource.swift`
- Modify: `MissingROMRecoveryService.swift` — ask RomM last, only when a login is saved and nothing else matched

RomM is not a `LibrarySource` and has no SHA-256 manifest. Read `RomMGameImport.swift` and `RomMClient` first: use the client's search or hash filter when it has one, else the platform's game list. Match with `MissingGameMatcher.normalised` on the ROM's file name; exact only when RomM reports an MD5 equal to the query's, otherwise a stand-in. Download with the client to staging, check the size, restore through `MissingGameRestorer` with a one-file `PulledGame`. No saved login → nothing; an expired one → "RomM" in `needsSignIn`.

- [ ] **Step 1: Implement and wire in.**
- [ ] **Step 2: Build both platforms as in Task 8 Step 2.**
- [ ] **Step 3: Commit.** `git commit -m "feat(library): recover a missing ROM from RomM"`
