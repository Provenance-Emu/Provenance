//
//  PVAltKitService.swift
//  Provenance
//
//  Created by Joseph Mattiello on 6/12/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import AltKit
import os

struct PVAltKitService {
    static let shared = PVAltKitService()

    private init() {}

    func start() {
#if !targetEnvironment(macCatalyst) && !targetEnvironment(tvOS)
        ALTServerManager.shared.startDiscovering()

        ALTServerManager.shared.autoconnect { connection, error in
            if let error = error as NSError? {
                os_log("Could not auto-connect to server: %@", log: .altKitService, type: .error, error)
            }

            DispatchQueue.global().async {
                connection?.enableUnsignedCodeExecution { success, _ in
                    if success {
                        os_log("Successfully enabled JIT compilation!", log: .altKitService, type: .info)
                        ALTServerManager.shared.stopDiscovering()
                    } else {
                        os_log("Could not enable JIT compilation.", log: .altKitService, type: .error)
                    }

                    DispatchQueue.main.async {
                        connection?.disconnect()
                    }
                }
            }
        }
        #else
        WLOG("PVAltKitService not supported on this platform.")
#endif
    }
}
