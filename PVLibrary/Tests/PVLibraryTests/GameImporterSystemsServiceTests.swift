import Testing
import PVLibrary
import PVLookup
import PVSystems
import PVHashing
@testable import PVLibrary

/// Mock MD5Provider for testing
class MockMD5Provider: MD5Provider {
    var mockMD5: String?

    func md5ForFile(atPath path: String, fromOffset offset: UInt = 0) -> String? {
        return mockMD5
    }
}

struct GameImporterSystemsServiceTests {
    var service: GameImporterSystemsService!
    let mockMD5Provider = MockMD5Provider()
    let database = RomDatabase.sharedInstance

    init() {
        service = GameImporterSystemsService()
        setupTestDatabase()
    }

    /// Setup test database with required systems
    private func setupTestDatabase() {
        // Create test systems
        let testSystems: [(SystemIdentifier, [String])] = [
            (.ColecoVision, ["col"]),
            (.NES, ["nes"]),
            (.PSX, ["bin"]),
            (.SNES, ["sfc"]),
            (.Genesis, ["gen"])
        ]

        try? database.writeTransaction {
            for (identifier, extensions) in testSystems {
                let system = PVSystem()
                system.identifier = identifier.rawValue
                system.manufacturer = identifier.manufacturer
                system.name = identifier.systemName
                system.shortName = identifier.systemName
                system.supportedExtensions.append(objectsIn: extensions)

                try! database.add(system, update: true)
            }
        }

        // Force reload systems cache
        RomDatabase.reloadCaches(force: true)
    }

    @Test("Determine systems for filenames with special characters")
    func testSpecialCharacters() async throws {
        // Test cases with special characters and periods
        let testCases = [
            (
                filename: "Bruce's Controller Test v1.0 (2004) (Bruce Tomlin).col",
                extension: "col",
                expectedSystems: [SystemIdentifier.ColecoVision]
            ),
            (
                filename: "Super Mario Bros. 3 (USA) (Rev 1).nes",
                extension: "nes",
                expectedSystems: [SystemIdentifier.NES]
            ),
            (
                filename: "Final Fantasy VII (v1.1).bin",
                extension: "bin",
                expectedSystems: [SystemIdentifier.PSX]
            ),
            (
                filename: "Street Fighter II' Turbo.sfc",
                extension: "sfc",
                expectedSystems: [SystemIdentifier.SNES]
            ),
            (
                filename: "Sonic & Knuckles.gen",
                extension: "gen",
                expectedSystems: [SystemIdentifier.Genesis]
            )
        ]

        for testCase in testCases {
            // Create test URL and ImportQueueItem
            let url = URL(fileURLWithPath: "/test/\(testCase.filename)")
            let item = ImportQueueItem(url: url)

            // Test system determination
            let systems = try await service.determineSystems(for: item)

            // Verify results
            #expect(systems.sorted() == testCase.expectedSystems.sorted())

            // Verify extension extraction
            let extractedExtension = url.pathExtension.lowercased()
            #expect(extractedExtension == testCase.extension)
        }
    }

    @Test("Handle invalid file extensions")
    func testInvalidExtensions() async throws {
        let testCases = [
            "invalid_file",
            "no_extension.",
            ".hidden",
            ""
        ]

        for filename in testCases {
            let url = URL(fileURLWithPath: "/test/\(filename)")
            let item = ImportQueueItem(url: url)

            let systems = try await service.determineSystems(for: item)
            #expect(systems.isEmpty == true)
        }
    }

    @Test("Fallback to extension lookup when MD5 fails")
    func testMD5Fallback() async throws {
        let url = URL(fileURLWithPath: "/test/game.unknown")
        mockMD5Provider.mockMD5 = "1234567890abcdef"

        // Create ImportQueueItem with mocked MD5Provider
        let item = ImportQueueItem(url: url, md5Provider: mockMD5Provider)

        // First attempt should use MD5
        let systems = try await service.determineSystems(for: item)

        // Since this is a test MD5, it should fall back to extension lookup
        // which should return empty array for unknown extension
        #expect(systems.isEmpty == true)
    }
}
