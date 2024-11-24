import Foundation
import RealmSwift
import PVLibrary
import SwiftUI

/// Factory for creating in-memory Realm instances with test data
public class RealmSaveStateTestFactory {
    /// Creates an in-memory Realm with sample save states
    public static func createInMemoryRealm() throws -> Realm {
        /// Configure in-memory Realm
        var configuration = Realm.Configuration()
        configuration.inMemoryIdentifier = "TestRealm"

        let realm = try Realm(configuration: configuration)

        /// Create sample data
        try realm.write {
            /// Create a test game and core
            let game = PVGame()
            game.title = "Bomber Man"
            game.id = "test-game-1"

            // Setup game file
            let gameFile = PVFile(withPartialPath: "bomber-man.sfc", relativeRoot: .documents)
//            gameFile.sizeCache = 2_097_152 // 2MB
//            gameFile.md5Cache = "abc123def456"
            game.file = gameFile

            let core = PVCore()
            core.projectVersion = "1.0.0"

            realm.add(game)
            realm.add(core)

            /// Create 15 sample save states with varied properties
            for i in 0...14 {
                let file = PVFile(withPartialPath: "save-\(i).sav", relativeRoot: .documents)
                //file.sizeCache = 128_000 // 128KB
                //file.md5Cache = "save\(i)_md5_hash"

                let saveState = PVSaveState(
                    withGame: game,
                    core: core,
                    file: file,
                    isAutosave: i % 3 == 0,
                    isPinned: i % 4 == 0,
                    isFavorite: i % 2 == 0,
                    userDescription: getDescription(for: i)
                )

                // Distribute dates across last two weeks
                saveState.date = Date().addingTimeInterval(Double(-i * 24 * 3600))

                realm.add(saveState)
            }
        }

        return realm
    }

    private static func getDescription(for index: Int) -> String? {
        let descriptions = [
            "Final Boss Battle",
            "Secret Area Found",
            "Power-Up Location",
            "Hidden Passage",
            "Boss Rush Mode",
            nil,
            "100% Completion",
            nil,
            "Speed Run Attempt",
            "Extra Lives Found",
            nil,
            "Secret Ending Path",
            nil,
            "Challenge Mode",
            "Tournament Ready"
        ]
        return descriptions[index]
    }
}
