import Foundation
import PVSQLiteDatabase
import PVLogging

/// Manager for LibretroDB SQLite database
public actor LibretroDBManager {
    /// Singleton instance
    public static let shared = LibretroDBManager()

    private let databaseManager: SQLiteDatabaseManager

    private init() {
        self.databaseManager = SQLiteDatabaseManager(
            bundle: .module,
            databaseName: "libretrodb.sqlite",
            compressedName: "libretrodb.sqlite"
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
