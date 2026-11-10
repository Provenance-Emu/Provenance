//
//  WebServerBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging
import PVUIBase

#if canImport(PVWebServerHost)
import PVWebServerHost
#endif

/// Registers the lifecycle service with
/// `BackgroundServiceRegistry` for emulation pause/resume, and starts the
/// HTTP and WebDAV server on every platform.
///
/// On iOS / Catalyst the system Local Network permission alert fires when
/// the web server / Bonjour first touches the network; `LocalNetworkOnboardingView`
/// in `MainView` displays an informational retrowave alert alongside it.
///
/// Depends on `BootstrapKey.logging`. Provides `BootstrapKey.webServer`.
@MainActor
struct WebServerBootstrapTask: BootstrapTask {
    var name: String { "WebServer" }
    var dependencies: [String] { [BootstrapKey.logging] }
    var provisions: [String] { [BootstrapKey.webServer] }

    func execute() async throws {
#if canImport(PVWebServerHost)
        // Touch the lifecycle service so it self-registers with
        // BackgroundServiceRegistry — that's how the web server gets
        // paused during emulation and resumed when the user returns home.
        _ = PVWebServerLifecycleService.shared

        // /api/debug/* handlers (no-op unless PVDebugAPIPrefs.isEnabled).
        PVDebugAPIRoutes.registerAll()

        let impl = await PVWebServerManager.shared.implementationDescription
        ILOG("WebServerBootstrapTask: starting web server (impl=\(impl))")
        do {
            let ok = try await PVWebServerManager.shared.start()
            if ok {
                let http = await PVWebServerManager.shared.serverURL?.absoluteString ?? "?"
                let dav  = await PVWebServerManager.shared.webDAVURL?.absoluteString ?? "?"
                ILOG("WebServerBootstrapTask: web server started — HTTP: \(http), WebDAV: \(dav)")
            } else {
                WLOG("WebServerBootstrapTask: web server did not start (impl=\(impl)) — see the PVHostedWebServer log line for the reason.")
            }
        } catch {
            ELOG("WebServerBootstrapTask: failed to start web server (impl=\(impl)): \(error.localizedDescription)")
        }
#else
        ILOG("WebServerBootstrapTask: PVWebServer not available on this target")
#endif
    }
}
