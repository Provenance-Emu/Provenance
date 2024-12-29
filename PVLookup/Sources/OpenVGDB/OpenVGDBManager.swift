import Foundation
import PVSQLiteDatabase
import PVLogging

/// Manager for OpenVGDB SQLite database
public actor OpenVGDBManager {
    /// Singleton instance
    public static let shared = OpenVGDBManager()

    private let databaseManager: SQLiteDatabaseManager

    private init() {
        self.databaseManager = SQLiteDatabaseManager(
            bundle: .module,
            databaseName: "openvgdb.sqlite",
            compressedName: "openvgdb.sqlite"
        )
    }

    /// Ensures database is ready for use
    public func prepareDatabaseIfNeeded() async throws {
        try await databaseManager.prepareDatabaseIfNeeded()
    }

    /// Path to the database file
    public var databasePath: URL {
        databaseManager.databasePath
    }
}
