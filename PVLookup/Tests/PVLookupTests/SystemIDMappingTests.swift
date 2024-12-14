import Testing
@testable import libretrodb

final class SystemIDMappingTests {
    func testOpenVGDBToLibretroConversion() {
        // Test NES conversion
        let nesOpenVGDB = 25  // NES in OpenVGDB
        let nesLibretro = SystemIDMapping.convertToLibretroID(nesOpenVGDB)
        #expect(nesLibretro == 28)  // Nintendo Entertainment System in libretrodb

        // Test SNES conversion
        let snesOpenVGDB = 26  // SNES in OpenVGDB
        let snesLibretro = SystemIDMapping.convertToLibretroID(snesOpenVGDB)
        #expect(snesLibretro == 37)  // Super Nintendo Entertainment System in libretrodb
    }

    func testLibretroToOpenVGDBConversion() {
        // Test NES conversion
        let nesLibretro = 28  // Nintendo Entertainment System in libretrodb
        let nesOpenVGDB = SystemIDMapping.convertToOpenVGDBID(nesLibretro)
        #expect(nesOpenVGDB == 25)  // NES in OpenVGDB

        // Test SNES conversion
        let snesLibretro = 37  // Super Nintendo Entertainment System in libretrodb
        let snesOpenVGDB = SystemIDMapping.convertToOpenVGDBID(snesLibretro)
        #expect(snesOpenVGDB == 26)  // SNES in OpenVGDB
    }

    func testArrayConversion() {
        let openVGDBIDs = [25, 26, 20]  // NES, SNES, GBA
        let libretroDB = SystemIDMapping.convertToLibretroIDs(openVGDBIDs)
        #expect(libretroDB.contains(28))  // NES
        #expect(libretroDB.contains(37))  // SNES
        #expect(libretroDB.contains(115)) // GBA
    }

    func testReverseArrayConversion() {
        let libretroDB = [28, 37, 115]  // NES, SNES, GBA in libretrodb
        let openVGDB = SystemIDMapping.convertToOpenVGDBIDs(libretroDB)
        #expect(openVGDB.contains(25))  // NES in OpenVGDB
        #expect(openVGDB.contains(26))  // SNES in OpenVGDB
        #expect(openVGDB.contains(20))  // GBA in OpenVGDB
    }

    func testBidirectionalMapping() {
        // Test that converting back and forth preserves the ID
        for (openVGDBID, libretroDB) in SystemIDMapping.openVGDBToLibretroMap {
            let roundTrip = SystemIDMapping.convertToOpenVGDBID(libretroDB)
            #expect(roundTrip == openVGDBID)
        }

        // Test reverse mapping
        for (libretroDB, openVGDBID) in SystemIDMapping.libretrotoOpenVGDBMap {
            let roundTrip = SystemIDMapping.convertToLibretroID(openVGDBID)
            #expect(roundTrip == libretroDB)
        }
    }

    func testMappingConsistency() {
        // Verify that both maps contain the same relationships
        for (openVGDBID, libretroDB) in SystemIDMapping.openVGDBToLibretroMap {
            let reverseMapping = SystemIDMapping.libretrotoOpenVGDBMap[libretroDB]
            #expect(reverseMapping == openVGDBID)
        }
    }
}
