//
//  PVEmulatorCore+Saves.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import PVCoreBridge
import PVLogging

@objc extension PVEmulatorCore: EmulatorCoreSavesSerializer {
    
    @objc(saveStateToFileAtPath:error:) open func saveStateSync(toFileAtPath path: String) throws {
        throw EmulatorCoreSavesSerializerError.coreDoesNotSupportSaves
    }
    
    @objc(loadStateToFileAtPath:error:) open func loadStateSync(toFileAtPath path: String) throws {
        throw EmulatorCoreSavesSerializerError.coreDoesNotSupportSaves
    }

    @objc open func saveState(toFileAtPath path: String) async throws {
        try saveStateSync(toFileAtPath: path)
    }
    
    @objc open func loadState(fromFileAtPath path: String) async throws {
        try loadStateSync(toFileAtPath: path)
    }
}
