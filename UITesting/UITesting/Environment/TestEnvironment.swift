import Foundation
import RealmSwift
import SwiftUI

private struct TestRealmKey: EnvironmentKey {
    static let defaultValue: Realm? = try? Realm(configuration: .init(
        fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("test.realm"),
        inMemoryIdentifier: nil
    ))
}

extension EnvironmentValues {
    var testRealm: Realm? {
        get { self[TestRealmKey.self] }
        set { self[TestRealmKey.self] = newValue }
    }
}
