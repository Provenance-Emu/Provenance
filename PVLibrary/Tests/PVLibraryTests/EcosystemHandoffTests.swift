//
//  EcosystemHandoffTests.swift
//  PVLibraryTests
//
//  The receiving half of the cross-app drop box, against a temporary directory
//  standing in for the App Group container.
//

@testable import PVLibrary
import XCTest

final class EcosystemHandoffTests: XCTestCase {
    private var root: URL!
    private var imports: URL!
    private let fileManager = FileManager.default
    private let created = Date(timeIntervalSince1970: 1_800_000_000)
    private let md5 = "1a2b3c4d5e6f708192a3b4c5d6e7f809"

    override func setUpWithError() throws {
        let base = fileManager.temporaryDirectory.appendingPathComponent("EcosystemHandoffTests-\(UUID().uuidString)")
        root = base.appendingPathComponent("Ecosystem", isDirectory: true)
        imports = base.appendingPathComponent("Imports", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imports, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: root.deletingLastPathComponent())
    }

    // MARK: - Helpers

    /// Writes `Handoff/<inbox>/<directoryName>/` with a manifest listing `files`
    /// (path → contents) and the files themselves.
    @discardableResult
    private func makeHandoff(
        id: String = "A1B2C3D4-0000-0000-0000-000000000000",
        directoryName: String? = nil,
        inbox: String = "provenance",
        version: Int = 1,
        kind: String = "game",
        to: String = "provenance",
        from: String = "ifly",
        md5: String? = nil,
        files: [(path: String, role: String, contents: String)],
        writeFiles: Bool = true
    ) throws -> URL {
        let directory = EcosystemHandoff.inbox(for: inbox, root: root)
            .appendingPathComponent(directoryName ?? id, isDirectory: true)
        let filesDirectory = directory.appendingPathComponent("files", isDirectory: true)
        try fileManager.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        if writeFiles {
            for file in files {
                let url = filesDirectory.appendingPathComponent(file.path)
                try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(file.contents.utf8).write(to: url)
            }
        }
        let manifest = EcosystemHandoffManifest(
            version: version, id: id, from: from, to: to, created: created, kind: kind,
            title: "Test Game", system: "dreamcast", md5: md5 ?? self.md5,
            files: files.map { .init(path: $0.path, role: $0.role, size: Int64($0.contents.utf8.count)) })
        try EcosystemHandoff.encoder().encode(manifest)
            .write(to: directory.appendingPathComponent("manifest.json"))
        return directory
    }

    private func onlyPending() throws -> EcosystemHandoffInbox.Pending {
        let pending = EcosystemHandoffInbox.pending(root: root)
        XCTAssertEqual(pending.count, 1)
        return try XCTUnwrap(pending.first)
    }

    private func visibleImports() throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: imports.path).filter { !$0.hasPrefix(".") }.sorted()
    }

    private func hiddenImports() throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: imports.path).filter { $0.hasPrefix(".") }.sorted()
    }

    private func contents(_ url: URL) throws -> String {
        String(bytes: try Data(contentsOf: url), encoding: .utf8) ?? ""
    }

    private func makeReceiver() -> EcosystemHandoffReceiver {
        let root: URL = self.root
        let imports: URL = self.imports
        return EcosystemHandoffReceiver(root: { root }, importDirectory: { imports })
    }

    // MARK: - Placement

    func testDiscSetWithIndexIsPlacedAsOneContainerAndHandoffRemoved() throws {
        let gdi = "3\n1 0 4 2352 track01.bin 0\n2 600 0 2352 track02.raw 0\n3 45000 4 2352 track03.bin 0\n"
        let handoff = try makeHandoff(files: [
            ("game.gdi", "primary", gdi),
            ("track01.bin", "companion", "one"),
            ("track02.raw", "companion", "two"),
            ("track03.bin", "companion", "three")
        ])

        let placement = try EcosystemHandoffInbox.place(try onlyPending(), into: imports)

        let container = imports.appendingPathComponent("iFly EMU-1a2b3c4d", isDirectory: true)
        XCTAssertEqual(placement.imported, [container])
        XCTAssertEqual(try visibleImports(), ["iFly EMU-1a2b3c4d"])
        XCTAssertEqual(
            try fileManager.contentsOfDirectory(atPath: container.path).sorted(),
            ["game.gdi", "track01.bin", "track02.raw", "track03.bin"])
        XCTAssertEqual(try contents(container.appendingPathComponent("game.gdi")), gdi)
        XCTAssertFalse(fileManager.fileExists(atPath: handoff.path), "the hand-off is deleted once placed")
        XCTAssertEqual(try hiddenImports(), [], "no staging folder is left behind")
        XCTAssertTrue(EcosystemHandoffInbox.pending(root: root).isEmpty)
    }

    func testContainerNameAvoidsAnExistingFolder() throws {
        try fileManager.createDirectory(
            at: imports.appendingPathComponent("iFly EMU-1a2b3c4d", isDirectory: true), withIntermediateDirectories: true)
        try makeHandoff(files: [("game.cue", "primary", "FILE \"game.bin\" BINARY\n"), ("game.bin", "companion", "x")])

        let placement = try EcosystemHandoffInbox.place(try onlyPending(), into: imports)

        XCTAssertEqual(placement.imported.map(\.lastPathComponent), ["iFly EMU-1a2b3c4d-1"])
    }

    func testContainerNameFallsBackToHandoffIDWithoutUsableMD5() throws {
        try makeHandoff(md5: "not-hex!", files: [("game.m3u", "primary", "disc1.chd\n"), ("disc1.chd", "primary", "d")])
        let pending = try onlyPending()
        XCTAssertEqual(EcosystemHandoffInbox.containerName(for: pending), "iFly EMU-A1B2C3D4")

        let fromICube = EcosystemHandoffInbox.Pending(
            directory: pending.directory,
            manifest: { var manifest = pending.manifest; manifest.from = "dolphinios"; return manifest }())
        XCTAssertEqual(EcosystemHandoffInbox.containerName(for: fromICube), "iCube-A1B2C3D4")
    }

    func testSingleImageWithoutIndexGoesFlatIntoImports() throws {
        // A folder holding a lone CHD is not a game to the importer, so it lands flat.
        try makeHandoff(files: [("Crazy Taxi.chd", "primary", "disc")])

        let placement = try EcosystemHandoffInbox.place(try onlyPending(), into: imports)

        XCTAssertEqual(placement.imported, [imports.appendingPathComponent("Crazy Taxi.chd")])
        XCTAssertEqual(try visibleImports(), ["Crazy Taxi.chd"])
        XCTAssertEqual(try hiddenImports(), [])
    }

    func testNaomiCompanionIsStagedForItsArchive() throws {
        try makeHandoff(files: [
            ("ikaruga.zip", "primary", "zip"),
            ("ikaruga/gdl-0010.chd", "companion", "gdrom")
        ])

        let placement = try EcosystemHandoffInbox.place(try onlyPending(), into: imports)

        let companion = ArchiveCompanionLayout.stagingDirectory(importDirectory: imports, archiveName: "ikaruga.zip")
            .appendingPathComponent("gdl-0010.chd")
        XCTAssertEqual(placement.imported, [imports.appendingPathComponent("ikaruga.zip")])
        XCTAssertEqual(placement.stagedCompanions, [companion])
        XCTAssertEqual(try contents(companion), "gdrom")
        XCTAssertEqual(try visibleImports(), ["ikaruga.zip"])
        XCTAssertEqual(try hiddenImports(), [ArchiveCompanionLayout.stagingDirectoryName])
    }

    func testFlatNameClashGetsFreeNameAndCompanionFollowsTheRenamedArchive() throws {
        try Data("older".utf8).write(to: imports.appendingPathComponent("ikaruga.zip"))
        try makeHandoff(files: [
            ("ikaruga.zip", "primary", "zip"),
            ("ikaruga/gdl-0010.chd", "companion", "gdrom")
        ])

        let placement = try EcosystemHandoffInbox.place(try onlyPending(), into: imports)

        XCTAssertEqual(placement.imported.map(\.lastPathComponent), ["ikaruga-1.zip"])
        XCTAssertEqual(try contents(imports.appendingPathComponent("ikaruga.zip")), "older")
        XCTAssertEqual(placement.stagedCompanions, [
            ArchiveCompanionLayout.stagingDirectory(importDirectory: imports, archiveName: "ikaruga-1.zip")
                .appendingPathComponent("gdl-0010.chd")
        ])
    }

    func testOnlyListedFilesArePlaced() throws {
        let handoff = try makeHandoff(files: [("game.cdi", "primary", "disc")])
        try Data("stowaway".utf8).write(to: handoff.appendingPathComponent("files/extra.cdi"))

        try EcosystemHandoffInbox.place(try onlyPending(), into: imports)

        XCTAssertEqual(try visibleImports(), ["game.cdi"])
    }

    // MARK: - Left alone

    func testStagingDirectoryIsIgnored() throws {
        try makeHandoff(directoryName: ".A1B2C3D4.staging", files: [("game.chd", "primary", "disc")])
        XCTAssertTrue(EcosystemHandoffInbox.pending(root: root).isEmpty)
    }

    func testNewerVersionUnknownKindAndOtherRecipientAreIgnored() throws {
        try makeHandoff(id: "newer", version: 2, files: [("a.chd", "primary", "a")])
        try makeHandoff(id: "save", kind: "save", files: [("b.chd", "primary", "b")])
        try makeHandoff(id: "misrouted", to: "ifly", files: [("c.chd", "primary", "c")])
        try makeHandoff(id: "for-ifly", inbox: "ifly", to: "ifly", files: [("d.chd", "primary", "d")])

        XCTAssertTrue(EcosystemHandoffInbox.pending(root: root).isEmpty)
        let outcomes = makeReceiver()
            .receivePendingNow()
        XCTAssertEqual(outcomes, [])
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: imports.path), [])
        for id in ["newer", "save", "misrouted"] {
            XCTAssertTrue(fileManager.fileExists(
                atPath: EcosystemHandoff.inbox(for: "provenance", root: root).appendingPathComponent(id).path))
        }
    }

    func testUnsafeRelativePaths() {
        for path in ["../escape.chd", "/etc/passwd", "a/../b.chd", "a//b.chd", "", "./a.chd", "a/./b.chd",
                     ".hidden.chd", "dir/.hidden", "dir\\file.chd", "trailing/"] {
            XCTAssertFalse(EcosystemHandoffInbox.isSafeRelativePath(path), path)
        }
        for path in ["game.chd", "ikaruga/gdl-0010.chd", "Disc 1/Track 01.bin"] {
            XCTAssertTrue(EcosystemHandoffInbox.isSafeRelativePath(path), path)
        }
    }

    func testUnsafePathRefusesTheWholeHandoff() throws {
        let handoff = try makeHandoff(
            files: [("game.chd", "primary", "disc"), ("../outside.bin", "companion", "x")], writeFiles: false)
        try Data("disc".utf8).write(to: handoff.appendingPathComponent("files/game.chd"))

        XCTAssertThrowsError(try EcosystemHandoffInbox.place(try onlyPending(), into: imports)) { error in
            XCTAssertEqual(error as? EcosystemHandoffInbox.Refusal, .unsafePath("../outside.bin"))
        }
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: imports.path), [], "nothing is copied")
        XCTAssertTrue(fileManager.fileExists(atPath: handoff.path), "a refused hand-off stays for its sender")
    }

    func testMissingFileRefusesTheWholeHandoff() throws {
        let handoff = try makeHandoff(
            files: [("game.gdi", "primary", "1\n1 0 4 2352 track01.bin 0\n"), ("track01.bin", "companion", "t")],
            writeFiles: false)
        try Data("1\n".utf8).write(to: handoff.appendingPathComponent("files/game.gdi"))

        XCTAssertThrowsError(try EcosystemHandoffInbox.place(try onlyPending(), into: imports)) { error in
            XCTAssertEqual(error as? EcosystemHandoffInbox.Refusal, .missingFile("track01.bin"))
        }
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: imports.path), [])
        XCTAssertTrue(fileManager.fileExists(atPath: handoff.path))
    }

    func testSymlinkIsRefused() throws {
        let outside = root.deletingLastPathComponent().appendingPathComponent("secret.realm")
        try Data("private".utf8).write(to: outside)
        let handoff = try makeHandoff(files: [("game.chd", "primary", "disc")], writeFiles: false)
        try fileManager.createSymbolicLink(
            at: handoff.appendingPathComponent("files/game.chd"), withDestinationURL: outside)

        XCTAssertThrowsError(try EcosystemHandoffInbox.place(try onlyPending(), into: imports)) { error in
            XCTAssertEqual(error as? EcosystemHandoffInbox.Refusal, .missingFile("game.chd"))
        }
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: imports.path), [])
    }

    func testManifestWithoutPrimaryIsRefused() throws {
        try makeHandoff(files: [("track01.bin", "companion", "t")])
        XCTAssertThrowsError(try EcosystemHandoffInbox.place(try onlyPending(), into: imports)) { error in
            XCTAssertEqual(error as? EcosystemHandoffInbox.Refusal, .noPrimaryFile)
        }
    }

    func testLeftoverStagingIsRemoved() throws {
        let leftover = imports.appendingPathComponent(".ecosystem-dead", isDirectory: true)
        try fileManager.createDirectory(at: leftover, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: leftover.appendingPathComponent("half.chd"))
        let companions = imports.appendingPathComponent(ArchiveCompanionLayout.stagingDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: companions, withIntermediateDirectories: true)

        EcosystemHandoffInbox.removeLeftoverStaging(in: imports)

        XCTAssertEqual(try hiddenImports(), [ArchiveCompanionLayout.stagingDirectoryName])
    }

    // MARK: - Receiver

    func testReceiverPlacesWaitingHandoffsOnceAndReportsRefusalOnce() throws {
        try makeHandoff(id: "good", files: [("game.cdi", "primary", "disc")])
        try makeHandoff(id: "bad", files: [("../x.cdi", "primary", "x")], writeFiles: false)
        let receiver = makeReceiver()

        let first = receiver.receivePendingNow()
        XCTAssertEqual(first.count, 2)
        XCTAssertTrue(first.contains { if case .received = $0 { return true } else { return false } })
        XCTAssertTrue(first.contains { if case .refused(_, .unsafePath("../x.cdi")) = $0 { return true } else { return false } })
        XCTAssertEqual(try visibleImports(), ["game.cdi"])

        XCTAssertEqual(receiver.receivePendingNow(), [], "placed is gone, refused is not reported again")
    }

    func testReceiverWithoutGroupContainerDoesNothing() {
        let receiver = EcosystemHandoffReceiver(root: { nil }, importDirectory: { FileManager.default.temporaryDirectory })
        XCTAssertEqual(receiver.receivePendingNow(), [])
    }

    // MARK: - Presence and wire format

    func testPresenceRoundTripsAndAdvertisesGameHandoffForAnySystem() throws {
        let receiver = makeReceiver()
        receiver.publishPresenceNow(now: created)

        let presence = try XCTUnwrap(EcosystemPresence.read(scheme: "provenance", root: root))
        XCTAssertEqual(presence.version, 1)
        XCTAssertEqual(presence.scheme, "provenance")
        XCTAssertEqual(presence.handoff, 1)
        XCTAssertEqual(presence.accepts, ["game"])
        XCTAssertEqual(presence.systems, [])
        XCTAssertEqual(presence.updated, created)
        XCTAssertEqual(presence, EcosystemPresence.own(now: created))
        XCTAssertTrue(fileManager.fileExists(atPath: root.appendingPathComponent("Apps/provenance.json").path))
    }

    func testPresenceIsWrittenTheWaySiblingsDecodeIt() throws {
        try EcosystemPresence.own(now: created).write(root: root)
        let data = try Data(contentsOf: EcosystemHandoff.presenceURL(for: "provenance", root: root))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(
            Set(json.keys),
            ["version", "scheme", "bundleID", "appVersion", "build", "handoff", "accepts", "systems", "updated"])
        XCTAssertEqual(json["updated"] as? String, "2027-01-15T08:00:00Z", "ISO 8601 string, not a number")

        // iFly and iCube decode with `.iso8601` and no other options.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(EcosystemPresence.self, from: data).handoff, 1)
    }

    func testDecodesAManifestAsIFlyWritesIt() throws {
        let json = """
        {
          "created" : "2026-11-17T10:20:30Z",
          "files" : [
            { "path" : "ikaruga.zip", "role" : "primary", "size" : 1024 },
            { "path" : "ikaruga/gdl-0010.chd", "role" : "companion", "size" : 2048 }
          ],
          "from" : "ifly",
          "id" : "6F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0",
          "kind" : "game",
          "md5" : "0123456789abcdef0123456789abcdef",
          "system" : "naomi",
          "title" : "Ikaruga",
          "to" : "provenance",
          "version" : 1
        }
        """
        let manifest = try EcosystemHandoff.decoder().decode(EcosystemHandoffManifest.self, from: Data(json.utf8))
        XCTAssertEqual(manifest.files.map(\.path), ["ikaruga.zip", "ikaruga/gdl-0010.chd"])
        XCTAssertEqual(manifest.files.map(\.role), ["primary", "companion"])
        XCTAssertEqual(manifest.system, "naomi")
        XCTAssertEqual(manifest.to, "provenance")
    }

    func testRecognisesTheWakeURL() throws {
        XCTAssertTrue(EcosystemHandoff.isWakeURL(try XCTUnwrap(URL(string: "provenance://handoff?id=abc&from=ifly"))))
        XCTAssertTrue(EcosystemHandoff.isWakeURL(try XCTUnwrap(URL(string: "Provenance://HANDOFF"))))
        XCTAssertFalse(EcosystemHandoff.isWakeURL(try XCTUnwrap(URL(string: "provenance://ifly?games=abc"))))
        XCTAssertFalse(EcosystemHandoff.isWakeURL(try XCTUnwrap(URL(string: "ifly://handoff?id=abc"))))
    }
}
