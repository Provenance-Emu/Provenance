# Provenance Realm-Free Extensions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the snapshot-based Top Shelf in the App Store target, delete `TopShelfv2`, make both Quick Look extensions Realm-free via a file-based library index in the App Group, and embed the orphaned `QuickLookPreview` target.

**Architecture:** `PVLibrarySnapshot` (the existing dependency-free package under `PVAppIntents/`) gains a `LibraryIndex` writer/reader: two JSON files in the group container keyed by ROM filename and save-state filename. The host writes them from the existing Realm-backed `WidgetDataWriter` path, throttled. `PVQuickLookSupport` drops `PVLibrary`, `PVHashing` and `RealmSwift`, reading the index instead. The pbxproj is rewired so `Provenance (AppStore)` embeds `TopShelf`, `ThumbnailExtension` and `QuickLookPreview`, none of which link Realm.

**Tech Stack:** Swift 5/6 packages (`swift test` on macOS), Realm only on the host side, `project.pbxproj` hand edits with `C0C0CAFE`-prefixed UUIDs, XCTest.

**Spec:** `/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/docs/superpowers/specs/2026-09-23-extensions-topshelf-quicklook-design.md` (sections 2.2, 3.6, 4)

## Global Constraints

- Repo: `/Users/jmattiello/Workspace/Provenance/Provenance`, branch `develop`. Follow the repo `CLAUDE.md` (Pre-PR validation, no magic strings, `SystemIdentifier` enum, conventional commits, `[Agent]` prefix only for PR titles).
- App group id: `LibrarySnapshotAppGroup.identifier` (resolves to `group.org.provenance-emu.provenance`). Never hardcode the string in new code.
- Index files: `<group>/Library/Caches/LibraryIndex/games-by-filename.json` and `savestates-by-filename.json`, written atomically. Full-index throttle: at most once per 30 s unless forced.
- Extensions never link `PVLibrary`, `RealmSwift`, `PVHashing`. Verify with `otool -L` in Task 6.
- Quick Look extension bundle ids stay `$(PRODUCT_BUNDLE_IDENTIFIER).ThumbnailExtension` / `.QuickLookPreview`; Top Shelf stays `org.provenance-emu.provenance.topshelf`.
- Commits end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Use `git -c commit.gpgsign=false commit` if signing hangs.
- pbxproj edits: minimal diffs, new objects use `C0C0CAFE` + 16 hex digits.

---

### Task 1: `LibraryIndex` model, writer and reader in `PVLibrarySnapshot`

**Files:**
- Create: `PVAppIntents/Sources/PVLibrarySnapshot/LibraryIndex.swift`
- Test: `PVAppIntents/Tests/PVAppIntentsTests/LibraryIndexTests.swift`

**Interfaces:**
- Consumes: `LibrarySnapshotAppGroup.containerURL`, `.url(forRelativePath:)`.
- Produces: `LibraryIndexGame` (filename, title, systemName, systemIdentifier, developer, publishDate, genre, gameDescription, playCount, isFavorite, artworkKey), `LibraryIndexSaveState` (filename, imageRelativePath), `LibraryIndexPaths`, `LibraryIndexWriter(containerURL:).write(games:saveStates:)`, `LibraryIndexReader(containerURL:).game(forROMFilename:)`, `.saveStateImageURL(forFilename:)`.

- [ ] **Step 1: Failing tests**

```swift
// PVAppIntents/Tests/PVAppIntentsTests/LibraryIndexTests.swift
import XCTest
@testable import PVLibrarySnapshot

final class LibraryIndexTests: XCTestCase {
    private var container: URL!

    override func setUp() {
        super.setUp()
        container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: container)
        super.tearDown()
    }

    private let smw = LibraryIndexGame(filename: "Super Mario World.sfc", title: "Super Mario World",
                                       systemName: "Super Nintendo", systemIdentifier: "com.provenance.snes",
                                       developer: "Nintendo", publishDate: "1990", genre: "Platformer",
                                       gameDescription: "Yoshi debuts.", playCount: 3, isFavorite: true,
                                       artworkKey: "https://example.com/smw.jpg")

    func testWriteThenReadGame() throws {
        let writer = LibraryIndexWriter(containerURL: container)
        XCTAssertTrue(writer.write(games: [smw], saveStates: [LibraryIndexSaveState(filename: "smw.svs", imageRelativePath: "Documents/Save States/smw.jpg")]))
        let reader = LibraryIndexReader(containerURL: container)
        let g = reader.game(forROMFilename: "Super Mario World.sfc")
        XCTAssertEqual(g?.title, "Super Mario World")
        XCTAssertEqual(g?.playCount, 3)
        XCTAssertEqual(g?.artworkKey, "https://example.com/smw.jpg")
        XCTAssertNil(reader.game(forROMFilename: "nope.sfc"))
        XCTAssertEqual(reader.saveStateImageURL(forFilename: "smw.svs"), container.appendingPathComponent("Documents/Save States/smw.jpg"))
        XCTAssertNil(reader.saveStateImageURL(forFilename: "other.svs"))
    }

    func testFilesLandUnderLibraryCaches() {
        _ = LibraryIndexWriter(containerURL: container).write(games: [smw], saveStates: [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: container.appendingPathComponent(LibraryIndexPaths.games).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: container.appendingPathComponent(LibraryIndexPaths.saveStates).path))
    }

    func testMissingFilesReadAsEmpty() {
        let reader = LibraryIndexReader(containerURL: container)
        XCTAssertNil(reader.game(forROMFilename: "x.sfc"))
        XCTAssertNil(reader.saveStateImageURL(forFilename: "x.svs"))
    }

    func testCorruptFileReadsAsEmpty() throws {
        let url = container.appendingPathComponent(LibraryIndexPaths.games)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: url)
        XCTAssertNil(LibraryIndexReader(containerURL: container).game(forROMFilename: "x.sfc"))
    }

    func testNilContainerIsInert() {
        XCTAssertFalse(LibraryIndexWriter(containerURL: nil).write(games: [smw], saveStates: []))
        XCTAssertNil(LibraryIndexReader(containerURL: nil).game(forROMFilename: "Super Mario World.sfc"))
    }

    func testDuplicateFilenamesKeepFirst() {
        var second = smw
        second = LibraryIndexGame(filename: smw.filename, title: "Other", systemName: "X", systemIdentifier: nil,
                                  developer: nil, publishDate: nil, genre: nil, gameDescription: nil,
                                  playCount: 0, isFavorite: false, artworkKey: nil)
        _ = LibraryIndexWriter(containerURL: container).write(games: [smw, second], saveStates: [])
        XCTAssertEqual(LibraryIndexReader(containerURL: container).game(forROMFilename: smw.filename)?.title, "Super Mario World")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd PVAppIntents && swift test --filter LibraryIndexTests 2>&1 | tail -3`
Expected: `cannot find 'LibraryIndexGame' in scope`.

- [ ] **Step 3: Implement**

```swift
// PVAppIntents/Sources/PVLibrarySnapshot/LibraryIndex.swift
//
//  LibraryIndex.swift
//  PVLibrarySnapshot
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  File-based, Realm-free index of the whole library for the Quick Look
//  extensions. Two JSON files in the App Group container, keyed by bare ROM
//  filename and bare save-state filename. Written by the host app
//  (WidgetDataWriter+Realm), read by PVQuickLookSupport.
//

import Foundation

public struct LibraryIndexGame: Codable, Sendable, Equatable {
    public let filename: String
    public let title: String
    public let systemName: String?
    public let systemIdentifier: String?
    public let developer: String?
    public let publishDate: String?
    public let genre: String?
    public let gameDescription: String?
    public let playCount: Int
    public let isFavorite: Bool
    /// Raw `PVMediaCache` key (the artwork URL string). `ArtworkResolver` hashes it.
    public let artworkKey: String?

    public init(filename: String, title: String, systemName: String?, systemIdentifier: String?,
                developer: String?, publishDate: String?, genre: String?, gameDescription: String?,
                playCount: Int, isFavorite: Bool, artworkKey: String?) {
        self.filename = filename
        self.title = title
        self.systemName = systemName
        self.systemIdentifier = systemIdentifier
        self.developer = developer
        self.publishDate = publishDate
        self.genre = genre
        self.gameDescription = gameDescription
        self.playCount = playCount
        self.isFavorite = isFavorite
        self.artworkKey = artworkKey
    }
}

public struct LibraryIndexSaveState: Codable, Sendable, Equatable {
    public let filename: String
    /// Path of the screenshot relative to the App Group container.
    public let imageRelativePath: String

    public init(filename: String, imageRelativePath: String) {
        self.filename = filename
        self.imageRelativePath = imageRelativePath
    }
}

public enum LibraryIndexPaths {
    public static let directory = "Library/Caches/LibraryIndex"
    public static let games = directory + "/games-by-filename.json"
    public static let saveStates = directory + "/savestates-by-filename.json"
}

public struct LibraryIndexWriter {
    private let containerURL: URL?

    public init(containerURL: URL? = LibrarySnapshotAppGroup.containerURL) {
        self.containerURL = containerURL
    }

    /// Atomic (temp file + rename). Returns false when the group is unavailable.
    @discardableResult
    public func write(games: [LibraryIndexGame], saveStates: [LibraryIndexSaveState]) -> Bool {
        guard let containerURL else { return false }
        var gamesByName: [String: LibraryIndexGame] = [:]
        for g in games where gamesByName[g.filename] == nil { gamesByName[g.filename] = g }
        var savesByName: [String: String] = [:]
        for s in saveStates where savesByName[s.filename] == nil { savesByName[s.filename] = s.imageRelativePath }

        let dir = containerURL.appendingPathComponent(LibraryIndexPaths.directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            try encoder.encode(gamesByName).write(to: containerURL.appendingPathComponent(LibraryIndexPaths.games), options: .atomic)
            try encoder.encode(savesByName).write(to: containerURL.appendingPathComponent(LibraryIndexPaths.saveStates), options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

/// Decodes lazily and once per instance. Create one per extension request.
public final class LibraryIndexReader: @unchecked Sendable {
    private let containerURL: URL?
    private lazy var games: [String: LibraryIndexGame] = load(LibraryIndexPaths.games) ?? [:]
    private lazy var saves: [String: String] = load(LibraryIndexPaths.saveStates) ?? [:]

    public init(containerURL: URL? = LibrarySnapshotAppGroup.containerURL) {
        self.containerURL = containerURL
    }

    public func game(forROMFilename filename: String) -> LibraryIndexGame? {
        guard !filename.isEmpty else { return nil }
        return games[filename]
    }

    public func saveStateImageURL(forFilename filename: String) -> URL? {
        guard !filename.isEmpty, let containerURL, let rel = saves[filename] else { return nil }
        return containerURL.appendingPathComponent(rel)
    }

    private func load<T: Decodable>(_ relativePath: String) -> T? {
        guard let containerURL,
              let data = try? Data(contentsOf: containerURL.appendingPathComponent(relativePath)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
```

- [ ] **Step 4: Run all package tests**

Run: `cd PVAppIntents && swift test 2>&1 | tail -3`
Expected: 0 failures (existing `LibrarySnapshotTests`, `WidgetDataWriterTests` etc. still pass).

- [ ] **Step 5: Commit**

```bash
git add PVAppIntents/Sources/PVLibrarySnapshot/LibraryIndex.swift PVAppIntents/Tests/PVAppIntentsTests/LibraryIndexTests.swift
git -c commit.gpgsign=false commit -m "feat(snapshot): file-based library index for Realm-free Quick Look

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Host writes the index from Realm

**Files:**
- Modify: `PVUI/Sources/PVUIBase/Widgets/WidgetDataWriter+Realm.swift`
- Modify: `PVUI/Sources/PVUIBase/GameLibrary/PVGameLibraryUpdatesController.swift:131` (force after import). If the path differs, `grep -rn "writeFromRealm()" PVUI Provenance` and use the import-completion site.

**Interfaces:**
- Consumes: `LibraryIndexWriter`, `LibraryIndexGame`, `LibraryIndexSaveState`, existing `widgetArtworkPath(for:)` (make it `internal` instead of `private`), `PVGame` fields (`romPath`, `title`, `system?.name`, `systemShortName`, `systemIdentifier`, `developer`, `publishDate`, `genres`, `gameDescription`, `playCount`, `isFavorite`, `customArtworkURL`, `originalArtworkURL`), `PVSaveState.file?.partialPath`, `PVSaveState.image?.url`.
- Produces: `WidgetDataWriter.writeLibraryIndex(force:)` (`@MainActor`), called from `writeFromRealm()`.

- [ ] **Step 1: Add the index writer to the Realm extension**

Append to `WidgetDataWriter+Realm.swift` inside the `#if canImport(PVAppIntents)` block:

```swift
public extension WidgetDataWriter {
    private static let indexThrottle: TimeInterval = 30
    private static var lastIndexWrite: Date = .distantPast

    /// Writes the full library index the Quick Look extensions read. Throttled
    /// because it walks every game; `force` bypasses the throttle (import done).
    @MainActor
    func writeLibraryIndex(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(Self.lastIndexWrite) >= Self.indexThrottle else { return }
        Self.lastIndexWrite = now

        let database = RomDatabase.sharedInstance
        let games: [LibraryIndexGame] = database.all(PVGame.self)
            .filter("contentless == false")
            .map { game in
                let key = game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL
                // Side effect on purpose: copies local-only art into the group container.
                _ = widgetArtworkPath(for: game)
                return LibraryIndexGame(
                    filename: (game.romPath as NSString).lastPathComponent,
                    title: game.title,
                    systemName: game.system?.name ?? game.systemShortName,
                    systemIdentifier: game.systemIdentifier.isEmpty ? nil : game.systemIdentifier,
                    developer: emptyToNil(game.developer),
                    publishDate: emptyToNil(game.publishDate),
                    genre: emptyToNil(game.genres),
                    gameDescription: emptyToNil(game.gameDescription),
                    playCount: game.playCount,
                    isFavorite: game.isFavorite,
                    artworkKey: key.isEmpty ? nil : key)
            }

        let container = LibrarySnapshotAppGroup.containerURL
        let saves: [LibraryIndexSaveState] = database.all(PVSaveState.self).compactMap { state in
            guard let file = state.file, !file.partialPath.isEmpty,
                  let imageURL = state.image?.url,
                  let container,
                  imageURL.path.hasPrefix(container.path) else { return nil }
            let rel = String(imageURL.path.dropFirst(container.path.count + 1))
            return LibraryIndexSaveState(filename: (file.partialPath as NSString).lastPathComponent, imageRelativePath: rel)
        }

        let writer = LibraryIndexWriter(containerURL: container)
        DispatchQueue.global(qos: .utility).async {
            let ok = writer.write(games: games, saveStates: saves)
            DLOG("[WidgetDataWriter] library index write \(ok ? "ok" : "skipped") (\(games.count) games, \(saves.count) saves)")
        }
    }

    private func emptyToNil(_ value: String?) -> String? {
        value.flatMap { $0.isEmpty ? nil : $0 }
    }
}
```

Change `private func widgetArtworkPath(for game: PVGame)` to `func widgetArtworkPath(for game: PVGame)` (file-internal, same module).

At the end of `writeFromRealm()`, after the `writeGameData(...)` call, add:

```swift
        writeLibraryIndex()
```

- [ ] **Step 2: Force after imports**

At the import-completion call site (`PVGameLibraryUpdatesController.swift:131`, the line that calls `WidgetDataWriter.shared.writeFromRealm()`), add on the next line:

```swift
        WidgetDataWriter.shared.writeLibraryIndex(force: true)
```

- [ ] **Step 3: Build the app target**

Run:
```bash
xcodebuild build -workspace Provenance.xcworkspace -scheme "Provenance (AppStore)" -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/prov-build.log | xcbeautify | tail -5
```
Expected: `Build Succeeded`. (Full workspace build; allow 10+ minutes. If it fails on unrelated cached core steps, see CLAUDE.md "CI cache" notes; the relevant errors mention `WidgetDataWriter+Realm.swift`.)

- [ ] **Step 4: Commit**

```bash
git add PVUI/Sources/PVUIBase/Widgets/WidgetDataWriter+Realm.swift PVUI/Sources/PVUIBase/GameLibrary/PVGameLibraryUpdatesController.swift
git -c commit.gpgsign=false commit -m "feat(widgets): write the Quick Look library index from Realm, throttled

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `PVQuickLookSupport` goes Realm-free

**Files:**
- Modify: `PVQuickLookSupport/Package.swift`
- Modify: `PVQuickLookSupport/Sources/PVQuickLookSupport/ROMGameLookup.swift`
- Modify: `PVQuickLookSupport/Sources/PVQuickLookSupport/ArtworkResolver.swift`
- Create: `PVQuickLookSupport/Sources/PVQuickLookSupport/QuickLookLog.swift`
- Test: `PVQuickLookSupport/Tests/PVQuickLookSupportTests/SnapshotGamePreviewDataSourceTests.swift`
- Test: `PVQuickLookSupport/Tests/PVQuickLookSupportTests/ArtworkResolverTests.swift`

**Interfaces:**
- Consumes: `LibraryIndexReader`, `LibraryIndexWriter` (tests), `LibrarySnapshotAppGroup`.
- Produces: `SnapshotGamePreviewDataSource(reader:)` replacing `RealmGamePreviewDataSource`; `ArtworkResolver.fileURL(forKey:)`/`data(forKey:)` unchanged signatures, plus `ArtworkResolver.fileURL(forKey:containerURL:)` for tests; `GamePreviewDataSource`, `GameInfo`, `GameMetadataCard`, `SystemIconProvider` unchanged.

- [ ] **Step 1: Package manifest**

```swift
// PVQuickLookSupport/Package.swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PVQuickLookSupport",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "PVQuickLookSupport", targets: ["PVQuickLookSupport"])
    ],
    dependencies: [
        // Realm-free on purpose: this links into QLThumbnailProvider / QLPreviewProvider
        // processes. Library data comes from the App Group index written by the host.
        .package(path: "../PVAppIntents"),
    ],
    targets: [
        .target(
            name: "PVQuickLookSupport",
            dependencies: [
                .product(name: "PVLibrarySnapshot", package: "PVAppIntents"),
            ]
        ),
        .testTarget(
            name: "PVQuickLookSupportTests",
            dependencies: ["PVQuickLookSupport", .product(name: "PVLibrarySnapshot", package: "PVAppIntents")]
        ),
    ],
    swiftLanguageModes: [.v5],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx20
)
```

- [ ] **Step 2: Failing tests**

```swift
// PVQuickLookSupport/Tests/PVQuickLookSupportTests/SnapshotGamePreviewDataSourceTests.swift
import XCTest
import PVLibrarySnapshot
@testable import PVQuickLookSupport

final class SnapshotGamePreviewDataSourceTests: XCTestCase {
    private var container: URL!

    override func setUp() {
        super.setUp()
        container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: container)
        super.tearDown()
    }

    func testGameFromIndex() {
        let game = LibraryIndexGame(filename: "Chrono Trigger.sfc", title: "Chrono Trigger", systemName: "Super Nintendo",
                                    systemIdentifier: "com.provenance.snes", developer: "Square", publishDate: "1995",
                                    genre: "RPG", gameDescription: "Time travel.", playCount: 7, isFavorite: true,
                                    artworkKey: "ct_art")
        _ = LibraryIndexWriter(containerURL: container).write(games: [game], saveStates: [])
        let source = SnapshotGamePreviewDataSource(reader: LibraryIndexReader(containerURL: container))
        let info = source.game(forROMFilename: "Chrono Trigger.sfc")
        XCTAssertEqual(info?.title, "Chrono Trigger")
        XCTAssertEqual(info?.systemName, "Super Nintendo")
        XCTAssertEqual(info?.developer, "Square")
        XCTAssertEqual(info?.playCount, 7)
        XCTAssertEqual(info?.isFavorite, true)
        XCTAssertEqual(info?.artworkURLKey, "ct_art")
        XCTAssertNil(source.game(forROMFilename: "missing.sfc"))
        XCTAssertNil(source.game(forROMFilename: ""))
    }

    func testEmptyTitleDerivedFromFilename() {
        let game = LibraryIndexGame(filename: "Some_Game-Name.gba", title: "", systemName: nil, systemIdentifier: nil,
                                    developer: nil, publishDate: nil, genre: nil, gameDescription: nil,
                                    playCount: 0, isFavorite: false, artworkKey: nil)
        _ = LibraryIndexWriter(containerURL: container).write(games: [game], saveStates: [])
        let source = SnapshotGamePreviewDataSource(reader: LibraryIndexReader(containerURL: container))
        XCTAssertEqual(source.game(forROMFilename: "Some_Game-Name.gba")?.title, "Some Game Name")
    }

    func testSaveStateImageOnlyWhenFileExists() throws {
        let rel = "Documents/Save States/x.jpg"
        let img = container.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: img.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = LibraryIndexWriter(containerURL: container).write(games: [], saveStates: [LibraryIndexSaveState(filename: "x.svs", imageRelativePath: rel)])
        let source = SnapshotGamePreviewDataSource(reader: LibraryIndexReader(containerURL: container))
        XCTAssertNil(source.saveStateImageURL(forPath: "/any/dir/x.svs"), "index points at a file that does not exist yet")
        try Data([0xFF, 0xD8]).write(to: img)
        XCTAssertEqual(source.saveStateImageURL(forPath: "/any/dir/x.svs"), img)
    }
}
```

```swift
// PVQuickLookSupport/Tests/PVQuickLookSupportTests/ArtworkResolverTests.swift
import XCTest
@testable import PVQuickLookSupport

final class ArtworkResolverTests: XCTestCase {
    private var container: URL!

    override func setUp() {
        super.setUp()
        container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: container)
        super.tearDown()
    }

    func testMD5MatchesKnownVector() {
        XCTAssertEqual(ArtworkResolver.md5Hex("hello"), "5d41402abc4b2a76b9719d911017c592")
    }

    func testResolvesDocumentsPVCacheFirst() throws {
        let hash = ArtworkResolver.md5Hex("art-key")
        let docs = container.appendingPathComponent("Documents/PVCache/\(hash)")
        let caches = container.appendingPathComponent("Caches/PVCache/\(hash)")
        for u in [docs, caches] {
            try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([1]).write(to: u)
        }
        XCTAssertEqual(ArtworkResolver.fileURL(forKey: "art-key", containerURL: container), docs)
        try FileManager.default.removeItem(at: docs)
        XCTAssertEqual(ArtworkResolver.fileURL(forKey: "art-key", containerURL: container), caches)
    }

    func testMissingReturnsNil() {
        XCTAssertNil(ArtworkResolver.fileURL(forKey: "nothing", containerURL: container))
        XCTAssertNil(ArtworkResolver.fileURL(forKey: "", containerURL: container))
        XCTAssertNil(ArtworkResolver.fileURL(forKey: "x", containerURL: nil))
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `cd PVQuickLookSupport && swift test 2>&1 | tail -5`
Expected: compile errors (`SnapshotGamePreviewDataSource`, `md5Hex`, `containerURL:` label not found).

- [ ] **Step 4: Rewrite ROMGameLookup.swift**

Keep the header comment block, `GamePreviewDataSource`, the `ROMGameLookup` façade (`dataSource`, `lookup`, `saveStateImageURL`, `realFilename(from:)`, `romPathMatches`). Replace `import PVLibrary` / `import RealmSwift` with `import PVLibrarySnapshot`. Change the default data source line to:

```swift
    public static var dataSource: any GamePreviewDataSource = SnapshotGamePreviewDataSource()
```

Delete `RealmGamePreviewDataSource` and `openReadOnlyGroupRealm()` entirely and add:

```swift
// MARK: - SnapshotGamePreviewDataSource

/// Reads the App Group library index written by the host app
/// (`WidgetDataWriter.writeLibraryIndex`). No database is opened in the
/// extension process; a missing or stale index simply yields `nil`.
public struct SnapshotGamePreviewDataSource: GamePreviewDataSource {
    private let reader: LibraryIndexReader

    public init(reader: LibraryIndexReader = LibraryIndexReader()) {
        self.reader = reader
    }

    public func game(forROMFilename filename: String) -> GameInfo? {
        guard !filename.isEmpty, let entry = reader.game(forROMFilename: filename) else {
            QuickLookLog.debug("No index entry for \(filename)")
            return nil
        }
        return GameInfo(
            title: entry.title.isEmpty ? derivedTitle(from: entry.filename) : entry.title,
            systemName: entry.systemName,
            systemIdentifier: entry.systemIdentifier,
            developer: entry.developer,
            publishDate: entry.publishDate,
            genre: entry.genre,
            gameDescription: entry.gameDescription,
            playCount: entry.playCount,
            isFavorite: entry.isFavorite,
            artworkURLKey: entry.artworkKey
        )
    }

    public func saveStateImageURL(forPath path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        let filename = (path as NSString).lastPathComponent
        guard let url = reader.saveStateImageURL(forFilename: filename),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func derivedTitle(from filename: String) -> String {
        let noExt = (filename as NSString).deletingPathExtension
        return noExt
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}
```

Note `SnapshotGamePreviewDataSource` must be `Sendable`: `LibraryIndexReader` is declared `@unchecked Sendable` in Task 1, so this compiles under `swiftLanguageModes: [.v5]`.

- [ ] **Step 5: Rewrite ArtworkResolver.swift**

Replace the imports with `import Foundation`, `import CryptoKit`, `import PVLibrarySnapshot`. Replace the body of the struct with:

```swift
public struct ArtworkResolver {

    /// Candidate locations, relative to the group container, in priority order.
    static let candidateDirectories = [
        "Documents/PVCache",          // iOS/macOS with App Groups
        "Caches/PVCache",             // tvOS (documentsPath → Caches)
        "Library/Caches/PVCache",     // Top Shelf / CloudKit save-state art
        "PVCache",                    // root-level container path
    ]

    public static func fileURL(forKey key: String) -> URL? {
        fileURL(forKey: key, containerURL: LibrarySnapshotAppGroup.containerURL)
    }

    static func fileURL(forKey key: String, containerURL: URL?) -> URL? {
        guard !key.isEmpty, let containerURL else { return nil }
        let keyHash = md5Hex(key)
        for dir in candidateDirectories {
            let candidate = containerURL
                .appendingPathComponent(dir, isDirectory: true)
                .appendingPathComponent(keyHash, isDirectory: false)
            if FileManager.default.fileExists(atPath: candidate.path) {
                QuickLookLog.debug("Artwork resolved via \(dir)")
                return candidate
            }
        }
        QuickLookLog.debug("Artwork file not found for key hash: \(keyHash)")
        return nil
    }

    public static func data(forKey key: String) -> Data? {
        guard let url = fileURL(forKey: key) else { return nil }
        if url.isUbiquitousPlaceholder { return nil }
        return try? Data(contentsOf: url)
    }

    /// Lowercase hex MD5, matching `PVMediaCache`'s on-disk key hashing.
    static func md5Hex(_ key: String) -> String {
        Insecure.MD5.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
```

Keep the `private extension URL { var isUbiquitousPlaceholder }` block as is. Update the doc comment above the struct to drop the `PVMediaCache.filePath(forKey:)` fallback line.

- [ ] **Step 6: Logging shim**

```swift
// PVQuickLookSupport/Sources/PVQuickLookSupport/QuickLookLog.swift
//
//  QuickLookLog.swift
//  PVQuickLookSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  os.Logger wrapper. PVLogging is not linked here on purpose (keeps the
//  extension dependency graph to Foundation + PVLibrarySnapshot).
//

import Foundation
import os

enum QuickLookLog {
    private static let logger = Logger(subsystem: "org.provenance-emu.provenance", category: "quicklook")

    static func debug(_ message: @autoclosure () -> String) {
        logger.debug("\(message(), privacy: .public)")
    }

    static func error(_ message: @autoclosure () -> String) {
        logger.error("\(message(), privacy: .public)")
    }
}
```

Search the package for any remaining `DLOG(`, `ELOG(`, `WLOG(`, `PVAppGroupId`, `PVMediaCache`, `import PVLibrary`, `import PVHashing`, `import RealmSwift`:
```bash
grep -rn "DLOG\|ELOG\|WLOG\|PVAppGroupId\|PVMediaCache\|import PVLibrary\|import PVHashing\|RealmSwift" PVQuickLookSupport/Sources
```
Expected: no output.

- [ ] **Step 7: Run the package tests**

Run: `cd PVQuickLookSupport && swift test 2>&1 | tail -5`
Expected: 0 failures. `ROMGameLookupTests.testLookupReturnsNilWhenAppGroupsUnavailable` still passes because the test process has no group container.

- [ ] **Step 8: Commit**

```bash
git add PVQuickLookSupport
git -c commit.gpgsign=false commit -m "refactor(quicklook): PVQuickLookSupport reads the App Group index, drops Realm

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Quick Look targets: drop Realm links, embed `QuickLookPreview`

**Files:**
- Modify: `Provenance.xcodeproj/project.pbxproj`
- Modify: `Extensions/QuickLookPreview/PreviewProvider.swift:13-15` (remove the stale note)
- Delete: `Extensions/QuickLookPreview/PreviewViewController.swift`, `Extensions/QuickLookPreview/Base.lproj/` (storyboard)
- Rename: `Extensions/ThumbnailExtension/RealmThumbnailArtworkDriver.swift` → `SnapshotThumbnailArtworkDriver.swift` (class `SnapshotThumbnailArtworkDriver`), update `ThumbnailProvider.swift:23`.

**Interfaces:**
- Consumes: pbxproj object ids listed below (all verified in the current tree).
- Produces: `Provenance (AppStore)` embeds `QuickLookPreview.appex` (ios, maccatalyst); neither Quick Look target links `PVLibrary`.

Object ids:
- QuickLookPreview target `B3CC2200000000010000000A`; its `PVLibrary` product dep `B3CC2200000000010000000F` and build file `B3CC22000000000100000005`; `Defaults` build file `B3E2E8412F6BC1ED0010BDDE` / product dep `B3E2E8402F6BC1ED0010BDDE`; `PVArchivingFormats` build file `B33D87B72F9014CE00248544` / product dep `B33D87B62F9014CE00248544`; `PreviewViewController.swift` build file `B3CC22000000000100000003`, file ref `B355DF9B29209B6700E4C858`; storyboard file ref `B355DF9F29209B6700E4C858`; group `B355DF9A29209B6700E4C858`; product ref `B3CC22000000000100000001`.
- ThumbnailExtension target `B355DFFD2920AA2000E4C858`; product deps to remove: `B32C30782F6E6CD8003150F0` (Defaults), `B32C307A2F6E6CDE003150F0` (PVSettings), `B33D87BC2F9014EE00248544` (PVArchivingFormats) and their `in Frameworks` build files (grep each id).
- AppStore target `B394CC562BDEE53A006B63E8`, its embed phase `B394CD6A2BDEE53A006B63E8`, existing Thumbnail dependency `B32C30772F6E6AEE003150F0` with proxy `B32C30762F6E6AEE003150F0` (template).

- [ ] **Step 1: Source cleanups**

Delete `Extensions/QuickLookPreview/PreviewViewController.swift` and `Extensions/QuickLookPreview/Base.lproj/`. In `PreviewProvider.swift` delete the three-line `// NOTE: This file is ready for use once ... remove NSExtensionMainStoryboard.` comment and change the two comments that say "shared Realm database" to "App Group library index".

`git mv Extensions/ThumbnailExtension/RealmThumbnailArtworkDriver.swift Extensions/ThumbnailExtension/SnapshotThumbnailArtworkDriver.swift`, rename the class to `SnapshotThumbnailArtworkDriver`, update its doc comment ("Index-backed"), and in `ThumbnailProvider.swift` change the lazy driver line to `= SnapshotThumbnailArtworkDriver()`. In the pbxproj rename the file reference `B3AAAAAA00000003BBBBBB01` path/name and its build file comment accordingly.

- [ ] **Step 2: pbxproj: strip Realm-bearing package products from both Quick Look targets**

For `QuickLookPreview` (`B3CC2200000000010000000A`): remove `B3CC2200000000010000000F /* PVLibrary */`, `B3E2E8402F6BC1ED0010BDDE /* Defaults */`, `B33D87B62F9014CE00248544 /* PVArchivingFormats */` from `packageProductDependencies`; remove build files `B3CC22000000000100000005`, `B3E2E8412F6BC1ED0010BDDE`, `B33D87B72F9014CE00248544` from its Frameworks phase (`B3CC22000000000100000007`) and from the `PBXBuildFile` section; remove `B3CC22000000000100000003` (PreviewViewController) from its Sources phase (`B3CC22000000000100000006`) and the `PBXBuildFile` section; delete the `XCSwiftPackageProductDependency` objects `B3CC2200000000010000000F`, `B3E2E8402F6BC1ED0010BDDE`, `B33D87B62F9014CE00248544`; remove `B355DF9B29209B6700E4C858` and `B355DF9F29209B6700E4C858` from the group `B355DF9A29209B6700E4C858` and from `PBXFileReference` (and any `PBXVariantGroup` for `MainInterface.storyboard`, grep `MainInterface`).

For `ThumbnailExtension` (`B355DFFD2920AA2000E4C858`): remove `B32C30782F6E6CD8003150F0`, `B32C307A2F6E6CDE003150F0`, `B33D87BC2F9014EE00248544` from `packageProductDependencies`, their `in Frameworks` build files from its Frameworks phase (`B355DFFB2920AA2000E4C858`) and the `PBXBuildFile` section, and the three `XCSwiftPackageProductDependency` objects. Keep `1BA3F6932C1D4965AC324A86 /* PVQuickLookSupport */`.

- [ ] **Step 3: pbxproj: embed QuickLookPreview in the App Store target**

Add these objects (new ids):

```
/* PBXBuildFile */
C0C0CAFE0000000000006001 /* QuickLookPreview.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = B3CC22000000000100000001 /* QuickLookPreview.appex */; platformFilters = (ios, maccatalyst, ); settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };

/* PBXContainerItemProxy */
C0C0CAFE0000000000006002 /* PBXContainerItemProxy */ = {
    isa = PBXContainerItemProxy;
    containerPortal = 1A3D408C17B2DCE4004DFFFC /* Project object */;
    proxyType = 1;
    remoteGlobalIDString = B3CC2200000000010000000A;
    remoteInfo = QuickLookPreview;
};

/* PBXTargetDependency */
C0C0CAFE0000000000006003 /* PBXTargetDependency */ = {
    isa = PBXTargetDependency;
    platformFilters = (
        ios,
        maccatalyst,
    );
    target = B3CC2200000000010000000A /* QuickLookPreview */;
    targetProxy = C0C0CAFE0000000000006002 /* PBXContainerItemProxy */;
};
```

Add `C0C0CAFE0000000000006003 /* PBXTargetDependency */,` to the AppStore target's `dependencies` list and `C0C0CAFE0000000000006001 /* QuickLookPreview.appex in Embed Foundation Extensions */,` to the `files` of phase `B394CD6A2BDEE53A006B63E8`.

Make QuickLookPreview's three `XCBuildConfiguration`s match ThumbnailExtension's for platform settings: both already have `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"; SUPPORTS_MACCATALYST = NO; TARGETED_DEVICE_FAMILY = "1,2"; IPHONEOS_DEPLOYMENT_TARGET = 17.0;` (verified in the current tree) so no change is expected; confirm with `grep -n "SUPPORTS_MACCATALYST" -B30 project.pbxproj | grep -A30 QuickLookPreview.entitlements | grep SUPPORT`.

- [ ] **Step 4: Verify the project parses and both Quick Look targets build without Realm**

Run:
```bash
plutil -lint Provenance.xcodeproj/project.pbxproj && xcodebuild -workspace Provenance.xcworkspace -list | grep -E "QuickLookPreview|ThumbnailExtension" && xcodebuild build -workspace Provenance.xcworkspace -scheme "Provenance (AppStore)" -destination "generic/platform=iOS" -derivedDataPath /tmp/prov-dd CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/prov-ios.log | xcbeautify | tail -3 && ls /tmp/prov-dd/Build/Products/Release-iphoneos/Provenance.app/PlugIns/ && for x in ThumbnailExtension QuickLookPreview; do echo "== $x"; otool -L "/tmp/prov-dd/Build/Products/Release-iphoneos/Provenance.app/PlugIns/$x.appex/$x" | grep -ci "realm"; done
```
Expected: `OK`, both targets listed, `Build Succeeded`, `PlugIns/` contains `ThumbnailExtension.appex` and `QuickLookPreview.appex`, and `0` Realm references for each. (The configuration name in the products path may be `Release (AppStore)-iphoneos`; adjust the path from the `ls` of `/tmp/prov-dd/Build/Products`.)

- [ ] **Step 5: Commit**

```bash
git add -A Extensions/QuickLookPreview Extensions/ThumbnailExtension Provenance.xcodeproj/project.pbxproj
git -c commit.gpgsign=false commit -m "build(quicklook): embed QuickLookPreview, drop Realm links from QL extensions

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Ship the snapshot Top Shelf, delete `TopShelfv2`

**Files:**
- Modify: `Provenance.xcodeproj/project.pbxproj`
- Delete: `Extensions/TopShelfv2/` (ContentProvider.swift, TopShelfDataDriver.swift, PVGame+TopShelf.swift, DebugLogger.swift, Info.plist, TopShelf.entitlements)
- Modify: `docs/superpowers/specs/2026-08-07-macos-visionos-strategy-design.md:128-129`

**Interfaces:**
- Consumes: ids `B379CA022F00C7BB00C3D7A7` (embed build file), `B379CA032F00C7BB00C3D7A7` (proxy), `B379CA042F00C7BB00C3D7A7` (dependency), `BE9FDCB61C210B9E0046DF0E` (TopShelf target), `BE9FDCB71C210B9E0046DF0E` (TopShelf.appex), `B39B10AA2DAF3D16004EEF79` (TopShelfv2 target), `B39B10AB2DAF3D16004EEF79` (its appex), `B39B10AE2DAF3D16004EEF79` (its sync group), `B39B10B92DAF3D16004EEF79` (exception set), `B39B10B52DAF3D16004EEF79` (its config list).

- [ ] **Step 1: Repoint the App Store target at TopShelf**

Edit the three existing objects in place (no new ids needed):

```
B379CA022F00C7BB00C3D7A7 /* TopShelf.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = BE9FDCB71C210B9E0046DF0E /* TopShelf.appex */; platformFilters = (tvos, ); settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };

B379CA032F00C7BB00C3D7A7 /* PBXContainerItemProxy */ = {
    isa = PBXContainerItemProxy;
    containerPortal = 1A3D408C17B2DCE4004DFFFC /* Project object */;
    proxyType = 1;
    remoteGlobalIDString = BE9FDCB61C210B9E0046DF0E;
    remoteInfo = TopShelf;
};

B379CA042F00C7BB00C3D7A7 /* PBXTargetDependency */ = {
    isa = PBXTargetDependency;
    platformFilters = (
        tvos,
    );
    target = BE9FDCB61C210B9E0046DF0E /* TopShelf */;
    targetProxy = B379CA032F00C7BB00C3D7A7 /* PBXContainerItemProxy */;
};
```

Also update the comment on the embed-phase entry line inside `B394CD6A2BDEE53A006B63E8` to `TopShelf.appex in Embed Foundation Extensions`.

- [ ] **Step 2: Remove TopShelfv2 from the project**

Delete, in `project.pbxproj`: the `PBXNativeTarget` `B39B10AA2DAF3D16004EEF79` block (lines ~7544-7573) and every id it lists in `buildPhases` and `packageProductDependencies` (each of those objects and their `PBXBuildFile` entries, grep each id); the `PBXFileReference` `B39B10AB2DAF3D16004EEF79` and its entry in the Products group (line ~3836); the sync group `B39B10AE2DAF3D16004EEF79` (line ~2971) and its entry in the parent group (line ~5184); the exception set `B39B10B92DAF3D16004EEF79` (lines ~2532-2538); the `XCConfigurationList` `B39B10B52DAF3D16004EEF79` and the three `XCBuildConfiguration`s it lists (they contain `Extensions/TopShelfv2/Info.plist`, lines ~13820-13940); the `targets` entry (line ~9515) and the `TargetAttributes` entry (line ~7988). Then:

```bash
git rm -r Extensions/TopShelfv2
grep -n "TopShelfv2\|B39B10A\|B39B10B" Provenance.xcodeproj/project.pbxproj
```
Expected: no matches.

- [ ] **Step 3: Fix the stale doc line**

In `docs/superpowers/specs/2026-08-07-macos-visionos-strategy-design.md` change `and the stale TopShelf v1-style dead targets encountered along the way.` to `(the direct-Realm TopShelfv2 target was removed on 2026-09-23; the snapshot-based Extensions/TopShelf is the shipping Top Shelf).`

- [ ] **Step 4: Verify the tvOS build embeds exactly one Top Shelf without Realm**

Run:
```bash
plutil -lint Provenance.xcodeproj/project.pbxproj && xcodebuild build -workspace Provenance.xcworkspace -scheme "Provenance (AppStore)" -destination "generic/platform=tvOS" -derivedDataPath /tmp/prov-dd CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/prov-tvos.log | xcbeautify | tail -3 && ls /tmp/prov-dd/Build/Products/*-appletvos/Provenance.app/PlugIns/ && otool -L /tmp/prov-dd/Build/Products/*-appletvos/Provenance.app/PlugIns/TopShelf.appex/TopShelf | grep -ci realm
```
Expected: `OK`, `Build Succeeded`, `PlugIns/` contains `TopShelf.appex` only (no `TopShelfv2.appex`), and `0`.

- [ ] **Step 5: Commit**

```bash
git add -A Extensions/TopShelfv2 Provenance.xcodeproj/project.pbxproj docs/superpowers/specs/2026-08-07-macos-visionos-strategy-design.md
git -c commit.gpgsign=false commit -m "build(topshelf): ship snapshot-based TopShelf in AppStore, delete TopShelfv2

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Validation and device check

**Files:** none unless a gate fails.

- [ ] **Step 1: Package tests and lint**

Run:
```bash
(cd PVAppIntents && swift test 2>&1 | tail -2); (cd PVQuickLookSupport && swift test 2>&1 | tail -2); swiftlint lint --path PVUI/Sources/PVUIBase/Widgets/WidgetDataWriter+Realm.swift; swiftlint lint --path Extensions/ThumbnailExtension/SnapshotThumbnailArtworkDriver.swift; swiftlint lint --path Extensions/QuickLookPreview/PreviewProvider.swift
```
Expected: both test runs 0 failures, no new lint errors.

- [ ] **Step 2: iOS device: Files app**

Install the App Store scheme on an iPhone (Xcode or `xcrun devicectl`), launch once (this writes `LibraryIndex/*.json` and copies art into the group container), open Files → On My iPhone → Provenance → a system folder, icon view. Expected: box art thumbnails for matched ROMs; Quick Look shows the metadata card. Check the index exists with the device's container if needed via Xcode → Devices → Download Container; `Library/Caches/LibraryIndex/games-by-filename.json` should be present.

- [ ] **Step 3: Apple TV**

Install on an Apple TV (or tvOS simulator), play a game, return home, focus the icon. Expected: recent games row from `Extensions/TopShelf/ServiceProvider.swift` (deep link `provenance://open?md5=`). If art is blank on a real device, check the provisioning profile carries the App Group (see the iCube doc `docs/app-group-entitlements.md` in the iCube repo for the wildcard-profile trap).

- [ ] **Step 4: Tick the TODO and commit**

If Step 3 shows the row, change `TODO.md:158` to `- [x] Top Shelf extension shows recent games` and commit:
```bash
git add TODO.md && git -c commit.gpgsign=false commit -m "docs: Top Shelf recent games verified on tvOS

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Self-review notes

- Spec 3.6 bullets: Top Shelf swap + TopShelfv2 delete + doc fix → Task 5; index files + reader → Task 1; host writer with throttle and forced import write → Task 2; PVQuickLookSupport Realm-free (data source, ArtworkResolver, identifier, tests) → Task 3; target dependency cleanup, PreviewViewController/storyboard removal, embed in AppStore with `(ios, maccatalyst)` filters, stale comment → Task 4; gates → Task 6.
- `GameInfo.artworkURLKey` keeps its meaning (raw key); hashing moved from PVHashing to CryptoKit inside `ArtworkResolver.md5Hex`, tested against the standard "hello" vector.
- Names used consistently: `LibraryIndexGame`, `LibraryIndexSaveState`, `LibraryIndexPaths`, `LibraryIndexWriter`, `LibraryIndexReader`, `SnapshotGamePreviewDataSource`, `SnapshotThumbnailArtworkDriver`, `QuickLookLog`, `WidgetDataWriter.writeLibraryIndex(force:)`.
