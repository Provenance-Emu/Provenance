//
//  PVAppDelegate+Helpers.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVLogging
import PVSettings
import PVUIBase

#if canImport(PVWebServer)
import PVWebServer
#endif

// MARK: - Helpers
extension PVAppDelegate {

    /// Boot the web server. Always-on across platforms; paused during emulation
    /// via `BackgroundServiceRegistry`. The implementation choice (legacy
    /// GCDWebServer vs. modern Hummingbird) is read from `Defaults[.useModernWebServer]`
    /// by `PVWebServerManager.refreshFeatureFlag()`.
    /// Legacy entry kept for any straggler callers. The canonical web-server
    /// startup is `WebServerBootstrapTask` which runs as part of the bootstrap
    /// pipeline on every platform. This shim defers to that lifecycle service
    /// + manager so callers don't end up double-starting the server.
    func startOptionalWebDavServer() {
#if canImport(PVWebServer)
        _ = PVWebServerLifecycleService.shared
        Task {
            await PVWebServerManager.shared.refreshFeatureFlag()
            do {
                _ = try await PVWebServerManager.shared.start()
            } catch {
                ELOG("startWebServer: \(error.localizedDescription)")
            }
        }
#endif
    }

}
