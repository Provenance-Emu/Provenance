import Foundation
import RealmSwift
import PVPrimitives
import PVRealm

public class RealmCheatDriver: CheatDriver {
    public typealias Entry = RealmCheatEntry

    @Published private(set) public var cheats: [RealmCheatEntry] = []
    private var notificationToken: NotificationToken?
    private let realm: Realm
    private let game: PVGame

    public var gameTitle: String {
        game.title
    }

    public var supportedCheatTypes: [CheatCodeTypes] {
        // Get supported types from the core if available
        if let core = game.system.cores.first {
            // TODO: Implement core-specific cheat type filtering
            return CheatCodeTypes.allCases
        }
        return CheatCodeTypes.allCases
    }

    public struct RealmCheatEntry: CheatEntry {
        public let id: String
        public var code: String
        public var type: CheatCodeTypes
        public var title: String
        public var enabled: Bool

        fileprivate let realmCheat: PVCheats

        // Required by CheatEntry protocol
        public init(id: String, code: String, type: CheatCodeTypes, title: String, enabled: Bool) {
            self.id = id
            self.code = code
            self.type = type
            self.title = title
            self.enabled = enabled
            // Create a temporary PVCheats since we're not actually using it in this case
            self.realmCheat = PVCheats()
        }

        // Internal initializer for creating from Realm object
        fileprivate init(realmCheat: PVCheats) {
            self.id = realmCheat.id
            self.code = realmCheat.code
            self.type = CheatCodeTypes.detectType(from: realmCheat.code).first ?? .rawCode
            self.title = realmCheat.type // We store the title in the type field in Realm
            self.enabled = realmCheat.enabled
            self.realmCheat = realmCheat
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    public init(realm: Realm, game: PVGame) {
        self.realm = realm
        self.game = game

        // Initial load
        reloadCheats()

        // Observe changes
        notificationToken = game.cheats.observe { [weak self] changes in
            self?.reloadCheats()
        }
    }

    deinit {
        notificationToken?.invalidate()
    }

    private func reloadCheats() {
        cheats = Array(game.cheats.map { RealmCheatEntry(realmCheat: $0) })
    }

    public func addCheat(_ cheat: RealmCheatEntry) {
        do {
            try realm.write {
                let newCheat = PVCheats()
                newCheat.id = cheat.id
                newCheat.game = game
                newCheat.code = cheat.code
                newCheat.type = cheat.title // Store title in type field
                newCheat.enabled = cheat.enabled
                newCheat.core = game.system.cores.first // Use first available core
                newCheat.file = PVFile() // TODO: Handle file if needed
                newCheat.createdWithCoreVersion = game.system.cores.first?.projectVersion ?? "1.0"

                realm.add(newCheat)
            }
        } catch {
            print("Error adding cheat: \(error)")
        }
    }

    public func toggleCheat(_ id: String) {
        guard let cheat = realm.object(ofType: PVCheats.self, forPrimaryKey: id) else { return }

        do {
            try realm.write {
                cheat.enabled.toggle()
            }
        } catch {
            print("Error toggling cheat: \(error)")
        }
    }

    public func deleteCheat(_ id: String) {
        guard let cheat = realm.object(ofType: PVCheats.self, forPrimaryKey: id) else { return }

        do {
            try realm.write {
                realm.delete(cheat)
            }
        } catch {
            print("Error deleting cheat: \(error)")
        }
    }

    public func updateCheat(_ cheat: RealmCheatEntry) {
        guard let realmCheat = realm.object(ofType: PVCheats.self, forPrimaryKey: cheat.id) else { return }

        do {
            try realm.write {
                realmCheat.code = cheat.code
                realmCheat.type = cheat.title
                realmCheat.enabled = cheat.enabled
            }
        } catch {
            print("Error updating cheat: \(error)")
        }
    }
}

// MARK: - Preview Helper
extension RealmCheatDriver {
    static func previewDriver() throws -> RealmCheatDriver {
        let realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "preview"))

        // Create test data if needed
        if realm.objects(PVGame.self).isEmpty {
            try realm.write {
                // Create core first
                let core = PVCore(
                    withIdentifier: "test.core",
                    principleClass: "TestCore",
                    supportedSystems: [], // Will add system after creation
                    name: "Test Core",
                    url: "https://test.core",
                    version: "1.0"
                )

                // Create system using convenience initializer
                let system = PVSystem(
                    identifier: "test.system",
                    name: "Test System",
                    shortName: "TEST",
                    manufacturer: "Test Manufacturer"
                )

                // Add system to core's supported systems
                core.supportedSystems.append(system)

                // Create game
                let game = PVGame()
                game.title = "Test Game"
                game.system = system
                game.md5Hash = "test"

                // Add objects to realm
                realm.add([core, system, game])
            }
        }

        let game = realm.objects(PVGame.self).first!
        return RealmCheatDriver(realm: realm, game: game)
    }
}
