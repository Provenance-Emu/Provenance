//
//  PVPCSXRearmedCore.swift
//  PVPCSXRearmedCore
//
//  Created by Joseph Mattiello on 10/06/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVCoreBridgeRetro

@objc
@objcMembers
open class PVPCSXRearmedCore: PVEmulatorCore {

    let _bridge: PVPCSXRearmedCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVPCSXRearmedCore: PVPSXSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVPSXButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVPSXButton, forPlayer player: Int) {
        (_bridge as! PVPSXSystemResponderClient).didRelease(button, forPlayer: player)
    }
}


extension PVPCSXRearmedCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PCSXRearmedOptions.options
    }
}

@objc
@objcMembers
public class PCSXRearmedOptions: NSObject, CoreOptions {

    public static var options: [CoreOption] {
        var options = [CoreOption]()
        
        let coreGroup = CoreOption.group(
            .init(title: "CORE",
                  description: nil),
            subOptions: Options.Core.allCases)

        let cpuGroup = CoreOption.group(
            .init(title: "CPU",
                  description: nil),
            subOptions: Options.CPU.allCases)

        let videoGroup = CoreOption.group(
            .init(title: "Video",
                  description: nil),
            subOptions: Options.Video.allCases )

        options.append(coreGroup)
        options.append(cpuGroup)
        options.append(videoGroup)

        return options
    }
    
    enum Options: CaseIterable {
        static var allCases: [CoreOption] {
            Core.allCases + CPU.allCases + Video.allCases
        }
        enum Core: CaseIterable {
            static var allCases: [CoreOption] {
                [showBootLogo]
            }
            
            static var showBootLogo: CoreOption {
                .bool(
                    .init(title: "Show boot BIOS logo",
                          description: "Disable to skip PSX boot logo."
                         ),
                    defaultValue: true)}
        }
        
        enum CPU: CaseIterable {
            static var allCases: [CoreOption] {
                [jitOption]
            }
            
            /// JIT
            static var jitOption: CoreOption {
                .bool(
                    .init(title: "Dynamic JIT",
                          description: "Enable dynamic JIT for the CPU core."
                         ),
                    defaultValue: false)}
        }

        enum Video: CaseIterable {
            static var allCases: [CoreOption] {
                [gpuNeonEnhancmentOption, gpuNeonEnhancmentSpeedHackOption, frameSkipOption, gpuThreadedRendering, frameDupingOption]
            }
            
            /// Enhanced resolution
            static var gpuNeonEnhancmentOption: CoreOption {
                .bool(
                    .init(title: "Enhanced Resolution (Slow)",
                          description: "Render games that do not already run in high resolution video modes (480i, 512i) at twice the native internal resolution. Improves the fidelity of 3D models at the expense of increased performance requirements. 2D elements are generally unaffected by this setting."
                         ),
                    defaultValue: true)}
            
            static var gpuNeonEnhancmentSpeedHackOption: CoreOption {
                .bool(
                    .init(title: "Enhanced Resolution Speed Hack",
                          description: "Improves performance when 'Enhanced Resolution (Slow)' is enabled, but reduces compatibility and may cause rendering errors."
                         ),
                    defaultValue: true)}
            
            /// Frame-skip
            static var frameSkipOption: CoreOption {
                .enumeration(.init(title: "Frame skip"),
                             values: [
                                .init(title: "Off", value: 0),
                                .init(title: "Auto", value: 1),
                                .init(title: "Manual", value: 2)
                             ], defaultValue: 1)}
            
            /// GPU Threading
            static var gpuThreadedRendering: CoreOption {
                .enumeration(.init(title: "GPU Threading",
                                   description: "Enable duplication of frames when skipping."),
                             values: [
                                .init(title: "Disabled", value: 0),
                                .init(title: "Syncronous", value: 1),
                                .init(title: "Asyncronous", value: 2)
                             ], defaultValue: 2)}
            
            /// Frame duplicatin
            static var frameDupingOption: CoreOption {
                .bool(.init(title: "Frame Duplication",
                                  description: "Enable duplication of frames when skipping."),
                      defaultValue: true)}
        }
    }
}

@objc public extension PCSXRearmedOptions {
    /// Core
    @objc static var showBootLogo: Bool { valueForOption(Options.Core.showBootLogo) }
    
    /// CPU
    @objc static var jit: Bool { valueForOption(Options.CPU.jitOption) }

    /// Video
    @objc static var gpuNeonEnhancment: Bool { valueForOption(Options.Video.gpuNeonEnhancmentOption) }
    @objc static var gpuNeonEnhancmenSpeedHack: Bool { valueForOption(Options.Video.gpuNeonEnhancmentSpeedHackOption) }

    @objc static var frameSkip: Int { valueForOption(Options.Video.frameSkipOption) }
    @objc static var gpuTheading: Int { valueForOption(Options.Video.gpuThreadedRendering) }
    @objc static var frameDuplication: Bool { valueForOption(Options.Video.frameDupingOption) }

}
