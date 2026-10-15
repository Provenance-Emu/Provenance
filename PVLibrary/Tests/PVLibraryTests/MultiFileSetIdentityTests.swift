//
//  MultiFileSetIdentityTests.swift
//  PVLibraryTests
//
//  A cue/gdi/m3u game is identified by its data track, not its index text: which
//  track that is, that two games with a byte-identical .gdi get different
//  identities, and that a game imported under the old rule (index MD5) is still
//  recognised when it is imported again.
//

@testable import PVLibrary
import CryptoKit
import Foundation
import Testing

@Suite("Set identity track")
struct MultiFileSetIdentityReferenceTests {

    private func reference(_ kind: MultiFileIndexKind, _ text: String) -> String? {
        MultiFileIndexReferences.identityReference(of: kind, contents: text)
    }

    @Test func cueTakesTheFirstFileWithADataTrack() {
        let psx = """
        FILE "Game (Track 1).bin" BINARY
          TRACK 01 MODE2/2352
            INDEX 01 00:00:00
        FILE "Game (Track 2).bin" BINARY
          TRACK 02 AUDIO
            INDEX 01 00:00:00
        """
        #expect(reference(.cue, psx) == "Game (Track 1).bin")

        // PC Engine CD: an audio warning track comes first.
        let pce = """
        FILE "Game (Track 01).bin" BINARY
          TRACK 01 AUDIO
            INDEX 01 00:00:00
        FILE "Game (Track 02).bin" BINARY
          TRACK 02 MODE1/2352
            INDEX 01 00:00:00
        FILE "Game (Track 03).bin" BINARY
          TRACK 03 MODE1/2352
            INDEX 01 00:00:00
        """
        #expect(reference(.cue, pce) == "Game (Track 02).bin")
    }

    @Test func cueWithOneFileForEveryTrackTakesThatFile() {
        let single = "FILE \"game.bin\" BINARY\r\n  TRACK 01 MODE1/2048\r\n    INDEX 01 00:00:00\r\n  TRACK 02 AUDIO\r\n"
        #expect(reference(.cue, single) == "game.bin")
    }

    @Test func cueKeywordsAndModesAreCaseInsensitiveAndUnquotedNamesWork() {
        #expect(reference(.cue, "file game.img binary\ntrack 1 mode2/2336\n") == "game.img")
        #expect(reference(.cue, "FILE \"cdi.bin\" BINARY\nTRACK 01 CDI/2352\n") == "cdi.bin")
    }

    @Test func audioOnlyCueHasNoIdentityTrack() {
        #expect(reference(.cue, "FILE \"a.wav\" WAVE\n  TRACK 01 AUDIO\nFILE \"b.wav\" WAVE\n  TRACK 02 AUDIO\n") == nil)
        #expect(reference(.cue, "TRACK 01 MODE1/2352\n") == nil)
    }

    @Test func gdiTakesTheLastDataTrack() {
        let gdi = """
        3
        1 0 4 2352 track01.bin 0
        2 450 0 2352 track02.raw 0
        3 45000 4 2352 track03.bin 0
        """
        #expect(reference(.gdi, gdi) == "track03.bin")

        let quoted = "5\n1 0 4 2352 \"Game (Track 1).bin\" 0\n2 600 0 2352 \"Game (Track 2).bin\" 0\n"
            + "3 45000 4 2352 \"Game (Track 3).bin\" 0\n4 300000 0 2352 \"Game (Track 4).bin\" 0\n"
            + "5 310000 4 2352 \"Game (Track 5).bin\" 0\n"
        #expect(reference(.gdi, quoted) == "Game (Track 5).bin")
    }

    @Test func gdiCountLineAndAudioTracksAreNotIdentityTracks() {
        #expect(reference(.gdi, "2\n1 0 4 2048 track01.iso 0\n2 600 0 2352 track02.raw 0\n") == "track01.iso")
        #expect(reference(.gdi, "1\n1 0 0 2352 track01.raw 0\n") == nil)
        #expect(reference(.gdi, "4 0 4 2352 x.bin 0\n") == nil)
    }

    @Test func m3uTakesTheFirstDisc() {
        #expect(reference(.m3u, "#EXTM3U\n\ndiscs/Game (Disc 1).cue\nGame (Disc 2).cue\n") == "Game (Disc 1).cue")
        #expect(reference(.m3u, "# nothing\n") == nil)
    }

    @Test func singleFileImagesAreNotIndexFiles() {
        for name in ["game.iso", "game.chd", "game.bin", "game.cdi", "game.pbp", "game"] {
            #expect(MultiFileIndexKind(fileName: name) == nil)
        }
    }
}

@Suite("Set identity on disk")
struct MultiFileSetIdentitySourceTests {

    private static let gdi = """
    3
    1 0 4 2352 track01.bin 0
    2 450 0 2352 track02.raw 0
    3 45000 4 2352 track03.bin 0
    """

    /// A scratch folder that removes itself.
    private final class Folder {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SetIdentity-\(UUID().uuidString)", isDirectory: true)

        @discardableResult
        func write(_ path: String, _ text: String) throws -> URL {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
            return url
        }

        /// A GD-ROM set: the shared track table, a shared low-density track and its own high-density data.
        func gdromSet(in folder: String, data: String) throws -> URL {
            try write("\(folder)/track01.bin", "low density area")
            try write("\(folder)/track02.raw", "audio")
            try write("\(folder)/track03.bin", data)
            return try write("\(folder)/disc.gdi", MultiFileSetIdentitySourceTests.gdi)
        }

        deinit { try? FileManager.default.removeItem(at: root) }
    }

    private func md5(_ url: URL) throws -> String {
        Insecure.MD5.hash(data: try Data(contentsOf: url)).map { String(format: "%02X", $0) }.joined()
    }

    /// What `GameImporterDatabaseService.identityMD5(of:)` stores as md5Hash.
    private func identityMD5(_ source: MultiFileSetIdentity.Source) throws -> String {
        let fileMD5 = try md5(source.file)
        guard source.viaPlaylist else { return fileMD5 }
        let key = MultiFileSetIdentity.playlistKey(firstDiscMD5: fileMD5)
        return Insecure.MD5.hash(data: Data(key.utf8)).map { String(format: "%02X", $0) }.joined()
    }

    @Test func gdiResolvesToItsHighDensityTrack() throws {
        let folder = Folder()
        let index = try folder.gdromSet(in: "Crazy Taxi", data: "CRAZY TAXI IP.BIN")
        let source = try #require(MultiFileSetIdentity.source(forIndexAt: index))
        #expect(source.file.lastPathComponent == "track03.bin")
        #expect(source.viaPlaylist == false)
    }

    @Test func twoGamesWithTheSameGDIGetDifferentIdentities() throws {
        let folder = Folder()
        let first = try folder.gdromSet(in: "Crazy Taxi", data: "CRAZY TAXI IP.BIN")
        let second = try folder.gdromSet(in: "Jet Set Radio", data: "JET SET RADIO IP.BIN")
        // The old identity: the index files are byte-identical.
        #expect(try md5(first) == md5(second))

        let firstSource = try #require(MultiFileSetIdentity.source(forIndexAt: first))
        let secondSource = try #require(MultiFileSetIdentity.source(forIndexAt: second))
        #expect(try identityMD5(firstSource) != identityMD5(secondSource))
        #expect(try identityMD5(firstSource) != md5(first))
    }

    @Test func cueResolvesCaseInsensitivelyAndThroughABackslashPath() throws {
        let folder = Folder()
        try folder.write("Game/GAME (TRACK 1).BIN", "data")
        let cue = try folder.write("Game/Game.cue", "FILE \"sub\\Game (Track 1).bin\" BINARY\n  TRACK 01 MODE2/2352\n")
        let source = try #require(MultiFileSetIdentity.source(forIndexAt: cue))
        // On a case-insensitive volume the index's spelling resolves directly.
        #expect(source.file.lastPathComponent.lowercased() == "game (track 1).bin")
        #expect(FileManager.default.fileExists(atPath: source.file.path))
    }

    @Test func m3uIsIdentifiedByItsFirstDiscsDataTrack() throws {
        let folder = Folder()
        try folder.write("Game/Disc 1.bin", "disc one data")
        try folder.write("Game/Disc 2.bin", "disc two data")
        let disc1 = try folder.write("Game/Disc 1.cue", "FILE \"Disc 1.bin\" BINARY\n  TRACK 01 MODE2/2352\n")
        try folder.write("Game/Disc 2.cue", "FILE \"Disc 2.bin\" BINARY\n  TRACK 01 MODE2/2352\n")
        let m3u = try folder.write("Game/Game.m3u", "Disc 1.cue\nDisc 2.cue\n")

        let source = try #require(MultiFileSetIdentity.source(forIndexAt: m3u))
        #expect(source.file.lastPathComponent == "Disc 1.bin")
        #expect(source.viaPlaylist)
        // The playlist and a stand-alone import of disc 1 stay two games.
        let discSource = try #require(MultiFileSetIdentity.source(forIndexAt: disc1))
        #expect(try identityMD5(source) != identityMD5(discSource))
        #expect(MultiFileSetIdentity.playlistKey(firstDiscMD5: "abc") == "m3u:ABC")
    }

    @Test func m3uOfSingleFileDiscsUsesTheFirstDisc() throws {
        let folder = Folder()
        try folder.write("Game/Game (Disc 1).chd", "chd one")
        let m3u = try folder.write("Game/Game.m3u", "Game (Disc 1).chd\nGame (Disc 2).chd\n")
        let source = try #require(MultiFileSetIdentity.source(forIndexAt: m3u))
        #expect(source.file.lastPathComponent == "Game (Disc 1).chd")
        #expect(source.viaPlaylist)
    }

    @Test func unresolvableSetsAndOtherFilesHaveNoSource() throws {
        let folder = Folder()
        // A missing data track: the importer keeps the index MD5, as before.
        let missing = try folder.write("Missing/disc.gdi", MultiFileSetIdentitySourceTests.gdi)
        #expect(MultiFileSetIdentity.source(forIndexAt: missing) == nil)
        // A playlist of playlists is not followed.
        try folder.write("Nested/inner.m3u", "disc.chd\n")
        try folder.write("Nested/disc.chd", "x")
        let nested = try folder.write("Nested/outer.m3u", "inner.m3u\n")
        #expect(MultiFileSetIdentity.source(forIndexAt: nested) == nil)
        // A single-file image keeps its own MD5.
        let iso = try folder.write("game.iso", "iso")
        #expect(MultiFileSetIdentity.source(forIndexAt: iso) == nil)
        // A folder named like a track is not a track.
        try FileManager.default.createDirectory(at: folder.root.appendingPathComponent("Dir/track03.bin"), withIntermediateDirectories: true)
        try folder.write("Dir/track01.bin", "x")
        let dirIndex = try folder.write("Dir/disc.gdi", MultiFileSetIdentitySourceTests.gdi)
        #expect(MultiFileSetIdentity.source(forIndexAt: dirIndex) == nil)
    }
}

@Suite("Set duplicate check")
struct MultiFileSetDuplicateTests {

    private typealias Fingerprint = MultiFileSetIdentity.Fingerprint

    private static let incoming = Fingerprint(file: URL(fileURLWithPath: "/ROMs/dc/B/track03.bin"), size: 1_000)

    /// Calls the decision and reports whether the existing game's track was hashed.
    private func decide(_ match: MultiFileSetIdentity.Match,
                        existing: Fingerprint?,
                        existingMD5: String?) async -> (same: Bool, hashed: Bool) {
        var hashed = false
        let same = await MultiFileSetIdentity.isSameGame(
            match: match, existing: existing, incoming: Self.incoming, incomingMD5: "BBBB",
            existingMD5: {
                hashed = true
                return existingMD5
            })
        return (same, hashed)
    }

    @Test func anIdentityMatchIsTheSameGame() async {
        let result = await decide(.identity, existing: Fingerprint(file: URL(fileURLWithPath: "/a"), size: 1), existingMD5: "AAAA")
        #expect(result.same)
        #expect(!result.hashed)
    }

    @Test func aLegacyGameWithTheSameIndexButOtherDataIsANewGame() async {
        // Same size, different data: hashed, then told apart.
        let sameSize = await decide(.legacyIndex,
                                    existing: Fingerprint(file: URL(fileURLWithPath: "/ROMs/dc/A/track03.bin"), size: 1_000),
                                    existingMD5: "AAAA")
        #expect(!sameSize.same)
        #expect(sameSize.hashed)
        // Different size: told apart without reading the track.
        let otherSize = await decide(.legacyIndex,
                                     existing: Fingerprint(file: URL(fileURLWithPath: "/ROMs/dc/A/track03.bin"), size: 2_000),
                                     existingMD5: "AAAA")
        #expect(!otherSize.same)
        #expect(!otherSize.hashed)
    }

    @Test func reimportingALegacyGameIsStillCaught() async {
        // Another copy of the same data.
        let copy = await decide(.legacyIndex,
                                existing: Fingerprint(file: URL(fileURLWithPath: "/ROMs/dc/A/track03.bin"), size: 1_000),
                                existingMD5: "bbbb")
        #expect(copy.same)
        // The existing game's own files.
        let itself = await decide(.legacyIndex, existing: Self.incoming, existingMD5: "AAAA")
        #expect(itself.same)
        #expect(!itself.hashed)
        // Its files can't be read (cloud only, moved): the match stands, as before.
        let unreadable = await decide(.legacyIndex, existing: nil, existingMD5: nil)
        #expect(unreadable.same)
        let hashFails = await decide(.legacyIndex,
                                     existing: Fingerprint(file: URL(fileURLWithPath: "/ROMs/dc/A/track03.bin"), size: nil),
                                     existingMD5: nil)
        #expect(hashFails.same)
    }
}
