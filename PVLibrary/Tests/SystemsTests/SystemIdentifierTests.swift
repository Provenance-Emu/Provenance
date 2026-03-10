import Testing
@testable import PVSystems

final class SystemIdentifierTests {
    // MARK: - OpenVGDB Conversion Tests
    func testOpenVGDBConversion() {
        // Test NES
        #expect(SystemIdentifier.NES.openVGDBID == 25)
        #expect(SystemIdentifier.fromOpenVGDBID(25) == .NES)

        // Test SNES
        #expect(SystemIdentifier.SNES.openVGDBID == 26)
        #expect(SystemIdentifier.fromOpenVGDBID(26) == .SNES)

        // Test GBA
        #expect(SystemIdentifier.gba.openVGDBID == 20)
        #expect(SystemIdentifier.fromOpenVGDBID(20) == .gba)
    }

    // MARK: - LibretroDB Conversion Tests
    func testLibretroDBConversion() {
        // Test NES
        #expect(SystemIdentifier.NES.libretroDatabaseID == 28)
        #expect(SystemIdentifier.fromLibretroDatabaseID(28) == .NES)

        // Test SNES
        #expect(SystemIdentifier.SNES.libretroDatabaseID == 37)
        #expect(SystemIdentifier.fromLibretroDatabaseID(37) == .SNES)

        // Test GBA
        #expect(SystemIdentifier.gba.libretroDatabaseID == 115)
        #expect(SystemIdentifier.fromLibretroDatabaseID(115) == .gba)
    }

    // MARK: - Cross-Database Consistency Tests
    func testCrossDatabaseConsistency() {
        for system in SystemIdentifier.allCases {
            // Convert to OpenVGDB ID and back
            let openVGDBID = system.openVGDBID
            let fromOpenVGDB = SystemIdentifier.fromOpenVGDBID(openVGDBID)
            #expect(fromOpenVGDB == system)

            // Convert to LibretroDB ID and back
            let libretroDatabaseID = system.libretroDatabaseID
            let fromLibretroDB = SystemIdentifier.fromLibretroDatabaseID(libretroDatabaseID)
            #expect(fromLibretroDB == system)

            // Verify cross-database conversion matches SystemIDMapping
            let mappedID = SystemIDMapping.convertToLibretroID(openVGDBID)
            #expect(mappedID == libretroDatabaseID)
        }
    }

    // MARK: - Offset Tests (for MD5 hashing)
    func testNESHas16ByteOffset() {
        // NES uses iNES header (16 bytes) that should be skipped
        #expect(SystemIdentifier.NES.offset == 16)
    }

    func testSNESHasZeroOffset() {
        // SNES uses dynamic detection in GameImporterDatabaseService
        // (512-byte copier header detection), so static offset is 0
        #expect(SystemIdentifier.SNES.offset == 0)
    }

    func testOtherSystemsHaveZeroOffset() {
        // Most systems have no header to skip
        #expect(SystemIdentifier.Genesis.offset == 0)
        #expect(SystemIdentifier.GBA.offset == 0)
        #expect(SystemIdentifier.N64.offset == 0)
        #expect(SystemIdentifier.PSX.offset == 0)
    }
}
