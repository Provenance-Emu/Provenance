//
//  WebServerBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

#if canImport(PVWebServer)
import PVWebServer
#endif

/// Sets up web-server notifications and, on tvOS, starts the upload and WebDAV
/// servers (the only way to get files onto tvOS).
///
/// Depends on `BootstrapKey.logging`. Provides `BootstrapKey.webServer`.
@MainActor
struct WebServerBootstrapTask: BootstrapTask {
    var name: String { "WebServer" }
    var dependencies: [String] { [BootstrapKey.logging] }
    var provisions: [String] { [BootstrapKey.webServer] }

    /// Back-reference to the app delegate needed to call
    /// `setupWebServerNotifications()`.
    private weak var delegate: PVAppDelegate?

    init(delegate: PVAppDelegate) {
        self.delegate = delegate
    }

    func execute() async throws {
#if canImport(PVWebServer)
        delegate?.setupWebServerNotifications()
#if os(tvOS)
        await PVWebServerManager.shared.refreshFeatureFlag()
        do {
            let ok = try await PVWebServerManager.shared.start()
            if ok {
                ILOG("WebServerBootstrapTask: tvOS servers started (PVWebServerManager)")
            } else {
                WLOG("WebServerBootstrapTask: tvOS servers did not start")
            }
        } catch {
            ELOG("WebServerBootstrapTask: failed to start servers: \(error.localizedDescription)")
        }
#else
        ILOG("WebServerBootstrapTask: Web server notifications registered")
#endif
#else
        ILOG("WebServerBootstrapTask: PVWebServer not available on this target")
#endif
    }
}
