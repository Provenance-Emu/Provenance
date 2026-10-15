//
//  MultiFileSetMetadataLookupTests.swift
//  PVLibraryTests
//
//  A cue/gdi/m3u game's md5Hash is its data track (`MultiFileSetIdentity`), but
//  OpenVGDB keys CD games by the MD5 and name of the unmodified redump .cue. The
//  metadata lookup therefore also tries the index file's MD5 and its full name.
//

@testable import PVLibrary
import Foundation
import Testing

@Suite("Set metadata lookup keys")
struct MultiFileSetMetadataLookupTests {

    /// The redump cue of "007 Racing (Europe)" (PSX), CRLF line endings as redump ships it.
    /// OpenVGDB's row for it: romHashMD5 94239B716D59A53EB83330F7C90115B5, romSize 85,
    /// romFileName "007 Racing (Europe).cue".
    static let redumpCue = "FILE \"007 Racing (Europe).bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n"
    static let openVGDBMD5 = "94239B716D59A53EB83330F7C90115B5"

    @Test func identityComesFirstThenTheIndexFile() {
        let keys = GameImporterDatabaseService.metadataLookupMD5s(identity: "aaaa", indexFileMD5: "bbbb")
        #expect(keys == ["AAAA", "BBBB"])
    }

    @Test func noIndexFileOrTheSameMD5GivesOneKey() {
        #expect(GameImporterDatabaseService.metadataLookupMD5s(identity: "AAAA", indexFileMD5: nil) == ["AAAA"])
        #expect(GameImporterDatabaseService.metadataLookupMD5s(identity: "AAAA", indexFileMD5: "aaaa") == ["AAAA"])
        #expect(GameImporterDatabaseService.metadataLookupMD5s(identity: "AAAA", indexFileMD5: "") == ["AAAA"])
    }

    @Test func indexFileTriesItsFullNameBeforeTheCutTitle() {
        #expect(GameImporterDatabaseService.filenameLookupKeys(forFileName: "007 Racing (Europe).cue")
                == ["007 Racing (Europe).cue", "007 Racing"])
        #expect(GameImporterDatabaseService.filenameLookupKeys(forFileName: "Shenmue (USA) (Disc 1).gdi")
                == ["Shenmue (USA) (Disc 1).gdi", "Shenmue"])
    }

    @Test func otherFilesKeepTheCutTitleOnly() {
        #expect(GameImporterDatabaseService.filenameLookupKeys(forFileName: "Sonic (USA).md") == ["Sonic"])
        #expect(GameImporterDatabaseService.filenameLookupKeys(forFileName: "game.bin") == ["game.bin"])
    }

    @Test func queueItemReportsTheRawCueMD5ThatOpenVGDBStores() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("MultiFileSetMetadataLookupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let cue = folder.appendingPathComponent("007 Racing (Europe).cue")
        try Data(Self.redumpCue.utf8).write(to: cue)
        let item = ImportQueueItem(url: cue, fileType: .cdRom)
        #expect(GameImporterDatabaseService.indexFileMD5ForLookup(of: item) == nil, "never hashes on its own")
        _ = await item.md5Async()
        #expect(GameImporterDatabaseService.indexFileMD5ForLookup(of: item) == Self.openVGDBMD5)

        let track = folder.appendingPathComponent("007 Racing (Europe).bin")
        try Data([0, 1, 2]).write(to: track)
        let trackItem = ImportQueueItem(url: track, fileType: .cdRom)
        _ = await trackItem.md5Async()
        #expect(GameImporterDatabaseService.indexFileMD5ForLookup(of: trackItem) == nil)
    }
}
