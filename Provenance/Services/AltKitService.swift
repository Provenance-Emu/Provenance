//
//  AltKitService.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/30/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(AltKit)
import AltKit
#endif


class AltKitService {
    public func start() {

        ServerManager.shared.startDiscovering()

        ServerManager.shared.autoconnect { result in
            switch result
            {
            case .failure(let error): print("Could not auto-connect to server.", error)
            case .success(let connection):
                connection.enableUnsignedCodeExecution { result in
                    switch result
                    {
                    case .failure(let error): print("Could not enable JIT compilation.", error)
                    case .success:
                        print("Successfully enabled JIT compilation!")
                        ServerManager.shared.stopDiscovering()
                    }
                    
                    connection.disconnect()
                }
            }
        }
    }
}
