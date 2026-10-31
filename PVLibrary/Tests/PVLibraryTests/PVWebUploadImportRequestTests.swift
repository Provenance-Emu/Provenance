import Foundation
import XCTest
@testable import PVLibrary

final class PVWebUploadImportRequestTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/tmp/upload-library/ROMs", isDirectory: true)
    private let extensions = ["com.provenance.mame": Set(["zip", "chd"])]

    func testTargetsSystemWithoutExtractingItsZIP() throws {
        let url = root.appendingPathComponent("com.provenance.mame/blitz.ZIP")
        let request = try XCTUnwrap(PVWebUploadImportRequest.resolve(fileURL: url, romsRoot: root, extensionsBySystem: extensions))
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.systemIdentifier, "com.provenance.mame")
    }

    func testLeavesArcadeCompanionsInTheirUploadedFolders() {
        let systems = extensions.merging(["com.provenance.dreamcast": Set(["chd"])]) { first, _ in first }
        for path in ["com.provenance.mame/blitz/blitz.chd", "com.provenance.dreamcast/ikaruga/gdl-0010.chd",
                     "com.provenance.dreamcast/ikaruga/GDS-0005A.CHD"] {
            XCTAssertNil(PVWebUploadImportRequest.resolve(fileURL: root.appendingPathComponent(path), romsRoot: root, extensionsBySystem: systems))
        }
    }

    func testAcceptsStandaloneDreamcastCHDInSystemDirectory() throws {
        let url = root.appendingPathComponent("com.provenance.dreamcast/Sonic Adventure.chd")
        let systems = ["com.provenance.dreamcast": Set(["chd"])]
        let request = try XCTUnwrap(PVWebUploadImportRequest.resolve(fileURL: url, romsRoot: root, extensionsBySystem: systems))
        XCTAssertEqual(request.url, url)
    }

    func testAcceptsFilesInRecognizedDiscSetFolder() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let roms = temporary.appendingPathComponent("ROMs")
        let folder = roms.appendingPathComponent("com.provenance.dreamcast/Disc")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "1\n1 0 4 2352 track01.bin 0\n".write(to: folder.appendingPathComponent("Disc.gdi"), atomically: true, encoding: .utf8)
        let systems = ["com.provenance.dreamcast": Set(["gdi", "bin"])]
        for name in ["Disc.gdi", "track01.bin"] {
            let url = folder.appendingPathComponent(name)
            XCTAssertNotNil(PVWebUploadImportRequest.resolve(fileURL: url, romsRoot: roms, extensionsBySystem: systems))
        }
    }

    func testRejectsNestedStandaloneFilesWithoutPreservedSetLayout() {
        let url = root.appendingPathComponent("com.provenance.mame/extra/deeper/game.zip")
        XCTAssertNil(PVWebUploadImportRequest.resolve(fileURL: url, romsRoot: root, extensionsBySystem: extensions))
    }

    func testRejectsOtherLibraryLocationsAndSiblingPrefix() {
        for path in ["/tmp/upload-library/Imports/blitz.zip", "/tmp/upload-library/BIOS/blitz.zip",
                     "/tmp/upload-library/ROMs-other/com.provenance.mame/blitz.zip",
                     "/tmp/other-library/ROMs/com.provenance.mame/blitz.zip"] {
            XCTAssertNil(PVWebUploadImportRequest.resolve(fileURL: URL(fileURLWithPath: path), romsRoot: root, extensionsBySystem: extensions))
        }
    }

    func testRejectsUnknownSystemsUnsupportedExtensionsAndHiddenFiles() {
        for path in ["unknown/blitz.zip", "com.provenance.mame/readme.txt", "com.provenance.mame/.partial.zip", "blitz.zip"] {
            XCTAssertNil(PVWebUploadImportRequest.resolve(fileURL: root.appendingPathComponent(path), romsRoot: root, extensionsBySystem: extensions))
        }
    }

    func testRejectsTraversalOutsideROMRoot() {
        let url = root.appendingPathComponent("com.provenance.mame/../../Imports/blitz.zip")
        XCTAssertNil(PVWebUploadImportRequest.resolve(fileURL: url, romsRoot: root, extensionsBySystem: extensions))
    }

    func testRejectsSymlinkOutsideROMRoot() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let roms = temporary.appendingPathComponent("ROMs")
        let system = roms.appendingPathComponent("com.provenance.mame")
        let outside = temporary.appendingPathComponent("outside.zip")
        try FileManager.default.createDirectory(at: system, withIntermediateDirectories: true)
        try Data([1]).write(to: outside)
        let link = system.appendingPathComponent("blitz.zip")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertNil(PVWebUploadImportRequest.resolve(fileURL: link, romsRoot: roms, extensionsBySystem: extensions))
    }
}
