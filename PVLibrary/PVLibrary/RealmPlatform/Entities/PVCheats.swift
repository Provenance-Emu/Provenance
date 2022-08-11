//
//  PVCheats.swift
//  Provenance
//

import Foundation
import PVSupport
import RealmSwift

public protocol CheatFile {
    associatedtype LocalFileProviderType: LocalFileProvider
    var file: LocalFileProviderType! { get }
}

extension LocalFileProvider where Self: CheatFile {
    public var url: URL { return file.url }
    public var fileInfo: Self.LocalFileProviderType? { return file }
}

public final class PVCheats: Object, CheatFile, LocalFileProvider {
    @Persisted(primaryKey: true) public var id = UUID().uuidString
    @Persisted public var game: PVGame!
    @Persisted public var core: PVCore!
    @Persisted public var code: String!
    @Persisted public var file: PVFile!
    @Persisted(indexed: true) public var date: Date = Date()
    @Persisted public var lastOpened: Date?
    @Persisted public var type: String!
    @Persisted public var enabled: Bool = false

    @Persisted public var createdWithCoreVersion: String!

    public convenience init(withGame game: PVGame, core: PVCore, code: String, type: String, enabled: Bool = false, file: PVFile ) {
        self.init()
        self.game = game
        self.code = code
        self.type = type
        self.enabled = enabled
        self.core = core
        self.file = file
        createdWithCoreVersion = core.projectVersion
    }

    public class func delete(_ state: PVCheats) throws {
        do {
            let database = RomDatabase.sharedInstance
            try database.delete(state)

        } catch {
            ELOG("Failed to delete PVState")
            throw error
        }
    }

    public static func == (lhs: PVCheats, rhs: PVCheats) -> Bool {
        return lhs.code == rhs.code && lhs.type == rhs.type && lhs.enabled == rhs.enabled
    }
}

// MARK: - Conversions

private extension Cheats {
    init(with saveState: PVCheats) {
        id = saveState.id
        game = saveState.game.asDomain()
        core = saveState.core.asDomain()
        code = saveState.code
        type = saveState.type
        date = saveState.date
        lastOpened = saveState.lastOpened
        enabled=saveState.enabled
        file = FileInfo(fileName: saveState.file.fileName, size: saveState.file.size, md5: saveState.file.md5, online: saveState.file.online, local: true)
    }
}

extension PVCheats: DomainConvertibleType {
    public typealias DomainType = Cheats

    public func asDomain() -> Cheats {
        return Cheats(with: self)
    }
}

extension Cheats: RealmRepresentable {
    public var uid: String {
        return code
    }

    public func asRealm() -> PVCheats {
        return PVCheats.build { object in

            object.id = id
            let realm = try! Realm()
            let rmGame = realm.object(ofType: PVGame.self, forPrimaryKey: game.md5) ?? game.asRealm()
            object.game = rmGame
            let rmCore = realm.object(ofType: PVCore.self, forPrimaryKey: core.identifier) ?? core.asRealm()
            object.core = rmCore
            object.date = date
            let path = PVEmulatorConfiguration.saveStatePath(forROMFilename: game.file.fileName).appendingPathComponent(file.fileName)
            object.file = PVFile(withURL: path)
            object.lastOpened = lastOpened
            object.code=code
            object.type=type
            object.enabled=enabled
        }
    }
}
