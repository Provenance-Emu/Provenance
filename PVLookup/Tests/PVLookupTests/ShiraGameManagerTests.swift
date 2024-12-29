import Testing
import Foundation
@testable import ShiraGame

struct ShiraGameManagerTests {
    let manager = ShiraGameManager.shared

    @Test
    func testDatabasePath() async {
        let dbPath = manager.databasePath
        #expect(dbPath.lastPathComponent == "shiragame.sqlite3")
        #expect(dbPath.path.contains("Caches"))
    }

    @Test
    func testDatabaseExtraction() async throws {
        // Remove any existing database
        try? FileManager.default.removeItem(at: manager.databasePath)
        #expect(!FileManager.default.fileExists(atPath: manager.databasePath.path))

        // Extract database
        try await manager.prepareDatabaseIfNeeded()
        #expect(FileManager.default.fileExists(atPath: manager.databasePath.path))

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: manager.databasePath.path)
        let fileSize = attributes[.size] as! Int64
        #expect(fileSize > 0)
    }

    @Test
    func testDatabaseExtractionIdempotent() async throws {
        // Extract database twice
        try await manager.prepareDatabaseIfNeeded()
        let firstModificationDate = try FileManager.default.attributesOfItem(atPath: manager.databasePath.path)[.modificationDate] as! Date

        try await manager.prepareDatabaseIfNeeded()
        let secondModificationDate = try FileManager.default.attributesOfItem(atPath: manager.databasePath.path)[.modificationDate] as! Date

        // Should be the same file (not re-extracted)
        #expect(firstModificationDate == secondModificationDate)
    }
}
