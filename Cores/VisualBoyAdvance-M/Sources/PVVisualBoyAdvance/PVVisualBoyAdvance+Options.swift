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
//import libvisualboyadvance

/*
 bool skipBios = false;
 bool cpuDisableSfx = false;
 bool speedHack = false;
 bool skipSaveGameBattery = false;
 bool skipSaveGameCheats = false;
 */
#warning("Need to test how to set this values into EMU and then enable")
#if false
extension PVVisualBoyAdvanceCore: CoreOptional {
    public static var options: [CoreOption] = {
        var options = [CoreOption]()

        let consoleGroup = CoreOption.group(.init(title: "Console",
                                                description: nil),
                                            subOptions: [skipBiosOption, cpuDisableSfxOption, speedHackOption])

        let savesGroup = CoreOption.group(.init(title: "Save Data",
                                                  description: nil),
                                            subOptions: [skipSaveGameBatteryOption, skipSaveGameCheatsOption])


        options.append(consoleGroup)

        return options
    }()

    // MARK: Console
    static var skipBiosOption: CoreOption = {
        .bool(.init(title: "skipBios",
                    description: "Skip Bios",
                    requiresRestart: true), defaultValue: false)
    }()

    static var cpuDisableSfxOption: CoreOption = {
        .bool(.init(title: "cpuDisableSfx",
                    description: "CPU Disable SFX",
                    requiresRestart: true), defaultValue: false)
    }()

    static var speedHackOption: CoreOption = {
        .bool(.init(title: "speedHack",
                    description: "Speed hack",
                    requiresRestart: true), defaultValue: false)
    }()

    // MARK: Saves
    static var skipSaveGameBatteryOption: CoreOption = {
        .bool(.init(title: "skipSaveGameBattery",
                    description: "Don't save/load game battery state with saves.",
                    requiresRestart: true), defaultValue: false)
    }()

    static var skipSaveGameCheatsOption: CoreOption = {
        .bool(.init(title: "skipSaveGameCheats",
                    description: "Don't save/load game cheat state with saves.",
                    requiresRestart: true), defaultValue: false)
    }()

    @objc(getVariable:)
    public func get(variable: String) -> Any? {
        switch variable {
        case "skipBios":
            return Self.valueForOption(Self.skipBiosOption).asBool
        case "cpuDisableSfx":
            return Self.valueForOption(Self.cpuDisableSfxOption).asBool
        case "speedHack":
            return Self.valueForOption(Self.speedHackOption).asBool
        case "skipSaveGameBattery":
            return Self.valueForOption(Self.skipSaveGameBatteryOption).asBool
        case "skipSaveGameCheats":
            return Self.valueForOption(Self.skipSaveGameCheatsOption).asBool
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
#endif
