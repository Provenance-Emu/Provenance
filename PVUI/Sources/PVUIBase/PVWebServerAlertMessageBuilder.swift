//
//  PVWebServerAlertMessageBuilder.swift
//  PVUI
//
//  Created by Joseph Mattiello on 5/29/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import PVWebServer

// MARK: - Wiki / alert message (shared)

/// Builds the standard “wiki + URLs” body used in Web Server Active alerts.
public enum PVWebServerAlertMessageBuilder {
    static func wikiMessage(http: String, dav: String) -> String {
        """
        Read about how to import ROMs on the Provenance wiki at:
        https://wiki.provenance-emu.com

        Upload/Download files to your device at:

        \(http)  ᵂᵉᵇᵁᴵ
        \(dav)  ᵂᵉᵇᴰᴬⱽ
        """
    }

    public static func wikiMessageFromManager() async -> String {
        let http = await PVWebServerManager.shared.serverURL?.absoluteString ?? "null"
        let dav = await PVWebServerManager.shared.webDAVURL?.absoluteString ?? "null"
        return wikiMessage(http: http, dav: dav)
    }
}
