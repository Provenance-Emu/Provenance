//
//  GameTag+Library.swift
//  PVUIBase
//
//  Connects game tags to the library and to the app's open-by-MD5 route.
//

#if os(iOS) && canImport(CoreNFC)
import Foundation
import PVLibrary
import PVLogging
import PVRealm
import RealmSwift

/// Bundle id written when `Bundle.main` has none (it always has one in the app).
private let fallbackBundleIdentifier = "org.provenance-emu.provenance"

public extension GameTagWriter {
    /// Writes a tag that launches `game`. Main thread; `game` may be frozen.
    func write(game: PVGame) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? fallbackBundleIdentifier
        guard let payload = GameTagPayload(md5: game.md5Hash, title: game.title, bundleIdentifier: bundleIdentifier) else {
            ELOG("GameTagWriter: game '\(game.title)' has no usable MD5")
            return
        }
        write(payload)
    }
}

public extension GameTagReader {
    /// Scans a tag and opens its game the same way a `provenance://open?md5=` link does.
    /// Main thread only.
    func scanAndOpenGame() {
        scan(isInLibrary: { md5 in
            // Library primary keys are upper-case (see ProvenanceApp.prepareGameForEmulatorScene).
            RomDatabase.sharedInstance.realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) != nil
        }, open: { md5 in
            MainActor.assumeIsolated {
                AppState.shared.appOpenAction = .openMD5(md5)
            }
        })
    }
}
#endif
