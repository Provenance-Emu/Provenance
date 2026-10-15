//
//  MultiFileSetFolderTests.swift
//  PVLibraryTests
//
//  Multi-file games (gdi/cue/m3u and their tracks) import into a folder of their
//  own under the system's ROM folder: naming and de-duplication, placement of two
//  sets with the same track names, the library scan finding games inside set
//  folders, and deleting the folder with its last game.
//

@testable import PVLibrary
import PVFileSystem
import Foundation
import Testing

@Suite("Set folder naming")
struct MultiFileSetFolderNamingTests {

    @Test func baseNameIsTheIndexStemMadeSafe() {
        #expect(MultiFileSetFolder.baseName(forIndexFile: "Crazy Taxi.gdi") == "Crazy Taxi")
        #expect(MultiFileSetFolder.baseName(forIndexFile: "Sonic Adventure 2 (v1.008).gdi") == "Sonic Adventure 2 (v1.008)")
        #expect(MultiFileSetFolder.baseName(forIndexFile: "a/b:c\\d.cue") == "a_b_c_d")
        #expect(MultiFileSetFolder.baseName(forIndexFile: "..hidden.cue") == "hidden")
        #expect(MultiFileSetFolder.baseName(forIndexFile: "Trailing. . .m3u") == "Trailing")
        #expect(MultiFileSetFolder.baseName(forIndexFile: "Tab\there\u{7}.gdi") == "Tabhere")
        #expect(MultiFileSetFolder.baseName(forIndexFile: "....gdi") == MultiFileSetFolder.fallbackName)
        #expect(MultiFileSetFolder.baseName(forIndexFile: ".cue") == "cue")
    }

    @Test func baseNameIsCappedOnACharacterBoundary() {
        let long = String(repeating: "é", count: 200) + ".cue"
        let name = MultiFileSetFolder.baseName(forIndexFile: long)
        #expect(name.utf8.count <= MultiFileSetFolder.maximumNameBytes)
        #expect(name.allSatisfy { $0 == "é" })
    }

    @Test func takenNamesGetANumericSuffix() {
        #expect(MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: []) == "disc")
        #expect(MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: ["Disc"]) == "disc-2")
        #expect(MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: ["disc", "DISC-2", "game.chd"]) == "disc-3")
        // A flat file with no extension takes the name too.
        #expect(MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: ["disc"]) == "disc-2")
    }

    @Test func aFolderHoldingTheSameSetIsReused() {
        let name = MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: ["disc", "disc-2"]) { $0 == "disc-2" }
        #expect(name == "disc-2")
    }

    @Test func takenNamesGetTheIdentitySuffixWhenTheIdentityIsKnown() {
        let md5 = "1a2b3c4d5e6f708192a3b4c5d6e7f809"
        #expect(MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: [], identityMD5: md5) == "disc")
        #expect(MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: ["disc"], identityMD5: md5) == "disc-1A2B3C4D")
        // Import order and legacy -N folders don't change it: two devices name the set the same.
        #expect(MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: ["disc", "disc-2", "disc-3"], identityMD5: md5)
                == "disc-1A2B3C4D")
        // Not an MD5: the legacy numbering.
        #expect(MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: ["disc"], identityMD5: "xyz") == "disc-2")
    }

    @Test func aLegacyNumberedFolderHoldingTheSameSetIsReusedBeforeTheIdentityName() {
        let md5 = "1A2B3C4D5E6F708192A3B4C5D6E7F809"
        let legacy = MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: ["disc", "disc-2"], identityMD5: md5) { $0 == "disc-2" }
        #expect(legacy == "disc-2")
        let identity = MultiFileSetFolder.folderName(
            forIndexFile: "disc.gdi", taken: ["disc", "disc-1A2B3C4D"], identityMD5: md5) { $0 == "disc-1A2B3C4D" }
        #expect(identity == "disc-1A2B3C4D")
    }

    @Test func identityNameTakenByAnotherSetFallsBackToNumbering() {
        let md5 = "1A2B3C4D5E6F708192A3B4C5D6E7F809"
        #expect(MultiFileSetFolder.folderName(forIndexFile: "disc.gdi", taken: ["disc", "disc-1a2b3c4d"], identityMD5: md5) == "disc-2")
    }

    @Test func setFolderNamesMatchTheirIndexFile() {
        #expect(MultiFileSetFolder.isSetFolder(named: "disc", forIndexFile: "disc.gdi"))
        #expect(MultiFileSetFolder.isSetFolder(named: "Disc-12", forIndexFile: "disc.gdi"))
        #expect(MultiFileSetFolder.isSetFolder(named: "disc-1A2B3C4D", forIndexFile: "disc.gdi"))
        #expect(MultiFileSetFolder.isSetFolder(named: "Disc-deadbeef", forIndexFile: "disc.gdi"))
        #expect(!MultiFileSetFolder.isSetFolder(named: "disc-1A2B3C4", forIndexFile: "disc.gdi"))
        #expect(!MultiFileSetFolder.isSetFolder(named: "disc-1A2B3C4DE", forIndexFile: "disc.gdi"))
        #expect(!MultiFileSetFolder.isSetFolder(named: "disc-x", forIndexFile: "disc.gdi"))
        #expect(!MultiFileSetFolder.isSetFolder(named: "DOOM", forIndexFile: "install.cue"))
        #expect(!MultiFileSetFolder.isSetFolder(named: "disc", forIndexFile: "disc.chd"))
    }

    @Test func romLocationReadsTheSystemAndSetFolder() {
        let flat = URL(fileURLWithPath: "/x/Documents/ROMs/com.provenance.dreamcast/game.chd")
        #expect(MultiFileSetFolder.romLocation(of: flat)
                == .init(systemIdentifier: "com.provenance.dreamcast", relativePath: "game.chd", setFolder: nil))
        let set = URL(fileURLWithPath: "/x/Documents/ROMs/com.provenance.dreamcast/disc-2/disc.gdi")
        #expect(MultiFileSetFolder.romLocation(of: set)?.romPath == "com.provenance.dreamcast/disc-2/disc.gdi")
        #expect(MultiFileSetFolder.romLocation(of: set)?.setFolder == "disc-2")
        #expect(MultiFileSetFolder.romLocation(of: URL(fileURLWithPath: "/x/Documents/ROMs/a/b/c/d.bin")) == nil)
        #expect(MultiFileSetFolder.romLocation(of: URL(fileURLWithPath: "/x/Documents/Imports/disc.gdi")) == nil)
    }

    @Test func systemFolderSkipsTheSetFolder() {
        let roms = "/x/Documents/ROMs/com.provenance.dreamcast/"
        #expect(MultiFileSetFolder.systemFolderName(ofFileAt: URL(fileURLWithPath: roms + "game.chd")) == "com.provenance.dreamcast")
        #expect(MultiFileSetFolder.systemFolderName(ofFileAt: URL(fileURLWithPath: roms + "disc-2/disc.gdi")) == "com.provenance.dreamcast")
        #expect(MultiFileSetFolder.systemFolderName(ofFileAt: URL(fileURLWithPath: "/x/Documents/Imports/disc.gdi")) == "Imports")
    }

    @Test func savesFollowTheFolderOnlyForADeduplicatedSet() {
        let roms = "/x/Documents/ROMs/com.provenance.dreamcast/"
        #expect(MultiFileSetFolder.saveName(forROMAt: URL(fileURLWithPath: roms + "Crazy Taxi.gdi")) == "Crazy Taxi")
        #expect(MultiFileSetFolder.saveName(forROMAt: URL(fileURLWithPath: roms + "disc/disc.gdi")) == "disc")
        #expect(MultiFileSetFolder.saveName(forROMAt: URL(fileURLWithPath: roms + "disc-2/disc.gdi")) == "disc-2")
        #expect(MultiFileSetFolder.saveName(forROMAt: URL(fileURLWithPath: roms + "disc-1A2B3C4D/disc.gdi")) == "disc-1A2B3C4D")
        #expect(MultiFileSetFolder.saveName(forROMAt: URL(fileURLWithPath: roms + "DOOM/doom.exe")) == "doom")
    }
}

@Suite("Set folder placement")
struct MultiFileSetPlacementTests {

    private static let system = "com.provenance.dreamcast"

    /// `<tmp>/Imports` and `<tmp>/ROMs/<system>`.
    private struct Library {
        let root: URL
        let imports: URL
        let systemDirectory: URL

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("SetFolder-\(UUID().uuidString)", isDirectory: true)
            imports = root.appendingPathComponent("Imports", isDirectory: true)
            systemDirectory = root.appendingPathComponent("ROMs", isDirectory: true)
                .appendingPathComponent(MultiFileSetPlacementTests.system, isDirectory: true)
            try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: systemDirectory, withIntermediateDirectories: true)
        }

        @discardableResult
        func write(_ name: String, _ text: String, in directory: URL? = nil) throws -> URL {
            let url = (directory ?? imports).appendingPathComponent(name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
            return url
        }

        func read(_ url: URL) -> String? {
            (try? Data(contentsOf: url)).flatMap { String(data: $0, encoding: .utf8) }
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }

    /// The track table of a three-track GDI set whose second track starts at `lba`.
    private static func gdiText(lba: Int) -> String {
        "3\n1 0 4 2352 track01.bin 0\n2 \(lba) 0 2352 track02.raw 0\n3 45000 4 2352 track03.bin 0\n"
    }

    /// The second track's start for a set tagged `tag`, so two sets' .gdi files differ.
    private static func lba(forTag tag: String) -> Int {
        700 + Int(tag.unicodeScalars.first?.value ?? 0)
    }

    /// A three-track GDI set; `tag` goes into every file so two sets differ in content.
    private func writeGDISet(_ library: Library, index: String, tag: String) throws -> (index: URL, tracks: [URL]) {
        let gdi = try library.write(index, Self.gdiText(lba: Self.lba(forTag: tag)))
        let tracks = try ["track01.bin", "track02.raw", "track03.bin"].map { try library.write($0, "\(tag) \($0)") }
        return (gdi, tracks)
    }

    @Test func gdiSetMovesIntoAFolderNamedAfterIt() throws {
        let library = try Library()
        defer { library.remove() }
        let set = try writeGDISet(library, index: "Crazy Taxi.gdi", tag: "A")

        let members = MultiFileSetPlacement.members(ofIndexAt: set.index, among: set.tracks)
        let placement = try MultiFileSetPlacement.place(indexAt: set.index, members: members, in: library.systemDirectory)

        #expect(placement.folder.lastPathComponent == "Crazy Taxi")
        #expect(placement.index.path == library.systemDirectory.appendingPathComponent("Crazy Taxi/Crazy Taxi.gdi").path)
        #expect(placement.members.map(\.lastPathComponent) == ["track01.bin", "track02.raw", "track03.bin"])
        #expect(!placement.reusedExistingFolder)
        #expect(library.read(placement.folder.appendingPathComponent("track01.bin")) == "A track01.bin")
        #expect(!FileManager.default.fileExists(atPath: set.index.path))
        // The index keeps its relative names: nothing to rewrite.
        #expect(library.read(placement.index)?.contains(" track01.bin ") == true)
    }

    @Test func aSecondSetWithTheSameTrackNamesLandsBesideTheFirst() throws {
        let library = try Library()
        defer { library.remove() }
        let first = try writeGDISet(library, index: "Crazy Taxi.gdi", tag: "A")
        let firstPlacement = try MultiFileSetPlacement.place(indexAt: first.index, members: first.tracks, in: library.systemDirectory)

        // Shared after the first one finished importing: same track names, different game.
        let second = try writeGDISet(library, index: "Jet Set Radio.gdi", tag: "B")
        let secondPlacement = try MultiFileSetPlacement.place(indexAt: second.index, members: second.tracks, in: library.systemDirectory)

        #expect(secondPlacement.folder.lastPathComponent == "Jet Set Radio")
        #expect(library.read(firstPlacement.folder.appendingPathComponent("track01.bin")) == "A track01.bin")
        #expect(library.read(secondPlacement.folder.appendingPathComponent("track01.bin")) == "B track01.bin")
        #expect(library.read(secondPlacement.index) == Self.gdiText(lba: Self.lba(forTag: "B")))
    }

    @Test func aDifferentSetWithTheSameIndexNameGetsASuffix() throws {
        let library = try Library()
        defer { library.remove() }
        let first = try writeGDISet(library, index: "disc.gdi", tag: "A")
        _ = try MultiFileSetPlacement.place(indexAt: first.index, members: first.tracks, in: library.systemDirectory)
        let second = try writeGDISet(library, index: "disc.gdi", tag: "B")
        let placement = try MultiFileSetPlacement.place(indexAt: second.index, members: second.tracks, in: library.systemDirectory)

        #expect(placement.folder.lastPathComponent == "disc-2")
        #expect(!placement.reusedExistingFolder)
        #expect(library.read(library.systemDirectory.appendingPathComponent("disc/track01.bin")) == "A track01.bin")
        #expect(library.read(placement.folder.appendingPathComponent("track01.bin")) == "B track01.bin")
    }

    @Test func aDifferentSetWithTheSameIndexNameIsNamedAfterItsIdentity() throws {
        let library = try Library()
        defer { library.remove() }
        let md5 = "C0FFEE00112233445566778899AABBCC"
        let first = try writeGDISet(library, index: "disc.gdi", tag: "A")
        _ = try MultiFileSetPlacement.place(indexAt: first.index, members: first.tracks, in: library.systemDirectory)
        #expect(MultiFileSetPlacement.baseNameIsTaken(forIndexAt: library.imports.appendingPathComponent("disc.gdi"),
                                                      in: library.systemDirectory))
        // A legacy -2 folder from another set doesn't change the name.
        let legacy = try writeGDISet(library, index: "disc.gdi", tag: "L")
        _ = try MultiFileSetPlacement.place(indexAt: legacy.index, members: legacy.tracks, in: library.systemDirectory)

        let second = try writeGDISet(library, index: "disc.gdi", tag: "B")
        let placement = try MultiFileSetPlacement.place(
            indexAt: second.index, members: second.tracks, in: library.systemDirectory, identityMD5: md5)

        #expect(placement.folder.lastPathComponent == "disc-C0FFEE00")
        #expect(library.read(placement.folder.appendingPathComponent("track01.bin")) == "B track01.bin")
        #expect(MultiFileSetPlacement.isSetFolder(placement.folder))
        #expect(MultiFileSetPlacement.indexFilesInSetFolders(of: library.systemDirectory).count == 3)

        // The same set again is found in its folder, not copied into another.
        let again = try writeGDISet(library, index: "disc.gdi", tag: "B")
        let repeated = try MultiFileSetPlacement.place(
            indexAt: again.index, members: again.tracks, in: library.systemDirectory, identityMD5: md5)
        #expect(repeated.folder.lastPathComponent == "disc-C0FFEE00")
        #expect(repeated.reusedExistingFolder)
    }

    @Test func aSetInALegacyNumberedFolderIsReusedNotCopied() throws {
        let library = try Library()
        defer { library.remove() }
        let first = try writeGDISet(library, index: "disc.gdi", tag: "A")
        _ = try MultiFileSetPlacement.place(indexAt: first.index, members: first.tracks, in: library.systemDirectory)
        let second = try writeGDISet(library, index: "disc.gdi", tag: "B")
        _ = try MultiFileSetPlacement.place(indexAt: second.index, members: second.tracks, in: library.systemDirectory)

        let again = try writeGDISet(library, index: "disc.gdi", tag: "B")
        let placement = try MultiFileSetPlacement.place(
            indexAt: again.index, members: again.tracks, in: library.systemDirectory, identityMD5: "C0FFEE00112233445566778899AABBCC")

        #expect(placement.folder.lastPathComponent == "disc-2")
        #expect(placement.reusedExistingFolder)
        #expect(!FileManager.default.fileExists(atPath: library.systemDirectory.appendingPathComponent("disc-C0FFEE00").path))
    }

    @Test func importingTheSameSetAgainReusesItsFolder() throws {
        let library = try Library()
        defer { library.remove() }
        let first = try writeGDISet(library, index: "disc.gdi", tag: "A")
        _ = try MultiFileSetPlacement.place(indexAt: first.index, members: first.tracks, in: library.systemDirectory)
        let again = try writeGDISet(library, index: "disc.gdi", tag: "A")
        let placement = try MultiFileSetPlacement.place(indexAt: again.index, members: again.tracks, in: library.systemDirectory)

        #expect(placement.folder.lastPathComponent == "disc")
        #expect(placement.reusedExistingFolder)
        #expect(!FileManager.default.fileExists(atPath: library.systemDirectory.appendingPathComponent("disc-2").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: library.imports.path).isEmpty)
    }

    @Test func anEmptyFolderLeftBehindIsReused() throws {
        let library = try Library()
        defer { library.remove() }
        try FileManager.default.createDirectory(
            at: library.systemDirectory.appendingPathComponent("disc", isDirectory: true), withIntermediateDirectories: true)
        let set = try writeGDISet(library, index: "disc.gdi", tag: "A")
        let placement = try MultiFileSetPlacement.place(indexAt: set.index, members: set.tracks, in: library.systemDirectory)

        #expect(placement.folder.lastPathComponent == "disc")
        #expect(library.read(placement.folder.appendingPathComponent("track03.bin")) == "A track03.bin")
    }

    @Test func onlyFilesTheIndexListsAreMembers() throws {
        let library = try Library()
        defer { library.remove() }
        let set = try writeGDISet(library, index: "Crazy Taxi.gdi", tag: "A")
        let unrelated = try library.write("Other Game (Disc 1).bin", "other")

        let members = MultiFileSetPlacement.members(ofIndexAt: set.index, among: set.tracks + [unrelated])
        #expect(members == set.tracks)
    }

    @Test func aCueKeepsItsSBIBesideIt() throws {
        let library = try Library()
        defer { library.remove() }
        let cue = try library.write("Ape Escape.cue", "FILE \"Ape Escape.bin\" BINARY\n  TRACK 01 MODE2/2352\n")
        let bin = try library.write("Ape Escape.bin", "bin")
        let sbi = try library.write("Ape Escape.sbi", "sbi")
        let otherDisc = try library.write("Ape Escape (Bonus).cue", "FILE \"Ape Escape (Bonus).bin\" BINARY\n")

        let members = MultiFileSetPlacement.members(ofIndexAt: cue, among: [bin, sbi, otherDisc])
        #expect(members == [bin, sbi])
        let placement = try MultiFileSetPlacement.place(indexAt: cue, members: members, in: library.systemDirectory)
        #expect(FileManager.default.fileExists(atPath: placement.folder.appendingPathComponent("Ape Escape.sbi").path))
    }

    @Test func m3uMembersIncludeEveryDiscAndItsTracks() throws {
        let library = try Library()
        defer { library.remove() }
        let m3u = try library.write("Final Fantasy VII.m3u", "#EXTM3U\nFF7 (Disc 1).cue\nFF7 (Disc 2).cue\n")
        let cue1 = try library.write("FF7 (Disc 1).cue", "FILE \"FF7 (Disc 1).bin\" BINARY\n  TRACK 01 MODE2/2352\n")
        let bin1 = try library.write("FF7 (Disc 1).bin", "d1")
        let cue2 = try library.write("FF7 (Disc 2).cue", "FILE \"FF7 (Disc 2).bin\" BINARY\n  TRACK 01 MODE2/2352\n")
        let bin2 = try library.write("FF7 (Disc 2).bin", "d2")

        let members = MultiFileSetPlacement.members(ofIndexAt: m3u, among: [cue1, bin1, cue2, bin2])
        #expect(Set(members) == Set([cue1, bin1, cue2, bin2]))

        let placement = try MultiFileSetPlacement.place(indexAt: m3u, members: members, in: library.systemDirectory)
        #expect(placement.folder.lastPathComponent == "Final Fantasy VII")
        #expect(MultiFileSetPlacement.outermostIndexFiles(in: placement.folder).map(\.lastPathComponent) == ["Final Fantasy VII.m3u"])
    }

    @Test func aSingleFileGameIsNotASetAndStaysFlat() throws {
        let library = try Library()
        defer { library.remove() }
        let chd = try library.write("Shenmue.chd", "chd")
        let emptyCue = try library.write("Empty.cue", "REM nothing here\n")
        let cue = try library.write("Game.cue", "FILE \"Game.bin\" BINARY\n")

        #expect(!MultiFileSetPlacement.isMultiFileSet(indexAt: chd))
        #expect(!MultiFileSetPlacement.isMultiFileSet(indexAt: emptyCue))
        #expect(MultiFileSetPlacement.isMultiFileSet(indexAt: cue))
        #expect(MultiFileSetPlacement.setFolder(ofGameFileAt: library.systemDirectory.appendingPathComponent("Shenmue.chd")) == nil)
    }

    @Test func libraryScanFindsGamesInsideSetFolders() throws {
        let library = try Library()
        defer { library.remove() }
        let dir = library.systemDirectory
        try library.write("Flat.cue", "FILE \"Flat.bin\" BINARY\n", in: dir)
        try library.write("Crazy Taxi/Crazy Taxi.gdi", "1\n1 0 4 2352 track01.bin 0\n", in: dir)
        try library.write("Crazy Taxi/track01.bin", "t", in: dir)
        try library.write("disc-2/disc.gdi", "1\n1 0 4 2352 track01.bin 0\n", in: dir)
        try library.write("Final Fantasy VII/Final Fantasy VII.m3u", "FF7 (Disc 1).cue\n", in: dir)
        try library.write("Final Fantasy VII/FF7 (Disc 1).cue", "FILE \"FF7 (Disc 1).bin\" BINARY\n", in: dir)
        // Not set folders: a DOS game with a CD image, a NAOMI GD-ROM folder, a hidden folder.
        try library.write("DOOM/install.cue", "FILE \"install.bin\" BINARY\n", in: dir)
        try library.write("ikaruga/gdl-0010.chd", "chd", in: dir)
        try library.write(".hidden/.hidden.gdi", "1\n1 0 4 2352 track01.bin 0\n", in: dir)

        let found = MultiFileSetPlacement.indexFilesInSetFolders(of: dir).map {
            MultiFileSetFolder.romLocation(of: $0)?.relativePath
        }
        #expect(found == ["Crazy Taxi/Crazy Taxi.gdi", "disc-2/disc.gdi", "Final Fantasy VII/Final Fantasy VII.m3u"])
    }

    @Test func deletingTheLastGameRemovesItsSetFolder() throws {
        let library = try Library()
        defer { library.remove() }
        let set = try writeGDISet(library, index: "Crazy Taxi.gdi", tag: "A")
        let placement = try MultiFileSetPlacement.place(indexAt: set.index, members: set.tracks, in: library.systemDirectory)
        let flat = try library.write("Shenmue.chd", "chd", in: library.systemDirectory)

        // Looked up before the game's own files are deleted, as RomDatabase.delete(game:) does.
        let folder = try #require(MultiFileSetPlacement.setFolder(ofGameFileAt: placement.index))
        #expect(folder.standardizedFileURL == placement.folder.standardizedFileURL)
        try FileManager.default.removeItem(at: placement.index)

        var askedPrefix: String?
        let removedWhileInUse = MultiFileSetPlacement.removeSetFolderIfUnused(folder) { prefix in
            askedPrefix = prefix
            return true
        }
        #expect(!removedWhileInUse)
        #expect(askedPrefix == "\(Self.system)/Crazy Taxi/")
        #expect(FileManager.default.fileExists(atPath: placement.folder.path))

        #expect(MultiFileSetPlacement.removeSetFolderIfUnused(folder) { _ in false })
        #expect(!FileManager.default.fileExists(atPath: placement.folder.path))
        // A flat game has no set folder; the system folder and the flat file are never removed.
        #expect(MultiFileSetPlacement.setFolder(ofGameFileAt: flat) == nil)
        #expect(!MultiFileSetPlacement.removeSetFolderIfUnused(flat) { _ in false })
        #expect(!MultiFileSetPlacement.removeSetFolderIfUnused(library.systemDirectory) { _ in false })
        #expect(FileManager.default.fileExists(atPath: flat.path))
    }
}
