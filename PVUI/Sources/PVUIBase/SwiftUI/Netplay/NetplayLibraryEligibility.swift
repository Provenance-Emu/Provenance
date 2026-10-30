#if !os(watchOS)
import Foundation
import PVNetplay
import PVLibrary
import PVRealm
import RealmSwift

@MainActor
enum NetplayLibraryEligibility {
    struct Entry: Identifiable {
        let game: PVGame
        let metadata: NetplayMultiplayerMetadata?
        let eligibility: NetplayEligibility
        var id: String { game.md5Hash }
    }

    static func availableCores(in realm: Realm) -> [String: [NetplayCoreSupport]] {
        var result: [String: [NetplayCoreSupport]] = [:]
        for core in realm.objects(PVCore.self).filter("disabled == false AND appStoreDisabled == false") {
            guard core.hasCoreClass else { continue }
            for system in core.supportedSystems {
                if let support = NetplayCoreCompatibility.support(coreIdentifier: core.identifier, systemIdentifier: system.identifier,
                                                                 coreVersion: core.projectVersion) {
                    result[system.identifier, default: []].append(support)
                }
            }
        }
        return result.mapValues { $0.sorted { $0.coreIdentifier < $1.coreIdentifier } }
    }

    static func entry(_ game: PVGame, realm: Realm, available: [String: [NetplayCoreSupport]]? = nil) -> Entry {
        let metadata = NetplayMetadataStore.shared.metadata(md5: game.md5Hash, system: game.systemIdentifier,
                                                          serial: game.romSerial, isPatched: game.isPatchVariant)
        let cores = (available ?? availableCores(in: realm))[game.systemIdentifier] ?? []
        let fileIsPresent = game.file?.url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let localFileAvailable = !game.contentless && game.isDownloaded && !game.isHiddenPatchVariant && fileIsPresent
        let unverifiedCore = metadata != nil && cores.isEmpty && realm.objects(PVCore.self).filter("disabled == false AND appStoreDisabled == false").contains {
            $0.hasCoreClass && $0.supportedSystems.contains { $0.identifier == game.systemIdentifier }
                && NetplayCoreCompatibility.netpacketMode(coreIdentifier: $0.identifier, systemIdentifier: game.systemIdentifier) != nil
        }
        return Entry(game: game.isFrozen ? game : game.freeze(), metadata: metadata,
                     eligibility: .evaluate(localFileAvailable: localFileAvailable, metadata: metadata, cores: cores, hasUnverifiedCore: unverifiedCore))
    }

    /// A room must name an installed compatible core. Never fall back silently to the user's default core.
    static func option(for room: NetplayRoom, entry: Entry) -> NetplayGameOption? {
        entry.eligibility.joinOption(for: room, gameMD5: entry.game.md5Hash, systemIdentifier: entry.game.systemIdentifier)
    }
}
#endif
