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

        // Start optional always on WebDav server using enviroment variable
        // See XCode run scheme enviroment varialbes settings. 
    func isWebDavServerEnvironmentVariableSet() -> Bool {
        // Note: ENV variables are only passed when when from XCode scheme.
        // Users clicking the app icon won't be passed this variable when run outside of XCode
        let buildConfiguration = ProcessInfo.processInfo.environment["ALWAYS_ON_WEBDAV"]
        return buildConfiguration == "1"
    }

    func startOptionalWebDavServer() {
#if canImport(PVWebServer)
        // Check if the user setting is set or the optional ENV variable
        if Defaults[.webDavAlwaysOn] || isWebDavServerEnvironmentVariableSet() {
            Task {
                await PVWebServerManager.shared.refreshFeatureFlag()
                do {
                    _ = try await PVWebServerManager.shared.start()
                } catch {
                    ELOG("startOptionalWebDavServer: \(error.localizedDescription)")
                }
            }
        }
#endif
    }

}
