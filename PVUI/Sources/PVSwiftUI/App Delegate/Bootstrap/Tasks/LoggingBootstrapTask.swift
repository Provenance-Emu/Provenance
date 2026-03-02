//
//  LoggingBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// Initialises the shared ``PVLogging`` instance.
///
/// All other tasks that emit log output should declare `BootstrapKey.logging`
/// as a dependency so that logging is ready before they run.
struct LoggingBootstrapTask: BootstrapTask {
    var name: String { "Logging" }
    var dependencies: [String] { [] }
    var provisions: [String] { [BootstrapKey.logging] }

    func execute() async throws {
        _ = PVLogging.shared
    }
}
