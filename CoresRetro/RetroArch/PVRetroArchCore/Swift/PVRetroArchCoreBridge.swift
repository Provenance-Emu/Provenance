//
//  PVRetroArchCoreBridge.swift
//  PVRetroArch
//
//  Created by Joseph Mattiello on 2/19/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVArchiving
import PVLogging

@objc public extension PVRetroArchCoreBridge {
    @objc func extractRAR(atPath: String, toDestination destination: String, overwrite: Bool) -> Bool {
        return PVArchiveHelper.shared.extractRAR(atPath, toDestination: destination, overwrite: overwrite)
    }
}
