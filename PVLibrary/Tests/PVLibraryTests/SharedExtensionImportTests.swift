//
//  SharedExtensionImportTests.swift
//  PVLibrary
//
//  Cue/bin association coverage: what rescues a `.bin` from being ambiguous.
//
//  A bare `.bin` on disk is claimed by 13 different systems, so the importer has
//  to guess. A `.bin` referenced by a `.cue`, by contrast, is unambiguous — it
//  belongs to that disc. These tests pin that absorption behaviour.
//
//  The pure systems.plist contract tests (which extensions are claimed by which
//  systems) deliberately live in PVPrimitives instead —
//  PVPrimitives/Tests/PVPrimitivesTests/SharedExtensionSystemMappingTests.swift —
//  because PVPrimitives builds and tests standalone via `swift test`, whereas
//  PVLibrary's test target currently cannot be run at all (missing PVLogging
//  product / Realm static-dynamic conflict in package mode, and the workspace
//  scheme has no test action).
//

@testable import PVLibrary
import PVPrimitives
import XCTest

final class SharedExtensionImportTests: XCTestCase {

    private func makeImporter(_ handler: GameImporterTests.MockCDFileHandler) -> GameImporter {
        GameImporter(FileManager.default,
                     GameImporterFileService(),
                     GameImporterDatabaseService(),
                     GameImporterSystemsService(),
                     ArtworkImporter(),
                     handler)
    }

    /// Builds a cue item with `systems` already populated. organizeCueAndBinFiles
    /// only consults `PVSystem.all` (Realm) when `systems` is empty, so presetting
    /// it keeps these tests pure — no database required.
    private func makeCueItem(url: URL) -> ImportQueueItem {
        let item = ImportQueueItem(url: url)
        item.systems = [.PSX]
        return item
    }

    /// A multi-track disc: the .cue names two .bin tracks and both are present.
    /// The cue must end up `.queued` with both tracks resolved, and neither .bin
    /// may survive as an independent queue item.
    func testMultiTrackCueAbsorbsAllBinTracks() {
        let handler = GameImporterTests.MockCDFileHandler()
        let importer = makeImporter(handler)

        let directory = URL(fileURLWithPath: "/path/to")
        let cueURL = directory.appendingPathComponent("Game (Track 1).cue")
        let track1 = directory.appendingPathComponent("Game (Track 1).bin")
        let track2 = directory.appendingPathComponent("Game (Track 2).bin")

        handler.binFilesResult = [track1.lastPathComponent, track2.lastPathComponent]
        handler.binUrlsResult = [track1, track2]
        handler.binFileExistsResult = [track1: true, track2: true]

        var queue = [makeCueItem(url: cueURL),
                     ImportQueueItem(url: track1),
                     ImportQueueItem(url: track2)]
        importer.organizeCueAndBinFiles(in: &queue)

        let cueItems = queue.filter { $0.url.pathExtension.lowercased() == "cue" }
        XCTAssertEqual(cueItems.count, 1, "Expected exactly one .cue item to remain at top level")

        guard let cue = cueItems.first else { return }
        XCTAssertEqual(cue.status, .queued,
                       "All referenced .bin tracks exist, so the cue should be .queued, not .partial")
        XCTAssertEqual(cue.fileType, .cdRom, "A .cue always implies a CD-ROM import")
        XCTAssertEqual(Set(cue.resolvedAssociatedFileURLs), Set([track1, track2]),
                       "Both .bin tracks should be resolved onto the .cue item")

        let topLevelBins = queue.filter { $0.url.pathExtension.lowercased() == "bin" }
        XCTAssertTrue(topLevelBins.isEmpty,
                      "Cue-referenced .bin tracks must not remain as standalone queue items — "
                      + "a loose .bin is ambiguous across 13 systems.")
    }

    /// If even one referenced track is missing the cue must go .partial and wait,
    /// rather than importing a half disc.
    func testCueGoesPartialWhenOneTrackMissing() {
        let handler = GameImporterTests.MockCDFileHandler()
        let importer = makeImporter(handler)

        let directory = URL(fileURLWithPath: "/path/to")
        let cueURL = directory.appendingPathComponent("Game.cue")
        let present = directory.appendingPathComponent("Game (Track 1).bin")
        let missing = directory.appendingPathComponent("Game (Track 2).bin")

        handler.binFilesResult = [present.lastPathComponent, missing.lastPathComponent]
        handler.binUrlsResult = [present]
        handler.binFileExistsResult = [present: true, missing: false]

        var queue = [makeCueItem(url: cueURL), ImportQueueItem(url: present)]
        importer.organizeCueAndBinFiles(in: &queue)

        guard let cue = queue.first(where: { $0.url.pathExtension.lowercased() == "cue" }) else {
            return XCTFail("The .cue item should still be in the queue")
        }
        XCTAssertEqual(cue.status, .partial,
                       "A cue missing one of its .bin tracks must be .partial, not imported")
        XCTAssertEqual(cue.expectedAssociatedFileNames, [missing.lastPathComponent.lowercased()],
                       "The missing track should be recorded so a later arrival can complete the cue")
    }
}
