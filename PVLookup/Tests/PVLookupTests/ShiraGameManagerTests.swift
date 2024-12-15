import Testing
@testable import ShiraGame

final class ShiraGameManagerTests {
    override func setUp() {
        // Clean up any existing database
        try? FileManager.default.removeItem(at: ShiraGameManager.databasePath)
    }

    func testDatabaseExtraction() throws {
        // Verify database doesn't exist
        #expect(!FileManager.default.fileExists(atPath: ShiraGameManager.databasePath.path))

        // Extract database
        try ShiraGameManager.prepareDatabaseIfNeeded()

        // Verify database exists
        #expect(FileManager.default.fileExists(atPath: ShiraGameManager.databasePath.path))

        // Verify it's a valid SQLite database
        let data = try Data(contentsOf: ShiraGameManager.databasePath, count: 16)
        let header = "SQLite format 3"
        #expect(String(data: data.prefix(header.count), encoding: .utf8)?.hasPrefix(header) == true)
    }

    func testCaching() throws {
        // First extraction
        try ShiraGameManager.prepareDatabaseIfNeeded()
        let firstModificationDate = try FileManager.default.attributesOfItem(atPath: ShiraGameManager.databasePath.path)[.modificationDate] as? Date

        // Second extraction - should use cached file
        try ShiraGameManager.prepareDatabaseIfNeeded()
        let secondModificationDate = try FileManager.default.attributesOfItem(atPath: ShiraGameManager.databasePath.path)[.modificationDate] as? Date

        // Verify dates match (cached file was used)
        #expect(firstModificationDate == secondModificationDate)
    }
}
