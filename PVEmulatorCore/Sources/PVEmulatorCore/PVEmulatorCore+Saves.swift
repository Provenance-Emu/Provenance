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
        if self.supportsSaveStates {
            try await (self as? ObjCCoreBridge)?.saveState(toFileAtPath: path)
        } else {
            throw EmulatorCoreSavesSerializerError.coreDoesNotSupportSaves
        }
    }
    
    @objc open func loadState(fromFileAtPath path: String) async throws {
        if self.supportsSaveStates {
            try await (self as? ObjCCoreBridge)?.loadState(fromFileAtPath: path)
        } else {
            throw EmulatorCoreSavesSerializerError.coreDoesNotSupportSaves
        }
    }
}
