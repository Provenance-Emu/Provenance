//
//  FirebaseBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

#if canImport(Firebase)
import Firebase
import FirebaseCrashlyticsSwift
#endif

/// Configures Firebase and Crashlytics.
///
/// Requires `BootstrapKey.logging` so that any errors are captured in the log.
/// Provides `BootstrapKey.firebase` and `BootstrapKey.crashReporting`.
struct FirebaseBootstrapTask: BootstrapTask {
    var name: String { "Firebase" }
    var dependencies: [String] { [BootstrapKey.logging] }
    var provisions: [String] { [BootstrapKey.firebase, BootstrapKey.crashReporting] }

    func execute() async throws {
#if canImport(Firebase)
        FirebaseApp.configure()
        ILOG("FirebaseBootstrapTask: FirebaseApp configured")
#else
        ILOG("FirebaseBootstrapTask: Firebase not available on this target")
#endif
    }
}
