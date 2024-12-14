import Testing
@testable import Systems

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
}
