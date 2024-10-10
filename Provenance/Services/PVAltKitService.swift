//
//  PVAltKitService.swift
//  Provenance
//
//  Created by Joseph Mattiello on 6/12/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
#if canImport(SideKit)
import SideKit
import PVLogging

struct PVAltKitService {
    static let shared = PVAltKitService()

    private init() {}

    func start() {
#if !targetEnvironment(macCatalyst) && !os(tvOS)
        SideKit.ServerManager.shared.startDiscovering()

        SideKit.ServerManager.shared.autoconnect { result in
            let connection = try? result.get()
            if connection == nil {
                let error = result.error as? NSError
                ELOG("Could not auto-connect to server. \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            DispatchQueue.global().async {
                connection?.enableUnsignedCodeExecution { result in
                    guard let success = try? result.get() else {
                        let error = result.error as? NSError
                        ELOG("Could not enable JIT compilation. \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }

                    ILOG("Successfully enabled JIT compilation!")
                    SideKit.ServerManager.shared.stopDiscovering()
                    
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
#endif
