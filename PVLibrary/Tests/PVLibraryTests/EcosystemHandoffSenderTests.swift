//
//  EcosystemHandoffSenderTests.swift
//  PVLibraryTests
//
//  The sending half of the cross-app drop box (Provenance to iCube), against a
//  temporary directory standing in for the App Group container.
//

@testable import PVLibrary
import PVSystems
import XCTest

final class EcosystemHandoffSenderTests: XCTestCase {
    private var base: URL!
    private var root: URL!
    private var library: URL!
    private let fileManager = FileManager.default
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let handoffID = "C0FFEE00-0000-0000-0000-000000000001"

    override func setUpWithError() throws {
        base = fileManager.temporaryDirectory.appendingPathComponent("EcosystemHandoffSenderTests-\(UUID().uuidString)")
        root = base.appendingPathComponent("Ecosystem", isDirectory: true)
        library = base.appendingPathComponent("ROMs", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: library, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: base)
    }

    // MARK: - Helpers

    private var iCubeInbox: URL { EcosystemHandoff.inbox(for: "dolphinios", root: root) }

    private func makeLibraryFile(_ name: String, contents: String = "disc image bytes") throws -> URL {
        let url = library.appendingPathComponent(name)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        return url
    }

    /// Writes `Apps/dolphinios.json` as iCube publishes it, with overrides.
    private func publishICube(handoff: Int = 1, accepts: [String] = ["game"], systems: [String] = ["gamecube", "wii"]) throws {
        try EcosystemPresence(
            version: 1, scheme: "dolphinios", bundleID: "com.joemattiello.icube", appVersion: "1.0", build: "1",
            handoff: handoff, accepts: accepts, systems: systems, updated: now
        ).write(root: root)
    }

    private func game(_ file: URL, system: SystemIdentifier = .GameCube, md5: String? = "ABCDEF0123456789ABCDEF0123456789") -> EcosystemHandoffSender.Game {
        EcosystemHandoffSender.Game(title: "Super Mario Sunshine", system: system, md5: md5, file: file)
    }

    private func route(_ game: EcosystemHandoffSender.Game, installed: Bool = true, root: URL?? = nil) -> EcosystemHandoffSender.Route? {
        EcosystemHandoffSender.route(for: game, isInstalled: { _ in installed }, root: root ?? self.root)
    }

    private func inboxItems() -> [String] {
        ((try? fileManager.contentsOfDirectory(atPath: iCubeInbox.path)) ?? []).sorted()
    }

    /// Writes a complete hand-off as `sender` would, with its manifest's `created`.
    @discardableResult
    private func makeHandoff(in inbox: String, id: String, from sender: String, created: Date) throws -> URL {
        let directory = EcosystemHandoff.inbox(for: inbox, root: root).appendingPathComponent(id, isDirectory: true)
        let files = directory.appendingPathComponent("files", isDirectory: true)
        try fileManager.createDirectory(at: files, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: files.appendingPathComponent("game.iso"))
        let manifest = EcosystemHandoffManifest(
            version: 1, id: id, from: sender, to: inbox, created: created, kind: "game", title: "Old",
            files: [.init(path: "game.iso", role: "primary", size: 1)])
        try EcosystemHandoff.encoder().encode(manifest).write(to: directory.appendingPathComponent("manifest.json"))
        return directory
    }

    private func makeStaging(in inbox: String, id: String, modified: Date) throws -> URL {
        let directory = EcosystemHandoff.inbox(for: inbox, root: root)
            .appendingPathComponent(".\(id).staging", isDirectory: true)
        try fileManager.createDirectory(at: directory.appendingPathComponent("files"), withIntermediateDirectories: true)
        try fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: directory.path)
        return directory
    }

    // MARK: - Staging layout and wire format

    func testStageWritesTheContractLayoutUnderItsFinalName() throws {
        let iso = try makeLibraryFile("Super Mario Sunshine (USA).iso")
        let entry = EcosystemHandoffStager.Entry(source: iso, relativePath: iso.lastPathComponent, role: "primary")

        let manifest = try EcosystemHandoffStager.stage(
            [entry], to: "dolphinios", title: "Super Mario Sunshine", system: "gamecube",
            md5: "ABCDEF0123456789ABCDEF0123456789", root: root, id: handoffID, now: now)

        XCTAssertEqual(inboxItems(), [handoffID], "only the final directory: the staging one was renamed")
        let directory = iCubeInbox.appendingPathComponent(handoffID, isDirectory: true)
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: directory.path).sorted(), ["files", "manifest.json"])
        let staged = directory.appendingPathComponent("files/Super Mario Sunshine (USA).iso")
        XCTAssertEqual(try Data(contentsOf: staged), try Data(contentsOf: iso))
        XCTAssertTrue(fileManager.fileExists(atPath: iso.path), "the library keeps its copy")

        XCTAssertEqual(manifest.version, 1)
        XCTAssertEqual(manifest.id, handoffID)
        XCTAssertEqual(manifest.from, "provenance")
        XCTAssertEqual(manifest.to, "dolphinios")
        XCTAssertEqual(manifest.kind, "game")
        XCTAssertEqual(manifest.system, "gamecube")
        XCTAssertEqual(manifest.md5, "abcdef0123456789abcdef0123456789", "md5 is lowercase on the wire")
        XCTAssertEqual(manifest.files, [.init(path: "Super Mario Sunshine (USA).iso", role: "primary", size: 16)])
    }

    func testManifestJSONUsesTheSharedKeysAndWholeSecondDates() throws {
        let iso = try makeLibraryFile("game.iso")
        let fractional = now.addingTimeInterval(0.75)
        try EcosystemHandoffStager.stage(
            [.init(source: iso, relativePath: "game.iso", role: "primary")],
            to: "dolphinios", title: "Game", system: "wii", md5: nil, root: root, id: handoffID, now: fractional)

        let data = try Data(contentsOf: iCubeInbox.appendingPathComponent("\(handoffID)/manifest.json"))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["version", "id", "from", "to", "created", "kind", "title", "system", "files"],
                       "md5 is omitted when absent")
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(json["created"] as? String, "2027-01-15T08:00:00Z", "ISO 8601, no fractional seconds")
        let files = try XCTUnwrap(json["files"] as? [[String: Any]])
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(Set(files[0].keys), ["path", "role", "size"])
        XCTAssertEqual(files[0]["path"] as? String, "game.iso")
        XCTAssertEqual(files[0]["role"] as? String, "primary")
        XCTAssertEqual(files[0]["size"] as? Int, 16)
    }

    func testNestedPathsKeepForwardSlashLayout() throws {
        let iso = try makeLibraryFile("set/disc1.iso")
        try EcosystemHandoffStager.stage(
            [.init(source: iso, relativePath: "set/disc1.iso", role: "primary")],
            to: "dolphinios", title: "Game", system: nil, md5: nil, root: root, id: handoffID, now: now)
        XCTAssertTrue(fileManager.fileExists(atPath: iCubeInbox.appendingPathComponent("\(handoffID)/files/set/disc1.iso").path))
    }

    func testStagedHandoffIsWhatAReceiverReads() throws {
        // Provenance's own inbox reader stands in for iCube's: same contract, same checks.
        let iso = try makeLibraryFile("game.iso")
        let manifest = try EcosystemHandoffStager.stage(
            [.init(source: iso, relativePath: "game.iso", role: "primary")],
            to: "provenance", title: "Game", system: "gamecube", md5: nil, root: root, id: handoffID, now: now)

        let pending = EcosystemHandoffInbox.pending(root: root)
        XCTAssertEqual(pending.map(\.manifest), [manifest])
    }

    // MARK: - Failed stage leaves nothing

    func testFailedCopyRemovesTheStagingDirectory() throws {
        let first = try makeLibraryFile("disc1.iso")
        let second = try makeLibraryFile("disc2.iso")
        let failing = FailingSecondCopyFileManager()

        XCTAssertThrowsError(try EcosystemHandoffStager.stage(
            [.init(source: first, relativePath: "disc1.iso", role: "primary"),
             .init(source: second, relativePath: "disc2.iso", role: "primary")],
            to: "dolphinios", title: "Game", system: "gamecube", md5: nil, root: root,
            id: handoffID, now: now, fileManager: failing))

        XCTAssertEqual(failing.copies, 2, "the failure happened after the staging directory had content")
        XCTAssertEqual(inboxItems(), [], "neither the staging directory nor a final one is left")
    }

    func testMissingSourceFailsBeforeAnythingIsWritten() {
        let missing = library.appendingPathComponent("gone.iso")
        XCTAssertThrowsError(try EcosystemHandoffStager.stage(
            [.init(source: missing, relativePath: "gone.iso", role: "primary")],
            to: "dolphinios", title: "Game", system: "gamecube", md5: nil, root: root, id: handoffID, now: now)
        ) { XCTAssertEqual($0 as? EcosystemHandoffStager.StageError, .notARegularFile(missing)) }
        XCTAssertEqual(inboxItems(), [])
    }

    func testSymbolicLinkSourceIsRefused() throws {
        let iso = try makeLibraryFile("game.iso")
        let link = library.appendingPathComponent("link.iso")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: iso)

        XCTAssertThrowsError(try EcosystemHandoffStager.stage(
            [.init(source: link, relativePath: "link.iso", role: "primary")],
            to: "dolphinios", title: "Game", system: "gamecube", md5: nil, root: root, id: handoffID, now: now)
        ) { XCTAssertEqual($0 as? EcosystemHandoffStager.StageError, .notARegularFile(link)) }
        XCTAssertEqual(inboxItems(), [])
    }

    func testUnsafePathsAreRefused() throws {
        let iso = try makeLibraryFile("game.iso")
        for path in ["../game.iso", "./game.iso", ".hidden.iso", "set/.hidden/game.iso", "a//game.iso",
                     "/abs/game.iso", "set\\game.iso", "", "set/"] {
            XCTAssertThrowsError(try EcosystemHandoffStager.stage(
                [.init(source: iso, relativePath: path, role: "primary")],
                to: "dolphinios", title: "Game", system: nil, md5: nil, root: root, id: handoffID, now: now),
                "\(path) must be refused"
            ) { XCTAssertEqual($0 as? EcosystemHandoffStager.StageError, .unsafePath(path)) }
        }
        XCTAssertEqual(inboxItems(), [])
    }

    func testDuplicatePathsAndNoPrimaryAreRefused() throws {
        let iso = try makeLibraryFile("game.iso")
        XCTAssertThrowsError(try EcosystemHandoffStager.stage(
            [.init(source: iso, relativePath: "Game.iso", role: "primary"),
             .init(source: iso, relativePath: "game.iso", role: "companion")],
            to: "dolphinios", title: "Game", system: nil, md5: nil, root: root, id: handoffID, now: now)
        ) { XCTAssertEqual($0 as? EcosystemHandoffStager.StageError, .unsafePath("game.iso")) }
        XCTAssertThrowsError(try EcosystemHandoffStager.stage(
            [.init(source: iso, relativePath: "game.iso", role: "companion")],
            to: "dolphinios", title: "Game", system: nil, md5: nil, root: root, id: handoffID, now: now)
        ) { XCTAssertEqual($0 as? EcosystemHandoffStager.StageError, .noPrimaryFile) }
        XCTAssertThrowsError(try EcosystemHandoffStager.stage(
            [], to: "dolphinios", title: "Game", system: nil, md5: nil, root: root, id: handoffID, now: now)
        ) { XCTAssertEqual($0 as? EcosystemHandoffStager.StageError, .noPrimaryFile) }
        XCTAssertEqual(inboxItems(), [])
    }

    // MARK: - Presence gating

    func testGameCubeAndWiiMapToICubesPublishedSystemIDs() {
        XCTAssertEqual(EcosystemHandoffSender.target(for: .GameCube), .init(app: .icube, systemID: "gamecube"))
        XCTAssertEqual(EcosystemHandoffSender.target(for: .Wii), .init(app: .icube, systemID: "wii"))
        XCTAssertNil(EcosystemHandoffSender.target(for: .Dreamcast), "only iCube is a send target")
        XCTAssertNil(EcosystemHandoffSender.target(for: .PSX))
    }

    func testRouteNeedsInstalledPeerWithMatchingPresence() throws {
        let iso = try makeLibraryFile("game.iso")
        try publishICube()

        let found = try XCTUnwrap(route(game(iso)))
        XCTAssertEqual(found.target, .init(app: .icube, systemID: "gamecube"))
        XCTAssertEqual(found.file, iso.resolvingSymlinksInPath())
        XCTAssertNotNil(route(game(iso, system: .Wii)))

        XCTAssertNil(route(game(iso), installed: false), "not installed: canOpenURL said no")
        XCTAssertNil(route(game(iso), root: .some(nil)), "no App Group container")
        XCTAssertNil(route(game(iso, system: .PSX)), "no sibling takes PlayStation")
    }

    func testRouteNeedsAPresenceEntry() throws {
        let iso = try makeLibraryFile("game.iso")
        XCTAssertNil(route(game(iso)), "iCube never wrote Apps/dolphinios.json")

        try fileManager.createDirectory(at: root.appendingPathComponent("Apps"), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: EcosystemHandoff.presenceURL(for: "dolphinios", root: root))
        XCTAssertNil(route(game(iso)), "an unreadable presence entry is no presence")
    }

    func testRouteHonoursHandoffVersionKindsAndSystems() throws {
        let iso = try makeLibraryFile("game.iso")

        try publishICube(handoff: 0)
        XCTAssertNil(route(game(iso)), "handoff 0: iCube does not receive")

        try publishICube(accepts: ["save"])
        XCTAssertNil(route(game(iso)), "iCube does not list game")

        try publishICube(systems: ["gamecube"])
        XCTAssertNotNil(route(game(iso, system: .GameCube)))
        XCTAssertNil(route(game(iso, system: .Wii)), "wii is not in the published systems")

        try publishICube(systems: [])
        XCTAssertNotNil(route(game(iso, system: .Wii)), "empty systems: any system")

        try publishICube(handoff: 2)
        XCTAssertNotNil(route(game(iso)), "a newer receiver still takes version 1")
    }

    func testRouteRefusesFilesICubeWillNotImport() throws {
        try publishICube()
        for name in ["game.zip", "game.7z", "game.m3u", "game.cue", "game.chd"] {
            XCTAssertNil(route(game(try makeLibraryFile(name))), "\(name) must fall back")
        }
        for name in ["a.iso", "b.GCM", "c.rvz", "d.wbfs", "e.ciso", "f.gcz", "g.wad", "h.nkit", "i.wia",
                     "j.tgc", "k.dol", "l.elf", "m.img", "n.bin"] {
            XCTAssertNotNil(route(game(try makeLibraryFile(name))), "\(name) is a disc image iCube imports")
        }
        XCTAssertNil(route(game(library.appendingPathComponent("missing.iso"))), "a file not on this device")
        let folder = library.appendingPathComponent("folder.iso", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        XCTAssertNil(route(game(folder)), "a directory is not a disc image")
    }

    func testRouteResolvesALibrarySymlinkToTheRealFile() throws {
        try publishICube()
        let real = try makeLibraryFile("real/game.iso")
        let link = library.appendingPathComponent("game.iso")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: real)

        let found = try XCTUnwrap(route(game(link)))
        XCTAssertEqual(found.file, real.resolvingSymlinksInPath())
    }

    func testPresenceAccepts() {
        func presence(handoff: Int = 1, accepts: [String] = ["game"], systems: [String] = []) -> EcosystemPresence {
            EcosystemPresence(version: 1, scheme: "dolphinios", bundleID: "", appVersion: "", build: "",
                              handoff: handoff, accepts: accepts, systems: systems, updated: now)
        }
        XCTAssertTrue(presence().accepts(kind: "game", system: "wii"))
        XCTAssertTrue(presence(systems: ["wii"]).accepts(kind: "game", system: "wii"))
        XCTAssertFalse(presence(systems: ["gamecube"]).accepts(kind: "game", system: "wii"))
        XCTAssertFalse(presence(handoff: 0).accepts(kind: "game", system: "wii"))
        XCTAssertFalse(presence(accepts: []).accepts(kind: "game", system: "wii"))
    }

    // MARK: - Send

    func testSendStagesTheDiscImageForICubeAndReturnsTheWakeURL() throws {
        try publishICube()
        let wbfs = try makeLibraryFile("Wii Sports (USA).wbfs")
        let wiiGame = game(wbfs, system: .Wii)
        let found = try XCTUnwrap(route(wiiGame))

        let sent = try EcosystemHandoffSender.send(wiiGame, via: found, root: root, id: handoffID, now: now)

        XCTAssertEqual(sent.wakeURL?.absoluteString, "dolphinios://handoff?id=\(handoffID)&from=provenance")
        XCTAssertEqual(sent.manifest.to, "dolphinios")
        XCTAssertEqual(sent.manifest.system, "wii")
        XCTAssertEqual(sent.manifest.title, "Super Mario Sunshine")
        XCTAssertEqual(sent.manifest.files, [.init(path: "Wii Sports (USA).wbfs", role: "primary", size: 16)])
        XCTAssertEqual(inboxItems(), [handoffID])
        XCTAssertTrue(fileManager.fileExists(
            atPath: iCubeInbox.appendingPathComponent("\(handoffID)/files/Wii Sports (USA).wbfs").path))
    }

    func testWakeURLMatchesTheContract() {
        XCTAssertEqual(EcosystemHandoff.wakeURL(to: "DolphiniOS", id: "abc")?.absoluteString,
                       "dolphinios://handoff?id=abc&from=provenance")
    }

    // MARK: - Clean up

    func testCollectGarbageRemovesOnlyStaleOwnHandoffsAndDeadStaging() throws {
        let week = EcosystemHandoff.staleAfter
        let hour = EcosystemHandoff.stagingStaleAfter
        let staleOwn = try makeHandoff(in: "dolphinios", id: "stale-own", from: "provenance", created: now - week - 60)
        let freshOwn = try makeHandoff(in: "dolphinios", id: "fresh-own", from: "provenance", created: now - week + 60)
        let staleOther = try makeHandoff(in: "provenance", id: "stale-other", from: "dolphinios", created: now - week - 60)
        let staleIFly = try makeHandoff(in: "dolphinios", id: "stale-ifly", from: "ifly", created: now - week - 60)
        let deadStaging = try makeStaging(in: "dolphinios", id: "dead", modified: now - hour - 60)
        let liveStaging = try makeStaging(in: "dolphinios", id: "live", modified: now - hour + 60)

        let removed = EcosystemHandoffStager.collectGarbage(root: root, now: now)

        XCTAssertEqual(removed, 2)
        XCTAssertFalse(fileManager.fileExists(atPath: staleOwn.path))
        XCTAssertFalse(fileManager.fileExists(atPath: deadStaging.path))
        for kept in [freshOwn, staleOther, staleIFly, liveStaging] {
            XCTAssertTrue(fileManager.fileExists(atPath: kept.path), "\(kept.lastPathComponent) must stay")
        }
    }

    func testCollectGarbageWithoutAnInboxDoesNothing() {
        XCTAssertEqual(EcosystemHandoffStager.collectGarbage(root: root, now: now), 0)
    }

    func testReceiverActivationCollectsGarbage() throws {
        let stale = try makeHandoff(
            in: "dolphinios", id: "stale-own", from: "provenance", created: now - EcosystemHandoff.staleAfter - 60)
        let root: URL = self.root
        let imports = base.appendingPathComponent("Imports", isDirectory: true)
        let receiver = EcosystemHandoffReceiver(root: { root }, importDirectory: { imports })

        XCTAssertEqual(receiver.collectGarbageNow(now: now), 1)
        XCTAssertFalse(fileManager.fileExists(atPath: stale.path))
        XCTAssertEqual(EcosystemHandoffReceiver(root: { nil }, importDirectory: { imports }).collectGarbageNow(now: now), 0)
    }
}

/// Lets the first copy through and fails the second, so a stage dies after the
/// staging directory already holds a file.
private final class FailingSecondCopyFileManager: FileManager {
    private(set) var copies = 0

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copies += 1
        if copies == 2 {
            throw CocoaError(.fileWriteOutOfSpace)
        }
        try super.copyItem(at: srcURL, to: dstURL)
    }
}
