//
//  MultiFileImportSetTests.swift
//  PVLibraryTests
//
//  Multi-file games arriving one file at a time (sibling share sheet): index
//  parsing and rewriting, renamed-copy fix-ups, NAOMI companion pairing and the
//  settle rule.
//

@testable import PVLibrary
import Foundation
import Testing

@Suite("Index file references")
struct MultiFileIndexReferencesTests {

    @Test func cueFileLinesQuotedAndUnquoted() {
        let cue = """
        FILE "Game (Track 1).bin" BINARY
          TRACK 01 MODE2/2352
            INDEX 01 00:00:00
        FILE track02.bin BINARY
          TRACK 02 AUDIO
        REM FILE "not-a-file.bin" BINARY
        """
        #expect(MultiFileIndexReferences.referencedFiles(of: .cue, contents: cue)
                == ["Game (Track 1).bin", "track02.bin"])
    }

    @Test func gdiTrackTable() {
        let gdi = "3\r\n1 0 4 2352 track01.bin 0\r\n2 756 0 2352 track02.raw 0\r\n3 45000 4 2352 \"track 03.bin\" 0\r\n"
        #expect(MultiFileIndexReferences.referencedFiles(of: .gdi, contents: gdi)
                == ["track01.bin", "track02.raw", "track 03.bin"])
    }

    @Test func gdiUnquotedNameWithSpaces() {
        let gdi = "2\n1 0 4 2352 Crazy Taxi (Track 1).bin 0\n2 600 0 2352 Crazy Taxi (Track 2).raw 0\n"
        #expect(MultiFileIndexReferences.referencedFiles(of: .gdi, contents: gdi)
                == ["Crazy Taxi (Track 1).bin", "Crazy Taxi (Track 2).raw"])
    }

    @Test func m3uSkipsCommentsAndStripsPaths() {
        let m3u = "#EXTM3U\nDisc 1.gdi\n\n  discs/Disc 2.gdi  \nC:\\games\\Disc 3.cue\n"
        #expect(MultiFileIndexReferences.referencedFiles(of: .m3u, contents: m3u)
                == ["Disc 1.gdi", "Disc 2.gdi", "Disc 3.cue"])
    }

    @Test func rewriteCueKeepsEverythingElse() {
        let cue = "FILE \"track01.bin\" BINARY\r\n  TRACK 01 MODE1/2352\r\nFILE \"track02.bin\" BINARY\r\n"
        let rewritten = MultiFileIndexReferences.rewritingReference(in: cue, kind: .cue, from: "TRACK01.BIN", to: "track01-1.bin")
        #expect(rewritten == "FILE \"track01-1.bin\" BINARY\r\n  TRACK 01 MODE1/2352\r\nFILE \"track02.bin\" BINARY\r\n")
    }

    @Test func rewriteGdiQuotesNamesWithSpaces() {
        let gdi = "2\n1 0 4 2352 track01.bin 0\n2 756 0 2352 track02.raw 0\n"
        let plain = MultiFileIndexReferences.rewritingReference(in: gdi, kind: .gdi, from: "track02.raw", to: "track02-1.raw")
        #expect(plain == "2\n1 0 4 2352 track01.bin 0\n2 756 0 2352 track02-1.raw 0\n")
        let spaced = MultiFileIndexReferences.rewritingReference(in: gdi, kind: .gdi, from: "track01.bin", to: "track 01-1.bin")
        #expect(spaced == "2\n1 0 4 2352 \"track 01-1.bin\" 0\n2 756 0 2352 track02.raw 0\n")
    }

    @Test func rewriteM3uKeepsPathPrefix() {
        let m3u = "discs/Disc 1.cue\nDisc 2.cue"
        let rewritten = MultiFileIndexReferences.rewritingReference(in: m3u, kind: .m3u, from: "disc 1.cue", to: "Disc 1-1.cue")
        #expect(rewritten == "discs/Disc 1-1.cue\nDisc 2.cue")
    }

    @Test func renamedCopyNames() {
        #expect(RenamedCopyName.original(of: "track01-1.bin")?.name == "track01.bin")
        #expect(RenamedCopyName.original(of: "track01-12.raw")?.copy == 12)
        #expect(RenamedCopyName.original(of: "Sonic-Adventure.gdi") == nil)
        #expect(RenamedCopyName.original(of: "track01.bin") == nil)
        #expect(RenamedCopyName.original(of: "-1.bin") == nil)
    }
}

@Suite("NAOMI companion layout")
struct ArchiveCompanionLayoutTests {

    @Test func chdNestsUnderTheZipStem() {
        #expect(ArchiveCompanionLayout.relativePath(archiveName: "ikaruga.zip", companionName: "gdl-0010.chd")
                == "ikaruga/gdl-0010.chd")
        let archive = URL(fileURLWithPath: "/ROMs/com.provenance.naomi/ikaruga.zip")
        #expect(ArchiveCompanionLayout.companionDirectory(forArchiveAt: archive).path
                == "/ROMs/com.provenance.naomi/ikaruga")
        let staging = ArchiveCompanionLayout.stagingDirectory(importDirectory: URL(fileURLWithPath: "/Imports"), archiveName: "ikaruga.7z")
        #expect(staging.path == "/Imports/.archive-companions/ikaruga")
    }

    @Test func onlyGDROMNamesPair() {
        #expect(ArchiveCompanionLayout.isGDROMImageName("gdl-0010.chd"))
        #expect(ArchiveCompanionLayout.isGDROMImageName("GDS-0005A.chd"))
        #expect(ArchiveCompanionLayout.isGDROMImageName("cdp-10001c.chd"))
        #expect(!ArchiveCompanionLayout.isGDROMImageName("Crazy Taxi.chd"))
        #expect(!ArchiveCompanionLayout.isGDROMImageName("gdl-0010.zip"))
    }
}

@Suite("Settle rule")
struct MultiFileImportSettlerTests {

    let policy = MultiFileImportSettlePolicy(quietWindow: 3, incompleteSetTimeout: 20)
    let gdi = "3\n1 0 4 2352 track01.bin 0\n2 756 0 2352 track02.raw 0\n3 45000 4 2352 track03.bin 0\n"

    @Test func nothingIsReleasedBeforeTheFolderIsQuiet() {
        let snapshot = MultiFileImportSnapshot(
            pending: ["game.gdi", "track01.bin", "track02.raw", "track03.bin"],
            present: [], indexContents: ["game.gdi": gdi], secondsSinceLastArrival: 1)
        let decision = MultiFileImportSettler.decide(snapshot, policy: policy)
        #expect(decision.release.isEmpty)
        #expect(decision.recheckAfter == 2)
        #expect(MultiFileImportSettler.fixups(for: snapshot, policy: policy).isEmpty)
    }

    @Test func completeGdiSetIsReleasedTogetherIndexFirst() {
        let snapshot = MultiFileImportSnapshot(
            pending: ["track02.raw", "game.gdi", "track01.bin", "track03.bin"],
            present: [], indexContents: ["game.gdi": gdi], secondsSinceLastArrival: 3)
        let decision = MultiFileImportSettler.decide(snapshot, policy: policy)
        #expect(decision.release == ["game.gdi", "track01.bin", "track02.raw", "track03.bin"])
        #expect(decision.hold.isEmpty)
        #expect(decision.recheckAfter == nil)
    }

    @Test func incompleteSetWaitsThenGoesAsItIs() {
        var snapshot = MultiFileImportSnapshot(
            pending: ["game.gdi", "track01.bin"],
            present: [], indexContents: ["game.gdi": gdi], secondsSinceLastArrival: 5)
        let waiting = MultiFileImportSettler.decide(snapshot, policy: policy)
        #expect(waiting.release.isEmpty)
        #expect(waiting.hold == ["game.gdi", "track01.bin"])
        #expect(waiting.recheckAfter == 15)

        snapshot.secondsSinceLastArrival = 20
        let timedOut = MultiFileImportSettler.decide(snapshot, policy: policy)
        #expect(timedOut.release == ["game.gdi", "track01.bin"])
    }

    @Test func m3uWaitsForEveryDiscAndItsTracks() {
        let m3u = "Disc 1.cue\nDisc 2.cue\n"
        let cue1 = "FILE \"Disc 1.bin\" BINARY\n"
        let cue2 = "FILE \"Disc 2.bin\" BINARY\n"
        var snapshot = MultiFileImportSnapshot(
            pending: ["Game.m3u", "Disc 1.cue", "Disc 1.bin", "Disc 2.cue"],
            present: [], indexContents: ["Game.m3u": m3u, "Disc 1.cue": cue1, "Disc 2.cue": cue2],
            secondsSinceLastArrival: 4)
        #expect(MultiFileImportSettler.decide(snapshot, policy: policy).release.isEmpty)

        snapshot.pending.append("Disc 2.bin")
        let decision = MultiFileImportSettler.decide(snapshot, policy: policy)
        #expect(decision.release == ["Game.m3u", "Disc 1.cue", "Disc 1.bin", "Disc 2.cue", "Disc 2.bin"])
    }

    @Test func loneFilesGoButLoneTracksWait() {
        let snapshot = MultiFileImportSnapshot(
            pending: ["Sonic.bin", "track02.raw", "track01-1.bin"],
            present: [], indexContents: [:], secondsSinceLastArrival: 3)
        let decision = MultiFileImportSettler.decide(snapshot, policy: policy)
        #expect(decision.release == ["Sonic.bin"])
        #expect(decision.hold == ["track02.raw", "track01-1.bin"])
    }

    @Test func trackForAnIndexReleasedEarlierGoesStraightThrough() {
        let snapshot = MultiFileImportSnapshot(
            pending: ["track03.bin"],
            present: ["game.gdi", "track01.bin", "track02.raw"],
            indexContents: ["game.gdi": gdi], secondsSinceLastArrival: 3)
        #expect(MultiFileImportSettler.decide(snapshot, policy: policy).release == ["track03.bin"])
    }

    // Branch A: the original name is free.
    @Test func renamedTrackIsRenamedBackWhenTheOriginalIsFree() {
        let snapshot = MultiFileImportSnapshot(
            pending: ["game.gdi", "track01.bin", "track02-1.raw", "track03.bin"],
            present: [], indexContents: ["game.gdi": gdi], secondsSinceLastArrival: 3)
        #expect(MultiFileImportSettler.fixups(for: snapshot, policy: policy)
                == [.rename(from: "track02-1.raw", to: "track02.raw")])
    }

    // Branch B: two GDI sets with the same generic track names.
    @Test func renamedTracksOfASecondSetRewriteThatSetsIndex() {
        let snapshot = MultiFileImportSnapshot(
            pending: ["A.gdi", "track01.bin", "track02.raw", "track03.bin",
                      "B.gdi", "track01-1.bin", "track02-1.raw", "track03-1.bin"],
            present: [], indexContents: ["A.gdi": gdi, "B.gdi": gdi], secondsSinceLastArrival: 3)
        #expect(MultiFileImportSettler.fixups(for: snapshot, policy: policy) == [
            .rewriteReference(indexFile: "B.gdi", from: "track01.bin", to: "track01-1.bin"),
            .rewriteReference(indexFile: "B.gdi", from: "track02.raw", to: "track02-1.raw"),
            .rewriteReference(indexFile: "B.gdi", from: "track03.bin", to: "track03-1.bin")
        ])
    }

    @Test func renamedCopyWithASingleOwnerIsLeftAlone() {
        let snapshot = MultiFileImportSnapshot(
            pending: ["game.gdi", "track01.bin", "track01-1.bin", "track02.raw", "track03.bin"],
            present: [], indexContents: ["game.gdi": gdi], secondsSinceLastArrival: 3)
        #expect(MultiFileImportSettler.fixups(for: snapshot, policy: policy).isEmpty)
    }

    @Test func gdromChdPairsWithTheZipBeforeIt() {
        let snapshot = MultiFileImportSnapshot(
            pending: ["ikaruga.zip", "gdl-0010.chd", "Sonic.zip", "gds-0001.chd", "Crazy Taxi.chd"],
            present: [], indexContents: [:], secondsSinceLastArrival: 3)
        #expect(MultiFileImportSettler.fixups(for: snapshot, policy: policy) == [
            .nestCompanion(file: "gdl-0010.chd", archive: "ikaruga.zip"),
            .nestCompanion(file: "gds-0001.chd", archive: "Sonic.zip")
        ])
    }

    @Test func gdromChdThatArrivesFirstPairsWithTheOnlyArchive() {
        let alone = MultiFileImportSnapshot(
            pending: ["gdl-0010.chd", "ikaruga.zip"], present: [], indexContents: [:], secondsSinceLastArrival: 3)
        #expect(MultiFileImportSettler.fixups(for: alone, policy: policy)
                == [.nestCompanion(file: "gdl-0010.chd", archive: "ikaruga.zip")])

        let ambiguous = MultiFileImportSnapshot(
            pending: ["gdl-0010.chd", "a.zip", "b.zip"], present: [], indexContents: [:], secondsSinceLastArrival: 3)
        #expect(MultiFileImportSettler.fixups(for: ambiguous, policy: policy).isEmpty)
    }

    @Test func singleChdWithoutArchiveIsAGame() {
        let snapshot = MultiFileImportSnapshot(
            pending: ["gdl-0010.chd"], present: [], indexContents: [:], secondsSinceLastArrival: 3)
        #expect(MultiFileImportSettler.fixups(for: snapshot, policy: policy).isEmpty)
        #expect(MultiFileImportSettler.decide(snapshot, policy: policy).release == ["gdl-0010.chd"])
    }
}

@Suite("Incoming file receiver")
struct IncomingFileReceiverTests {

    private func makeSandbox() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IncomingFileReceiverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func copiesTheOriginalAndLeavesItInPlace() throws {
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("Other App/game.gdi")
        try FileManager.default.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("3\n".utf8).write(to: original)
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)

        let copy = try IncomingFileReceiver.receive(original, into: imports, inbox: inbox)

        #expect(copy.lastPathComponent == "game.gdi")
        #expect(FileManager.default.fileExists(atPath: original.path))
        #expect(try Data(contentsOf: copy) == Data("3\n".utf8))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: imports.path)
        #expect(leftovers == ["game.gdi"])
    }

    @Test func removesItsOwnInboxCopyAndNeverOverwrites() throws {
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        try Data("first".utf8).write(to: imports.appendingPathComponent("track01.bin"))
        let inboxCopy = inbox.appendingPathComponent("track01.bin")
        try Data("second".utf8).write(to: inboxCopy)

        let copy = try IncomingFileReceiver.receive(inboxCopy, into: imports, inbox: inbox)

        #expect(copy.lastPathComponent == "track01-1.bin")
        #expect(!FileManager.default.fileExists(atPath: inboxCopy.path))
        #expect(try Data(contentsOf: imports.appendingPathComponent("track01.bin")) == Data("first".utf8))
        #expect(try Data(contentsOf: copy) == Data("second".utf8))
    }
}

@Suite("Import gate")
struct MultiFileImportGateTests {

    private actor Releases {
        private(set) var batches: [[String]] = []
        func add(_ urls: [URL]) { batches.append(urls.map(\.lastPathComponent)) }
    }

    private let policy = MultiFileImportSettlePolicy(quietWindow: 0.1, incompleteSetTimeout: 0.6)

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("MultiFileImportGateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func makeGate(_ folder: URL, _ releases: Releases) -> MultiFileImportGate {
        MultiFileImportGate(directory: folder, policy: policy, isBusy: { false }, release: { await releases.add($0) })
    }

    @discardableResult
    private func write(_ name: String, _ text: String = "x", in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    /// Polls until `count` batches arrived (or about 3 s passed).
    private func batches(_ releases: Releases, count: Int) async -> [[String]] {
        for _ in 0..<60 {
            let batches = await releases.batches
            if batches.count >= count { return batches }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return await releases.batches
    }

    @Test func gdiSetArrivingOneFileAtATimeIsReleasedOnce() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let releases = Releases()
        let gate = makeGate(folder, releases)

        let gdi = "2\n1 0 4 2352 track01.bin 0\n2 756 0 2352 track02.raw 0\n"
        await gate.submit([try write("game.gdi", gdi, in: folder)])
        await gate.submit([try write("track02.raw", in: folder)])
        await gate.submit([try write("track01.bin", in: folder)])

        #expect(await batches(releases, count: 1) == [["game.gdi", "track01.bin", "track02.raw"]])
    }

    @Test func renamedTrackIsRenamedBackOnDisk() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let releases = Releases()
        let gate = makeGate(folder, releases)

        let gdi = "2\n1 0 4 2352 track01.bin 0\n2 756 0 2352 track02.raw 0\n"
        await gate.submit([try write("game.gdi", gdi, in: folder),
                           try write("track01.bin", in: folder),
                           try write("track02-1.raw", in: folder)])

        #expect(await batches(releases, count: 1) == [["game.gdi", "track01.bin", "track02.raw"]])
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("track02.raw").path))
    }

    @Test func gdromChdIsStagedForItsZip() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let releases = Releases()
        let gate = makeGate(folder, releases)

        await gate.submit([try write("ikaruga.zip", in: folder)])
        await gate.submit([try write("gdl-0010.chd", in: folder)])

        #expect(await batches(releases, count: 1) == [["ikaruga.zip"]])
        let staged = ArchiveCompanionLayout.stagingDirectory(importDirectory: folder, archiveName: "ikaruga.zip")
            .appendingPathComponent("gdl-0010.chd")
        #expect(FileManager.default.fileExists(atPath: staged.path))
    }

    @Test func sameNameAfterTheFirstWasImportedIsANewArrival() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let releases = Releases()
        let gate = makeGate(folder, releases)

        let first = try write("Sonic.bin", "one", in: folder)
        await gate.submit([first])
        #expect(await batches(releases, count: 1).count == 1)

        // The watcher reports a file again on every folder change: no second release.
        await gate.submit([first])
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(await releases.batches.count == 1)

        // Imported (moved away), then shared again under the same name.
        // atPath: — the URL overload is PVLibrary's async extension (DirectoryWatcher.swift).
        try FileManager.default.removeItem(atPath: first.path)
        await gate.submit([try write("Sonic.bin", "two", in: folder)])
        #expect(await batches(releases, count: 2) == [["Sonic.bin"], ["Sonic.bin"]])
    }
}
