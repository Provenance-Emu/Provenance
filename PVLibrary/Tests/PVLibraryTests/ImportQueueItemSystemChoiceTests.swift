import Foundation
import XCTest
import PVSystems
@testable import PVLibrary

/// A file detection cannot identify must still import once the user names its system.
final class ImportQueueItemSystemChoiceTests: XCTestCase {
    private func makeItem(chosen: SystemIdentifier?) -> ImportQueueItem {
        let item = ImportQueueItem(url: URL(fileURLWithPath: "/tmp/Homebrew.bin"), fileType: .game)
        item.userChosenSystem = chosen
        return item
    }

    func testWithoutAChoiceDetectionIsUnchanged() {
        let item = makeItem(chosen: nil)
        XCTAssertEqual(item.systems(applyingUserChoiceTo: []), [])
        XCTAssertEqual(item.systems(applyingUserChoiceTo: [.SNES, .N64]), [.SNES, .N64])
    }

    func testChoiceStandsInWhenDetectionFindsNothing() {
        let item = makeItem(chosen: .AtariJaguarCD)
        XCTAssertEqual(item.systems(applyingUserChoiceTo: []), [.AtariJaguarCD])
    }

    func testChoiceAmongDetectedCandidatesKeepsThemAllForConflictResolution() {
        let item = makeItem(chosen: .AtariJaguar)
        XCTAssertEqual(item.systems(applyingUserChoiceTo: [.AtariJaguar, .AtariJaguarCD]), [.AtariJaguar, .AtariJaguarCD])
    }

    func testChoiceOutsideDetectedCandidatesOverridesThem() {
        let item = makeItem(chosen: .DOS)
        XCTAssertEqual(item.systems(applyingUserChoiceTo: [.AtariJaguar, .AtariJaguarCD]), [.DOS])
    }

    func testOverriddenSystemsMakeTheChoiceTheTarget() {
        let item = makeItem(chosen: .DOS)
        item.systems = item.systems(applyingUserChoiceTo: [])
        XCTAssertEqual(item.targetSystem(), .DOS)
    }

    func testExtensionlessROMWithManualChoiceReachesGameMove() async {
        let item = await processExtensionlessROM(detectionError: .noSystemMatched)
        guard case .failure(let error) = item.status else {
            return XCTFail("Expected the test mover to stop the import")
        }
        XCTAssertTrue(error is MoveProbe.ReachedGameMove)
    }

    func testManualChoicePreservesDetectionErrors() async {
        let item = await processExtensionlessROM(detectionError: .couldNotCalculateMD5)
        guard case .failure(let error) = item.status else {
            return XCTFail("Expected the original detection error")
        }
        XCTAssertEqual((error as? GameImporterError)?.errorCode, GameImporterError.couldNotCalculateMD5.errorCode)
    }

    private func processExtensionlessROM(detectionError: GameImporterError) async -> ImportQueueItem {
        let importer = GameImporter(FileManager.default,
                                    MoveProbe(),
                                    GameImporterDatabaseService(),
                                    FailingDetection(error: detectionError),
                                    ArtworkImporter(),
                                    DefaultCDFileHandler())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let item = ImportQueueItem(url: url, fileType: .unknown)
        item.userChosenSystem = .SNES
        await importer.processItem(item)
        return item
    }

    private final class FailingDetection: GameImporterSystemsService {
        let error: GameImporterError

        init(error: GameImporterError) {
            self.error = error
            super.init()
        }

        override func determineSystems(for item: ImportQueueItem) async throws -> [SystemIdentifier] {
            throw error
        }
    }

    private struct MoveProbe: GameImporterFileServicing {
        struct ReachedGameMove: Error {}

        func moveImportItem(toAppropriateSubfolder item: ImportQueueItem) async throws {
            guard item.fileType == .game, item.targetSystem() == .SNES else {
                throw GameImporterError.unsupportedFile
            }
            throw ReachedGameMove()
        }

        func moveToConflictsFolder(_ item: ImportQueueItem, conflictsPath: URL) async throws {}

        func removeImportItemFile(_ item: ImportQueueItem) throws {}
    }
}
