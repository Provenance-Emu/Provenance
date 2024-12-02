//
//  GenesisOptions.swift
//  PVGenesis
//
//  Created by Joseph Mattiello on 2/7/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport


extension PVGearcolecoCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVGearcolecoCoreOptions.options
    }
}

@objc
public final class PVGearcolecoCoreOptions: NSObject, CoreOptions, Sendable {
    
    /*
     { "gearcoleco_timing", "Refresh Rate (restart); Auto|NTSC (60 Hz)|PAL (50 Hz)" },
     { "gearcoleco_aspect_ratio", "Aspect Ratio (restart); 1:1 PAR|4:3 DAR|16:9 DAR" },
     { "gearcoleco_overscan", "Overscan; Disabled|Top+Bottom|Full (284 width)|Full (320 width)" },
     { "gearcoleco_up_down_allowed", "Allow Up+Down / Left+Right; Disabled|Enabled" },
     { "gearcoleco_no_sprite_limit", "No Sprite Limit; Disabled|Enabled" },
     { "gearcoleco_spinners", "Spinner support; Disabled|Super Action Controller|Wheel Controller|Roller Controller" },
     { "gearcoleco_spinner_sensitivity", "Spinner Sensitivity; 1|2|3|4|5|6|7|8|9|10" },
     */
    
    enum Options {
        enum System {
            static var noSpriteLimit: CoreOption {
                .bool(.init(
                    title: "No sprite limit.",
                    description: "Allow more sprites on screen per scanline than original hardware. May cause glitching in some games, reduce sprite flicker in others.",
                    requiresRestart: true),
                      defaultValue: false)}
            
            static var allOptions: [CoreOption] { [noSpriteLimit] }
        }
        
        enum Video {
            static var overscan: CoreOption {
                .enumeration(.init(
                    title: "Video Overscan",
                    description: "",
                    requiresRestart: true),
                             values:[
                                .init(title: "Disabled", description: "No borders", value: 0),
                                .init(title: "Top+Bottom", description: "Top+Bottom borders only", value: 1),
                                .init(title: "Full (284 width)", description: "Full (284 width)", value: 2),
                                .init(title: "Full (320 width)", description: "Full (320 width)", value: 3)
                             ],
                             defaultValue: 0)}
            
            static var allOptions: [CoreOption] { [overscan] }
        }
    }
    
    public static var options: [CoreOption] {
        var options = [CoreOption]()

        // MARK: -- System
        let systemOptions: CoreOption = .group(.init(title: "System",
                                                      description: nil),
                                                subOptions: Options.System.allOptions)

        
        // MARK: -- Video
        let videoOptions: CoreOption = .group(.init(title: "Video",
                                                      description: nil),
                                                subOptions: Options.Video.allOptions)

        options.append(contentsOf: [systemOptions, videoOptions])
        return options
    }
}

@objc
extension PVGearcolecoCoreOptions {
    @objc public static var no_sprite_limit: Bool { valueForOption(Options.System.noSpriteLimit).asBool }
    @objc public static var overscan: Int { valueForOption(Options.Video.overscan).asInt! }
}

//@objc public extension PVGenesisEmulatorCore {
//    @objc var dualJoystickOption: Bool { PVGenesisEmulatorCore.valueForOption(PVGenesisEmulatorCore.dualJoystickOption).asBool }
//
//    @objc var controllerPak1Option: Int { PVGenesisEmulatorCore.valueForOption(PVGenesisEmulatorCore.controllerPak1).asInt ?? 1 }
//    @objc var controllerPak2Option: Int { PVGenesisEmulatorCore.valueForOption(PVGenesisEmulatorCore.controllerPak2).asInt ?? 1 }
//    @objc var controllerPak3Option: Int { PVGenesisEmulatorCore.valueForOption(PVGenesisEmulatorCore.controllerPak3).asInt ?? 1 }
//    @objc var controllerPak4Option: Int { PVGenesisEmulatorCore.valueForOption(PVGenesisEmulatorCore.controllerPak4).asInt ?? 1 }
//
//    func parseOptions() {
//        self.dualJoystick = dualJoystickOption
//        self.setMode(controllerPak1Option, forController: 0)
//        self.setMode(controllerPak2Option, forController: 1)
//        self.setMode(controllerPak3Option, forController: 2)
//        self.setMode(controllerPak4Option, forController: 3)
//    }
//}
