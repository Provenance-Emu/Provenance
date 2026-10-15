//
//  MultiFileSetArrivalsTests.swift
//  PVLibraryTests
//
//  iCloud Drive mode downloads a library one file at a time. A disc set is
//  imported as soon as its last file lands (track or index), never before, and
//  each folder is grouped on its own. A file is "downloaded" here once it is
//  written; `pending` lists the ones iCloud still has to download.
//

@testable import PVLibrary
import Foundation
import Testing

@Suite("Disc set arrivals")
struct MultiFileSetArrivalsTests {

    private static let gdiText = "3\n1 0 4 2352 track01.bin 0\n2 756 0 2352 track02.raw 0\n3 45000 4 2352 track03.bin 0\n"
    private static let gdiTracks = ["track01.bin", "track02.raw", "track03.bin"]

    /// `<tmp>/ROMs/<system>`.
    private struct Library {
        let root: URL
        let system: URL

        init(system name: String = "com.provenance.dreamcast") throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("SetArrivals-\(UUID().uuidString)", isDirectory: true)
            system = root.appendingPathComponent("ROMs", isDirectory: true).appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: system, withIntermediateDirectories: true)
        }

        func url(_ path: String) -> URL {
            system.appendingPathComponent(path)
        }

        /// Downloads `path`: the file now exists at its real path.
        @discardableResult
        func download(_ path: String, _ text: String = "data") throws -> URL {
            let url = url(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
            return url
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }

    private func names(_ batches: [[URL]]) -> [[String]] {
        batches.map { $0.map(\.lastPathComponent) }
    }

    @Test func aGDISetWaitsForItsLastTrackThenImportsTogether() throws {
        let library = try Library()
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()
        var pending = Set(Self.gdiTracks.map { library.url("Crazy Taxi/\($0)") })

        let gdi = try library.download("Crazy Taxi/Crazy Taxi.gdi", Self.gdiText)
        #expect(arrivals.arrived(gdi, pending: pending).isEmpty)
        for track in Self.gdiTracks.dropLast() {
            let url = try library.download("Crazy Taxi/\(track)")
            pending.remove(url)
            #expect(arrivals.arrived(url, pending: pending).isEmpty)
        }
        let last = try library.download("Crazy Taxi/track03.bin")
        pending.remove(last)
        let released = arrivals.arrived(last, pending: pending)

        #expect(names(released) == [["Crazy Taxi.gdi", "track01.bin", "track02.raw", "track03.bin"]])
        #expect(arrivals.heldCount == 0)
    }

    @Test func tracksThatArriveFirstWaitForTheirIndex() throws {
        let library = try Library(system: "com.provenance.psx")
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()
        let cueURL = library.url("Game (USA).cue")

        let bin = try library.download("Game (USA).bin")
        #expect(arrivals.arrived(bin, pending: [cueURL]).isEmpty)
        let cue = try library.download("Game (USA).cue", "FILE \"Game (USA).bin\" BINARY\n  TRACK 01 MODE2/2352\n")

        #expect(names(arrivals.arrived(cue, pending: [])) == [["Game (USA).cue", "Game (USA).bin"]])
    }

    @Test func aTrackIsHeldEvenBeforeItsIndexIsKnown() throws {
        let library = try Library(system: "com.provenance.psx")
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()

        // The query reported the track before it listed the cue.
        let bin = try library.download("Game.bin")
        #expect(arrivals.arrived(bin, pending: []).isEmpty)
        let cue = try library.download("Game.cue", "FILE \"Game.bin\" BINARY\n  TRACK 01 MODE1/2352\n")
        #expect(names(arrivals.arrived(cue, pending: [])) == [["Game.cue", "Game.bin"]])
    }

    @Test func twoSetsWithTheSameTrackNamesAreGroupedByFolder() throws {
        let library = try Library()
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()
        let pending = Set(["disc", "disc-1A2B3C4D"].flatMap { folder in Self.gdiTracks.map { library.url("\(folder)/\($0)") } })

        let first = try library.download("disc/disc.gdi", Self.gdiText)
        let second = try library.download("disc-1A2B3C4D/disc.gdi", Self.gdiText)
        #expect(arrivals.arrived(first, pending: pending).isEmpty)
        #expect(arrivals.arrived(second, pending: pending).isEmpty)

        var remaining = pending
        var released: [[URL]] = []
        for track in Self.gdiTracks {
            let url = try library.download("disc-1A2B3C4D/\(track)")
            remaining.remove(url)
            released += arrivals.arrived(url, pending: remaining)
        }
        // The second set is complete; the first still waits for its own tracks.
        #expect(released.count == 1)
        #expect(released.first?.allSatisfy { $0.deletingLastPathComponent().lastPathComponent == "disc-1A2B3C4D" } == true)
        #expect(arrivals.heldCount == 1)
    }

    @Test func aSingleFileGameIsReleasedAtOnce() throws {
        let library = try Library()
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()
        let chd = try library.download("Crazy Taxi.chd")

        #expect(names(arrivals.arrived(chd, pending: [library.url("Other.chd")])) == [["Crazy Taxi.chd"]])
    }

    @Test func aFileBesideAnIndexStillDownloadingIsHeld() throws {
        let library = try Library(system: "com.provenance.psx")
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()
        let iso = try library.download("Game.iso")

        #expect(arrivals.arrived(iso, pending: [library.url("Game.cue")]).isEmpty)
        #expect(names(arrivals.flush()) == [["Game.iso"]])
    }

    @Test func aPlaylistWaitsForEveryDiscAndItsTracks() throws {
        let library = try Library(system: "com.provenance.psx")
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()
        let disc1 = "FILE \"Game (Disc 1).bin\" BINARY\n  TRACK 01 MODE2/2352\n"
        let disc2 = "FILE \"Game (Disc 2).bin\" BINARY\n  TRACK 01 MODE2/2352\n"
        var pending = Set(["Game (Disc 1).cue", "Game (Disc 1).bin", "Game (Disc 2).cue", "Game (Disc 2).bin"].map { library.url("Game/\($0)") })

        let m3u = try library.download("Game/Game.m3u", "Game (Disc 1).cue\nGame (Disc 2).cue\n")
        #expect(arrivals.arrived(m3u, pending: pending).isEmpty)
        for (name, text) in [("Game (Disc 1).cue", disc1), ("Game (Disc 1).bin", "1"), ("Game (Disc 2).cue", disc2)] {
            let url = try library.download("Game/\(name)", text)
            pending.remove(url)
            #expect(arrivals.arrived(url, pending: pending).isEmpty, "\(name) must not import before the whole playlist")
        }
        let last = try library.download("Game/Game (Disc 2).bin", "2")
        pending.remove(last)
        let released = names(arrivals.arrived(last, pending: pending))

        #expect(released.count == 1)
        #expect(released.first?.first == "Game.m3u")
        #expect(Set(released.first ?? []) == ["Game.m3u", "Game (Disc 1).cue", "Game (Disc 1).bin", "Game (Disc 2).cue", "Game (Disc 2).bin"])
    }

    @Test func flushReleasesWhatIsStillHeldPerFolder() throws {
        let library = try Library()
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()
        // A set missing a track for good, and a lone .bin game in another system folder.
        let gdi = try library.download("disc/disc.gdi", Self.gdiText)
        let track = try library.download("disc/track01.bin")
        _ = arrivals.arrived(gdi, pending: [library.url("disc/track02.raw")])
        _ = arrivals.arrived(track, pending: [library.url("disc/track02.raw")])
        let lone = try library.download("Lone.bin")
        _ = arrivals.arrived(lone, pending: [])

        let flushed = names(arrivals.flush())
        #expect(flushed.contains(["Lone.bin"]))
        #expect(flushed.contains(["disc.gdi", "track01.bin"]))
        #expect(arrivals.heldCount == 0)
    }

    @Test func aTrackOfASetAlreadyInTheLibraryIsDropped() throws {
        let library = try Library()
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()
        let gdi = try library.download("disc/disc.gdi", Self.gdiText)
        let track = try library.download("disc/track01.bin")

        #expect(arrivals.arrived(track, pending: [], importedIndexes: [gdi]).isEmpty)
        #expect(arrivals.heldCount == 0)
    }

    @Test func onlyAFolderNamedAfterItsIndexIsASetFolder() throws {
        let library = try Library()
        defer { library.remove() }
        // A set folder whose index is still downloading: its track is held for it.
        let track = try library.download("Crazy Taxi/track01.bin")
        let pendingIndex: Set<URL> = [library.url("Crazy Taxi/Crazy Taxi.gdi")]
        #expect(MultiFileSetArrivals.isInSetFolder(track, pending: pendingIndex))
        #expect(MultiFileSetArrivals.isInSetFolder(library.url("Crazy Taxi/Crazy Taxi.gdi"), pending: []))
        #expect(MultiFileSetArrivals.isInSetFolder(library.url("disc-1A2B3C4D/disc.gdi"), pending: []))
        var arrivals = MultiFileSetArrivals()
        #expect(arrivals.arrived(track, pending: pendingIndex).isEmpty)
        #expect(arrivals.heldCount == 1)

        // A NAOMI GD-ROM folder beside its zip, a DOS game folder: not set folders.
        let chd = try library.download("ikaruga/gdl-0010.chd")
        #expect(!MultiFileSetArrivals.isInSetFolder(chd, pending: []))
        let dosLibrary = try Library(system: "com.provenance.dos")
        defer { dosLibrary.remove() }
        try dosLibrary.download("DOOM/install.cue", "FILE \"doom.bin\" BINARY\n  TRACK 01 MODE1/2048\n")
        let exe = try dosLibrary.download("DOOM/doom.exe")
        #expect(!MultiFileSetArrivals.isInSetFolder(exe, pending: []))
        // A flat file is not in a set folder.
        #expect(!MultiFileSetArrivals.isInSetFolder(library.url("Crazy Taxi.chd"), pending: []))
    }

    @Test func tracksHeldForAGameAlreadyInTheLibraryAreDiscarded() throws {
        let library = try Library()
        defer { library.remove() }
        var arrivals = MultiFileSetArrivals()
        let pendingIndex: Set<URL> = [library.url("disc/disc.gdi")]
        for track in Self.gdiTracks {
            #expect(arrivals.arrived(try library.download("disc/\(track)"), pending: pendingIndex).isEmpty)
        }
        let gdi = try library.download("disc/disc.gdi", Self.gdiText)

        // The syncer found disc.gdi's game in the library and skipped it.
        arrivals.discardMembers(ofIndexAt: gdi)
        #expect(arrivals.heldCount == 0)
        #expect(arrivals.flush().isEmpty)
    }

    @Test func queueHandsSingleFilesBackAndKeepsSetsForLater() async throws {
        let library = try Library(system: "com.provenance.psx")
        defer { library.remove() }
        let queue = MultiFileSetArrivalQueue()
        let chd = try library.download("Other.chd")
        #expect(await queue.arrived(chd, pending: [], importedIndexes: []) == [chd])

        let bin = try library.download("Game.bin")
        #expect(await queue.arrived(bin, pending: [], importedIndexes: []).isEmpty)
        let cue = try library.download("Game.cue", "FILE \"Game.bin\" BINARY\n  TRACK 01 MODE1/2352\n")
        #expect(await queue.arrived(cue, pending: [], importedIndexes: []).isEmpty)

        #expect(await queue.hasReadySets)
        #expect(await queue.count == 2)
        #expect(await queue.nextSet()?.map(\.lastPathComponent) == ["Game.cue", "Game.bin"])
        #expect(await queue.nextSet() == nil)
    }
}
