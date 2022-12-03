//
//  PVEmulatorCoreHelper.swift
//  PVRuntime
//
//  Created by Stuart Carnie on 1/12/2022.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVRuntime

public class PVEmulatorCoreHelper: OEGameCoreHelper {
    public var description: String { core.description }
    
    public var renderFPS: Double { core.renderFPS }
    public var frameInterval: Double { core.frameInterval }
    
    public var controller1: GCController? { get { core.controller1 } set { core.controller1 = newValue } }
    public var controller2: GCController? { get { core.controller2 } set { core.controller2 = newValue } }
    public var controller3: GCController? { get { core.controller3 } set { core.controller3 = newValue } }
    public var controller4: GCController? { get { core.controller4 } set { core.controller4 = newValue } }
    
    public var romName: String? {
        get { core.romName }
        set { core.romName = newValue }
    }
    
    public var saveStatesPath: String? {
        get { core.saveStatesPath }
        set { core.saveStatesPath = newValue }
    }
    
    public var batterySavesPath: String? {
        get { core.batterySavesPath }
        set { core.batterySavesPath = newValue }
    }
    
    public var biosPath: String? {
        get { core.biosPath }
        set { core.biosPath = newValue }
    }
    
    public var systemIdentifier: String? {
        get { core.systemIdentifier }
        set { core.systemIdentifier = newValue }
    }
    
    public var coreIdentifier: String? {
        get { core.coreIdentifier }
        set { core.coreIdentifier = newValue }
    }
    
    public var romMD5: String? {
        get { core.romMD5 }
        set { core.romMD5 = newValue }
    }
    
    public var romSerial: String? {
        get { core.romSerial }
        set { core.romSerial = newValue }
    }
    
    public var screenType: String? {
        get { core.screenType }
        set { core.screenType = newValue }
    }
    
    public var supportsSaveStates: Bool { core.supportsSaveStates }
    
    public var responderClient: AnyObject? { core }
    public var viewController: AnyObject? { gpuViewController }
    
    let use_metal: Bool = PVSettingsModel.shared.debugOptions.useMetal
    private(set) lazy var gpuViewController: PVGPUViewController = use_metal ? PVMetalViewController(emulatorCore: core) : PVGLViewController(emulatorCore: core)
    let core: PVEmulatorCore
    
    var audioInited: Bool = false
    private(set) lazy var gameAudio: OEGameAudio = {
        audioInited = true
        return OEGameAudio(core: core)
    }()
    
    public init(_ core: PVEmulatorCore) {
        self.core = core
        self.core.audioDelegate = self
    }
    
    public func setVolume(_ value: Float) {
        gameAudio.volume = value
    }
    
    public weak var runStateDelegate: OEGameCoreHelperRunStateDelegate?
    
    public func setPauseEmulation(_ pauseEmulation: Bool) {
        gpuViewController.isPaused = pauseEmulation
        core.setPauseEmulation(pauseEmulation)
        if pauseEmulation {
            gameAudio.pause()
            runStateDelegate?.helper(self, didChangeState: .paused)
        } else {
            gameAudio.start()
            runStateDelegate?.helper(self, didChangeState: .running)
        }
    }
    
    public func setEffectsMode(_ mode: PVRuntime.OEGameCoreEffectsMode) {
        
    }
    
    public func setOutputBounds(_ rect: CGRect) {
        
    }
    
    public func setBackingScaleFactor(_ newBackingScaleFactor: CGFloat) {
        
    }
    
    public func setAdaptiveSyncEnabled(_ enabled: Bool) {
        
    }
    
    public func setShaderURL(_ url: URL, parameters: [String : NSNumber]?, completionHandler block: @escaping (Error?) -> Void) {
        
    }
    
    public func setShaderParameterValue(_ value: CGFloat, forKey key: String) {
        
    }
    
    public func loadFile(atPath path: String) throws {
        try core.loadFile(atPath: path)
    }
    
    public func setupEmulation(completionHandler handler: @escaping (OEIntSize, OEIntSize) -> Void) {
        
    }
    
    public func startEmulation(completionHandler handler: @escaping () -> Void) {
        gameAudio.start()
        core.startEmulation(completionHandler: handler)
        runStateDelegate?.helper(self, didChangeState: .running)
    }
    
    public func resetEmulation(completionHandler handler: @escaping () -> Void) {
        core.resetEmulation(completionHandler: handler)
    }
    
    public func stopEmulation(completionHandler handler: @escaping () -> Void) {
        core.stopEmulation(completionHandler: handler)
        runStateDelegate?.helper(self, didChangeState: .stopped)
    }
    
    public func saveStateToFile(at fileURL: URL, completionHandler block: @escaping (Bool, Error?) -> Void) {
        core.saveStateToFile(atPath: fileURL.path, completionHandler: block)
    }
    
    public func loadStateFromFile(at fileURL: URL, completionHandler block: @escaping (Bool, Error?) -> Void) {
        core.loadStateFromFile(atPath: fileURL.path, completionHandler: block)
    }
    
    public func setCheat(_ cheatCode: String, withType type: String, enabled: Bool) {
        
    }
    
    public func setDisc(_ discNumber: UInt) {
        
    }
    
    public func changeDisplay(withMode displayMode: String) {
        
    }
    
    public func insertFile(at url: URL, completionHandler block: @escaping (Bool, Error?) -> Void) {
        
    }
    
    public func captureOutputImage(completionHandler block: @escaping (CGImage) -> Void) {
        
    }
    
    public func captureSourceImage(completionHandler block: @escaping (CGImage) -> Void) {
        
    }
    
    public var features: AnyObject? { core as AnyObject }
}

extension PVEmulatorCoreHelper: PVAudioDelegate {
    public func audioSampleRateDidChange() {
        gameAudio.stop()
        gameAudio.start()
    }
}
