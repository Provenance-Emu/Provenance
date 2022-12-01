//
//  PVEmulatorCoreHelper.swift
//  PVRuntime
//
//  Created by Stuart Carnie on 1/12/2022.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVRuntime

@objc class PVEmulatorCoreHelper: NSObject, OEGameCoreHelper {
    
    let use_metal: Bool = PVSettingsModel.shared.debugOptions.useMetal
    
    
    func setVolume(_ value: Float) {
        
    }
    
    func setPauseEmulation(_ pauseEmulation: Bool) {
        
    }
    
    func setEffectsMode(_ mode: PVRuntime.OEGameCoreEffectsMode) {
        
    }
    
    func setOutputBounds(_ rect: CGRect) {
        
    }
    
    func setBackingScaleFactor(_ newBackingScaleFactor: CGFloat) {
        
    }
    
    func setAdaptiveSyncEnabled(_ enabled: Bool) {
        
    }
    
    func setShaderURL(_ url: URL, parameters: [String : NSNumber]?, completionHandler block: @escaping (Error?) -> Void) {
        
    }
    
    func setShaderParameterValue(_ value: CGFloat, forKey key: String) {
        
    }
    
    func setupEmulation(completionHandler handler: @escaping (OEIntSize, OEIntSize) -> Void) {
        
    }
    
    func startEmulation(completionHandler handler: @escaping () -> Void) {
        
    }
    
    func resetEmulation(completionHandler handler: @escaping () -> Void) {
        
    }
    
    func stopEmulation(completionHandler handler: @escaping () -> Void) {
        
    }
    
    func saveStateToFile(at fileURL: URL, completionHandler block: @escaping (Bool, Error?) -> Void) {
        
    }
    
    func loadStateFromFile(at fileURL: URL, completionHandler block: @escaping (Bool, Error?) -> Void) {
        
    }
    
    func setCheat(_ cheatCode: String, withType type: String, enabled: Bool) {
        
    }
    
    func setDisc(_ discNumber: UInt) {
        
    }
    
    func changeDisplay(withMode displayMode: String) {
        
    }
    
    func insertFile(at url: URL, completionHandler block: @escaping (Bool, Error?) -> Void) {
        
    }
    
    func captureOutputImage(completionHandler block: @escaping (CGImage) -> Void) {
        
    }
    
    func captureSourceImage(completionHandler block: @escaping (CGImage) -> Void) {
        
    }
    
    
}
