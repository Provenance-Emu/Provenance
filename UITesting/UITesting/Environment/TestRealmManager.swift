import Foundation
import RealmSwift

final class TestRealmManager {
    static let shared = TestRealmManager()

    private(set) var realm: Realm?

    private init() {
        do {
            let config = Realm.Configuration(
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("test.realm"),
                inMemoryIdentifier: nil,
                deleteRealmIfMigrationNeeded: true // For testing only
            )
            self.realm = try Realm(configuration: config)
        } catch {
            print("Error initializing test realm: \(error)")
        }
    }
}
