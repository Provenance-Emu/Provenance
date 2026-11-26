import XCTest
import CloudKit
@testable import PVLibrary

/// Existing users' iCloud records are found by these names. A change here orphans them.
final class CloudKitRecordNameTests: XCTestCase {
    private typealias Names = CloudKitSchema.RecordIDGenerator

    func testRecordTypeNames() {
        XCTAssertEqual(CloudKitSchema.RecordType.rom.rawValue, "ROM")
        XCTAssertEqual(CloudKitSchema.RecordType.saveState.rawValue, "SaveState")
        XCTAssertEqual(CloudKitSchema.RecordType.bios.rawValue, "BIOS")
        XCTAssertEqual(CloudKitSchema.RecordType.file.rawValue, "File")
    }

    func testROMRecordName() {
        let md5 = "0123456789ABCDEF0123456789ABCDEF"
        let recordID = Names.romRecordID(md5: md5)
        XCTAssertEqual(recordID.recordName, "rom_\(md5)")
        XCTAssertEqual(Names.extractMD5FromRomRecordID(recordID), md5)
    }

    func testSaveStateRecordName() {
        let recordID = Names.saveStateRecordID(gameID: "ABCDEF", filename: "Game.svs")
        XCTAssertEqual(recordID.recordName, "savestate_ABCDEF_Game_svs")
    }

    func testSaveStateRecordNameReadsBackWhenTheFileNameHasNoUnderscore() {
        let recordID = Names.saveStateRecordID(gameID: "ABCDEF", filename: "Game.svs")
        let parts = Names.extractFromSaveStateRecordID(recordID)
        XCTAssertEqual(parts?.gameID, "ABCDEF")
        XCTAssertEqual(parts?.filename, "Game.svs")
    }

    /// Fault 1 in section 2.9 of the 2026-11-25 cloud sync design: `.` is written as `_`
    /// and every `_` is read back as `.`, so this file name does not survive.
    func testSaveStateRecordNameWithAnUnderscoreDoesNotReadBack() {
        let recordID = Names.saveStateRecordID(gameID: "ABCDEF", filename: "My_Game.svs")
        XCTExpectFailure("Known fault: underscores in a save state's file name are read back as dots.")
        XCTAssertEqual(Names.extractFromSaveStateRecordID(recordID)?.filename, "My_Game.svs")
    }
}
