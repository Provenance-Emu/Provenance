//
//  GenesisOptions.swift
//  PVGenesis
//
//  Created by Joseph Mattiello on 2/7/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

extension PVGenesisEmulatorCore: CoreOptional {
    
    enum Options {
        enum System {
            static let noSpriteLimit: CoreOption =
                .bool(.init(
                    title: "No sprite limit.",
                    description: "Allow more sprites on screen per scanline than original hardware. May cause glitching in some games, reduce sprite flicker in others.",
                    requiresRestart: true),
                defaultValue: false)

            static var allOptions: [CoreOption] = [noSpriteLimit]
        }
        
        enum Video {
            static let gg_extra: CoreOption =
                .bool(.init(
                    title: "GameGear extra space.",
                    description: "Show extended Game Gear screen (256x192).",
                    requiresRestart: true),
                defaultValue: true)
            
            static let overscan: CoreOption =
                .enumeration(.init(
                    title: "Video Overscan",
                    description: "",
                    requiresRestart: true),
                             values:[
                               .init(title: "None", description: "No borders", value: 0),
                               .init(title: "Vertical", description: "Vertical borders only", value: 1),
                               .init(title: "Horizontal", description: "horizontal borders only", value: 2),
                               .init(title: "Full", description: "Full borders", value: 3),
                             ],
                defaultValue: 0)
            
            static var allOptions: [CoreOption] = [overscan, gg_extra]
        }
        
        enum Sound {
            static let hq_fm: CoreOption =
                .bool(.init(
                    title: "HQ FM",
                    description: "High-quality FM resampling (slower)",
                    requiresRestart: true),
                      defaultValue: true)
 
            static let hq_pqg: CoreOption =
                .bool(.init(
                    title: "HQ PSG",
                    description: "High-quality PSG resampling (slower)",
                    requiresRestart: true),
                      defaultValue: true)
            
            static let filter: CoreOption =
                .bool(.init(
                    title: "Audio Filtering",
                    description: "Apply a low-pass filter",
                    requiresRestart: true),
                      defaultValue: true)
            
            
            static let ym2413: CoreOption =
                .enumeration(.init(
                    title: "YM2413 chip",
                    description: "FM sound used in the FM Sound Unit add-on to the Sega Mark III and later.",
                    requiresRestart: true),
                             values:[
                               .init(title: "Off", description: "", value: 0),
                               .init(title: "On", description: "", value: 1),
                               .init(title: "Auto", description: "", value: 2),
                             ],
                defaultValue: 2)
            
            static let ym2612: CoreOption =
                .enumeration(.init(
                    title: "YM2612 chip",
                    description: "The Yamaha YM2612 is a six-channel FM synthesizer. Originally only in JPN models.",
                    requiresRestart: true),
                             values:[
                               .init(title: "Discrete", description: "", value: 0),
                               .init(title: "Integrated", description: "", value: 1),
                               .init(title: "Enhanced", description: "", value: 2),
                             ],
                defaultValue: 0)
            
        //            static var filter_range: CoreOption = {
//                .enumeration(.init(
//                    title: "Video Overscan",
//                    description: "If 1st player controller has dual joysticks, use the right joystick as player 2. For games, such as GoldenEye, that support using 2 N64 controllers for single player input.",
//                    requiresRestart: true),
//                             values:[
//                               .init(title: "Original", description: "", value: 0),
//                               .init(title: "Model1 VA2 US", description: "55%", value: 1),
//                             ])
//            }()
            
            static var allOptions: [CoreOption] = [hq_fm, hq_pqg, filter, ym2413, ym2612]
        }
    }
    
    public static var options: [CoreOption] {
        var options = [CoreOption]()

        // MARK: -- System
        let systemOptions: CoreOption = .group(.init(title: "System",
                                                      description: nil),
                                                subOptions: Options.System.allOptions)

        
        // MARK: -- Sound
        let soundOptions: CoreOption = .group(.init(title: "Sound",
                                                      description: nil),
                                                subOptions: Options.Sound.allOptions)
            
        // MARK: -- Video
        let videoOptions: CoreOption = .group(.init(title: "Video",
                                                      description: nil),
                                                subOptions: Options.Video.allOptions)

        options.append(contentsOf: [systemOptions, videoOptions, soundOptions])
        return options
    }
}

@objc
extension PVGenesisEmulatorCore {
    // TODO: move these generall accessors somewhere global, maybe use dynamicC
    @objc
    static public func bool(forOption option: String) -> Bool {
        return storedValueForOption(Bool.self, option) ?? false
    }
    
    @objc
    static public func int(forOption option: String) -> Int {
        let value = storedValueForOption(Int.self, option)
        return value ?? 0
    }
    
    @objc
    static public func float(forOption option: String) -> Float {
        let value = storedValueForOption(Float.self, option)
        return value ?? 0
    }
    
    @objc
    static public func string(forOption option: String) -> String? {
        let value = storedValueForOption(String.self, option)
        return value
    }
    
    public static var hq_fm: Bool { valueForOption(Options.Sound.hq_fm).asBool }
    public static var hq_psg: Bool { valueForOption(Options.Sound.hq_fm).asBool }
    public static var filter: Int { valueForOption(Options.Sound.hq_fm).asInt! }
    public static var ym2413: Int { valueForOption(Options.Sound.ym2413).asInt! }
    public static var ym2612: Int { valueForOption(Options.Sound.ym2612).asInt! }

    public static var no_sprite_limit: Bool { valueForOption(Options.System.noSpriteLimit).asBool }
    
    public static var gg_extra: Bool { valueForOption(Options.Video.gg_extra).asBool }
    public static var overscan: Int { valueForOption(Options.Video.overscan).asInt! }
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
