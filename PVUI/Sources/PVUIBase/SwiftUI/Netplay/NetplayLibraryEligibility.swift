#if !os(watchOS)
import Foundation
import PVNetplay
import PVLibrary
import PVRealm
import RealmSwift

/// Which library games can be played over the network: every downloaded game whose system
/// has an installed core that carries netplay. Nothing is decided per game.
@MainActor
enum NetplayLibraryEligibility {
    struct Entry: Identifiable {
        let game: PVGame
        let eligibility: NetplayEligibility
        /// Advice shown beside the game. It never changes `eligibility`.
        let hint: NetplayGameHint
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
        let cores = (available ?? availableCores(in: realm))[game.systemIdentifier] ?? []
        let fileIsPresent = game.file?.url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let localFileAvailable = !game.contentless && game.isDownloaded && !game.isHiddenPatchVariant && fileIsPresent
        let eligibility = NetplayEligibility.evaluate(localFileAvailable: localFileAvailable, cores: cores)
        let identity = NetplayGameIdentity(md5: game.md5Hash, systemIdentifier: game.systemIdentifier,
                                           coreIdentifier: eligibility.options.first?.core.coreIdentifier ?? "")
        return Entry(game: game.isFrozen ? game : game.freeze(), eligibility: eligibility, hint: NetplayGameHints.hint(for: identity))
    }

    /// A room must name an installed compatible core. Never fall back silently to the user's default core.
    static func option(for room: NetplayRoom, entry: Entry) -> NetplayGameOption? {
        entry.eligibility.joinOption(for: room, gameMD5: entry.game.md5Hash, systemIdentifier: entry.game.systemIdentifier)
    }
}
#endif
