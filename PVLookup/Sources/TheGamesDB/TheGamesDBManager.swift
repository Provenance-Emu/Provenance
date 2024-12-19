import Foundation
import PVSQLiteDatabase

/// Manager for TheGamesDB SQLite database
public actor TheGamesDBManager {
    /// Singleton instance
    public static let shared = TheGamesDBManager()

    private let databaseManager: SQLiteDatabaseManager

    private init() {
        self.databaseManager = SQLiteDatabaseManager(
            bundle: .module,
            databaseName: "thegamesdb.sqlite",
            compressedName: "thegamesdb.sqlite"
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
