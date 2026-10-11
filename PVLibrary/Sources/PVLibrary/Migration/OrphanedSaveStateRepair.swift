//
//  OrphanedSaveStateRepair.swift
//  PVLibrary
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Gives save states whose core row was deleted their core back. Deleting a PVCore nils
//  the `core` link of every state on it; the stale-core prune used to do that, and Lite
//  shares the library with the full app while shipping fewer native cores, so launching
//  Lite orphaned the full app's Dolphin and Mupen64Plus states.
//
//  Evidence, strongest first: the save's JSON sidecar (`<save>.svs.json`, which names the
//  core), then the one core for the game's system whose version matches the state's
//  `createdWithCoreVersion`, then the only core for that system available in this build.
//  A state the evidence doesn't settle stays orphaned; a later launch of a build with
//  more cores tries again.
//

import Foundation
import RealmSwift
import PVLogging
import PVRealm

enum OrphanedSaveStateRepair {

    /// Relinks orphaned save states. Must be called inside a write transaction.
    /// - Parameters:
    ///   - isAvailable: whether a core can run in this build.
    ///   - sidecarCoreIdentifier: the core named by a state's JSON sidecar, if any.
    /// - Returns: how many states got a core.
    @discardableResult
    static func repair(in realm: Realm,
                       isAvailable: (PVCore) -> Bool = { $0.hasCoreClass },
                       sidecarCoreIdentifier: (PVSaveState) -> String? = sidecarCoreIdentifier(for:)) -> Int {
        var repaired = 0
        for state in Array(realm.objects(PVSaveState.self).filter("core == nil")) {
            guard let game = state.game else { continue }
            guard let core = core(for: state, systemIdentifier: game.systemIdentifier, in: realm,
                                  isAvailable: isAvailable, sidecarCoreIdentifier: sidecarCoreIdentifier) else {
                WLOG("OrphanedSaveStateRepair: no core for save state \(state.id) (\(game.systemIdentifier))")
                continue
            }
            state.core = core
            repaired += 1
        }
        if repaired > 0 {
            ILOG("OrphanedSaveStateRepair: relinked \(repaired) save state(s) to their core")
        }
        return repaired
    }

    private static func core(for state: PVSaveState, systemIdentifier: String, in realm: Realm,
                             isAvailable: (PVCore) -> Bool,
                             sidecarCoreIdentifier: (PVSaveState) -> String?) -> PVCore? {
        if let identifier = sidecarCoreIdentifier(state),
           let core = realm.object(ofType: PVCore.self, forPrimaryKey: PVCore.currentIdentifier(for: identifier)) {
            return core
        }
        let candidates = Array(realm.objects(PVCore.self).filter("ANY supportedSystems.identifier == %@", systemIdentifier))
        if let version = state.createdWithCoreVersion {
            let matches = candidates.filter { $0.projectVersion == version }
            // A version that names a core this build lacks still rules the others out.
            if !matches.isEmpty {
                return matches.count == 1 && isAvailable(matches[0]) ? matches[0] : nil
            }
        }
        let available = candidates.filter(isAvailable)
        return available.count == 1 ? available[0] : nil
    }

    private struct Sidecar: Decodable {
        struct Core: Decodable { let identifier: String }
        let core: Core
    }

    /// The core identifier in `<save>.json`, written by `LibrarySerializer.storeMetadata`.
    static func sidecarCoreIdentifier(for state: PVSaveState) -> String? {
        guard let url = state.file?.url else { return nil }
        let sidecar = url.appendingPathExtension("json")
        guard let data = try? Data(contentsOf: sidecar) else { return nil }
        return (try? JSONDecoder().decode(Sidecar.self, from: data))?.core.identifier
    }
}
