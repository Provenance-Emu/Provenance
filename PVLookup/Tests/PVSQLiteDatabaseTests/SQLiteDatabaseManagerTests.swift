import Foundation
import Testing
import ZIPFoundation
@testable import PVSQLiteDatabase

/// Regression tests for PROVENANCE-269: bundled databases were re-extracted on every launch
/// because the staleness check compared modification dates that ZIPFoundation does not preserve.
struct SQLiteDatabaseManagerTests {

    /// Builds a flat "bundle" directory containing `<name>.zip` with a single `<name>` entry
    /// whose stored date is old (as with the real bundled archives).
    private func makeFixtureBundle(databaseName: String, contents: String) throws -> (Bundle, URL) {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("SQLiteDBMgrTests-\(UUID().uuidString)")
        let staging = root.appendingPathComponent("staging")
        let bundleDir = root.appendingPathComponent("Fixture.bundle")
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        let dbFile = staging.appendingPathComponent(databaseName)
        try Data(contents.utf8).write(to: dbFile)
        try fileManager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_734_000_000)],
                                      ofItemAtPath: dbFile.path)

        let zipURL = bundleDir.appendingPathComponent("\(databaseName).zip")
        try fileManager.zipItem(at: dbFile, to: zipURL)

        let bundle = try #require(Bundle(url: bundleDir))
        return (bundle, root)
    }

    private func cleanUp(_ manager: SQLiteDatabaseManager, root: URL) {
        try? FileManager.default.removeItem(at: manager.databasePath)
        try? FileManager.default.removeItem(at: manager.sourceMarkerPath)
        try? FileManager.default.removeItem(at: root)
    }

    private func inode(of url: URL) throws -> Int {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return try #require(attrs[.systemFileNumber] as? Int)
    }

    @Test
    func doesNotReextractOnSubsequentLaunches() async throws {
        let name = "test-\(UUID().uuidString).sqlite"
        let (bundle, root) = try makeFixtureBundle(databaseName: name, contents: "v1")

        let first = SQLiteDatabaseManager(bundle: bundle, databaseName: name)
        defer { cleanUp(first, root: root) }

        try await first.prepareDatabaseIfNeeded()
        #expect(FileManager.default.fileExists(atPath: first.databasePath.path))
        #expect(FileManager.default.fileExists(atPath: first.sourceMarkerPath.path))
        let firstInode = try inode(of: first.databasePath)

        // Simulate a fresh launch with a new manager instance.
        let second = SQLiteDatabaseManager(bundle: bundle, databaseName: name)
        try await second.prepareDatabaseIfNeeded()
        let secondInode = try inode(of: second.databasePath)

        #expect(firstInode == secondInode, "Database was re-extracted even though the archive is unchanged")
    }

    @Test
    func reextractsWhenArchiveContentsChange() async throws {
        let name = "test-\(UUID().uuidString).sqlite"
        let (bundleV1, rootV1) = try makeFixtureBundle(databaseName: name, contents: "v1")
        let (bundleV2, rootV2) = try makeFixtureBundle(databaseName: name, contents: "version-2")

        let v1 = SQLiteDatabaseManager(bundle: bundleV1, databaseName: name)
        defer {
            cleanUp(v1, root: rootV1)
            try? FileManager.default.removeItem(at: rootV2)
        }
        try await v1.prepareDatabaseIfNeeded()

        let v2 = SQLiteDatabaseManager(bundle: bundleV2, databaseName: name)
        try await v2.prepareDatabaseIfNeeded()

        let contents = try String(contentsOf: v2.databasePath, encoding: .utf8)
        #expect(contents == "version-2")
    }

    @Test
    func adoptsLegacyDatabaseWithoutMarker() async throws {
        let name = "test-\(UUID().uuidString).sqlite"
        let (bundle, root) = try makeFixtureBundle(databaseName: name, contents: "v1")

        let manager = SQLiteDatabaseManager(bundle: bundle, databaseName: name)
        defer { cleanUp(manager, root: root) }

        // Database extracted by an older build: present, but no marker.
        try Data("v1".utf8).write(to: manager.databasePath)
        let legacyInode = try inode(of: manager.databasePath)

        try await manager.prepareDatabaseIfNeeded()

        #expect(try inode(of: manager.databasePath) == legacyInode)
        #expect(FileManager.default.fileExists(atPath: manager.sourceMarkerPath.path))
    }
}
