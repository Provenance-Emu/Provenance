//
//  SkinIndexPrewarmBootstrapTask.swift
//  PVUI
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVUIBase
import SkinKitManager

/// Starts the skin scan in the background at launch.
///
/// Without a stored skin pick, the first game launched resolves its skin through
/// `DeltaSkinManager.availableSkins()`, which opens every bundled and imported skin archive and
/// parses its info.json while the game waits on "LOADING SKIN". The scan is cached for the rest
/// of the run, so doing it early takes it off that path. Fire-and-forget: launch doesn't wait.
///
/// Depends on `BootstrapKey.settings` (the library location decides where imported skins live).
struct SkinIndexPrewarmBootstrapTask: BootstrapTask {
    var name: String { "Skin index prewarm" }
    var dependencies: [String] { [BootstrapKey.logging, BootstrapKey.settings] }
    var provisions: [String] { [] }

    func execute() async throws {
        #if !os(tvOS)   // tvOS has no skins
        Task.detached(priority: .utility) {
            let skins = try? await DeltaSkinManager.shared.availableSkins()
            ILOG("SkinIndexPrewarmBootstrapTask: scanned \(skins?.count ?? 0) skins")
        }
        #endif
    }
}
