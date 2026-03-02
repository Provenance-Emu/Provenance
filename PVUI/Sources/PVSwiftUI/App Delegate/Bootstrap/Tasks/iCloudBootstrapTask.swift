//
//  iCloudBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVEmulatorCore

/// Initialises iCloud / CloudKit configuration via
/// `PVEmulatorConfiguration.initICloud()`.
///
/// Depends on `BootstrapKey.logging` and `BootstrapKey.settings`.
/// Provides `BootstrapKey.iCloud`.
struct iCloudBootstrapTask: BootstrapTask {
    var name: String { "iCloud" }
    var dependencies: [String] { [BootstrapKey.logging, BootstrapKey.settings] }
    var provisions: [String] { [BootstrapKey.iCloud] }

    func execute() async throws {
        PVEmulatorConfiguration.initICloud()
        ILOG("iCloudBootstrapTask: iCloud configuration initialised")
    }
}
