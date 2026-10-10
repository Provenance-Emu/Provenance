//
//  PVVisualBoyAdvance+Options.swift
//  PVVisualBoyAdvance
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVLogging

/*
 bool skipBios = false;
 bool cpuDisableSfx = false;
 bool speedHack = false;
 bool skipSaveGameBattery = false;
 bool skipSaveGameCheats = false;
 */

@objc
@objcMembers
public class VisualBoyAdvanceOptions: NSObject, CoreOptional {
    public static var options: [CoreOption] {
        var options = [CoreOption]()

        let consoleGroup = CoreOption.group(.init(title: "Console",
                                                description: nil),
                                            subOptions: Options.Console.allCases)

        let savesGroup = CoreOption.group(.init(title: "Save Data",
                                                  description: nil),
                                          subOptions: Options.Saves.allCases)

        options.append(consoleGroup)
        options.append(savesGroup)

        return options
    }

    public enum Options: CaseIterable {

        static var allCases: [CoreOption] {
            Console.allCases + Saves.allCases
        }
        
        public enum Console: CaseIterable {
            static var allCases: [CoreOption] {
                [skipBiosOption, cpuDisableSfxOption, speedHackOption]
            }
            
            // MARK: Console
            static var skipBiosOption: CoreOption {
                .bool(.init(title: "skipBios",
                            description: "Skip Bios",
                            requiresRestart: true), defaultValue: false)
            }

            static var cpuDisableSfxOption: CoreOption {
                .bool(.init(title: "cpuDisableSfx",
                            description: "CPU Disable SFX",
                            requiresRestart: true), defaultValue: false)
            }

            static var speedHackOption: CoreOption {
                .bool(.init(title: "speedHack",
                            description: "Speed hack",
                            requiresRestart: true), defaultValue: false)
            }
        }

        public enum Saves: CaseIterable {
            static var allCases: [CoreOption] {
                [skipSaveGameBatteryOption, skipSaveGameCheatsOption]
            }
            // MARK: Saves
            static var skipSaveGameBatteryOption: CoreOption {
                .bool(.init(title: "skipSaveGameBattery",
                            description: "Don't save/load game battery state with saves.",
                            requiresRestart: true), defaultValue: false)
            }

            static var skipSaveGameCheatsOption: CoreOption {
                .bool(.init(title: "skipSaveGameCheats",
                            description: "Don't save/load game cheat state with saves.",
                            requiresRestart: true), defaultValue: false)
            }
        }
    }
}

public extension VisualBoyAdvanceOptions {
    
    @objc static var skipBios: Bool { valueForOption(Options.Console.skipBiosOption) }
    @objc static var cpuDisableSfx: Bool { valueForOption(Options.Console.cpuDisableSfxOption) }
    @objc static var speedHack: Bool { valueForOption(Options.Console.speedHackOption) }
    @objc static var skipSaveGameBattery: Bool { valueForOption(Options.Saves.skipSaveGameBatteryOption) }
    @objc static var skipSaveGameCheats: Bool { valueForOption(Options.Saves.skipSaveGameCheatsOption) }

    @objc(getVariable:)
    static func get(variable: String) -> Any? {
        switch variable {
        case "skipBios":
            return valueForOption(Options.Console.skipBiosOption).asBool
        case "cpuDisableSfx":
            return valueForOption(Options.Console.cpuDisableSfxOption).asBool
        case "speedHack":
            return valueForOption(Options.Console.speedHackOption).asBool
        case "skipSaveGameBattery":
            return valueForOption(Options.Saves.skipSaveGameBatteryOption).asBool
        case "skipSaveGameCheats":
            return valueForOption(Options.Saves.skipSaveGameCheatsOption).asBool
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
