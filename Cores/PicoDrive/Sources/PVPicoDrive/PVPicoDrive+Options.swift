//
//  PVPicoDrive+Options.swift
//  PVPicoDrive
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVLogging
import libpicodrive
import PVEmulatorCore

extension PVPicoDrive: @preconcurrency CoreOptional {
    public static var options: [CoreOption] {
        var options = [CoreOption]()

        let coreGroup = CoreOption.group(.init(title: "Core",
                                                description: nil),
                                          subOptions: [
                                            inputDevice1Option,
                                            inputDevice2Option,
                                            spriteLimitOption,
                                            ramCartOption,
                                            regionOption,
                                            overclock68kOption
                                          ])

        let videoGroup = CoreOption.group(.init(title: "Video",
                                                description: nil),
                                          subOptions: [
                                            aspectRatioOption,
                                            overscanOption
                                          ])

        options.append(coreGroup)
        options.append(videoGroup)

        return options
    }

    // MARK: - Core Options

    static var inputDevice1Option: CoreOption {
        .enumeration(.init(title: "picodrive_input1",
                          description: "Input device 1"),
                     values: [
                        .init(title: "3 button pad", value: 0),
                        .init(title: "6 button pad", value: 1),
                        .init(title: "None", value: 2),
                     ],
                     defaultValue: 0)
    }

    static var inputDevice2Option: CoreOption {
        .enumeration(.init(title: "picodrive_input2",
                          description: "Input device 2"),
                     values: [
                        .init(title: "3 button pad", value: 0),
                        .init(title: "6 button pad", value: 1),
                        .init(title: "None", value: 2),
                     ],
                     defaultValue: 0)
    }

    static var spriteLimitOption: CoreOption {
        .bool(.init(title: "picodrive_sprlim",
                    description: "No sprite limit"),
              defaultValue: false)
    }

    static var ramCartOption: CoreOption {
        .bool(.init(title: "picodrive_ramcart",
                    description: "MegaCD RAM cart"),
              defaultValue: false)
    }

    static var regionOption: CoreOption {
        .enumeration(.init(title: "picodrive_region",
                          description: "Region"),
                     values: [
                        .init(title: "Auto", value: 0),
                        .init(title: "Japan NTSC", value: 1),
                        .init(title: "Japan PAL", value: 2),
                        .init(title: "US", value: 3),
                        .init(title: "Europe", value: 4),
                     ],
                     defaultValue: 0)
    }

    static var overclock68kOption: CoreOption {
        .enumeration(.init(title: "picodrive_overclk68k",
                          description: "68k overclock"),
                     values: [
                        .init(title: "disabled", value: 0),
                        .init(title: "+25%", value: 1),
                        .init(title: "+50%", value: 2),
                        .init(title: "+75%", value: 3),
                        .init(title: "+100%", value: 4),
                        .init(title: "+200%", value: 5),
                        .init(title: "+400%", value: 6),
                     ],
                     defaultValue: 0)
    }

    // MARK: - Video Options

    static var aspectRatioOption: CoreOption {
        .enumeration(.init(title: "picodrive_aspect",
                          description: "Core-provided aspect ratio"),
                     values: [
                        .init(title: "PAR", value: 0),
                        .init(title: "4/3", value: 1),
                        .init(title: "CRT", value: 2),
                     ],
                     defaultValue: 0)
    }

    static var overscanOption: CoreOption {
        .bool(.init(title: "picodrive_overscan",
                    description: "Show Overscan"),
              defaultValue: false)
    }

    @objc(getVariable:)
    public static func get(variable: String) -> Any? {
        switch variable {
        case "picodrive_input1":
            switch valueForOption(inputDevice1Option).asInt ?? 0 {
            case 0: return "3 button pad"
            case 1: return "6 button pad"
            case 2: return "None"
            default: return "3 button pad"
            }
        case "picodrive_input2":
            switch valueForOption(inputDevice2Option).asInt ?? 0 {
            case 0: return "3 button pad"
            case 1: return "6 button pad"
            case 2: return "None"
            default: return "3 button pad"
            }
        case "picodrive_sprlim":
            return valueForOption(spriteLimitOption).asBool ? "enabled" : "disabled"
        case "picodrive_ramcart":
            return valueForOption(ramCartOption).asBool ? "enabled" : "disabled"
        case "picodrive_region":
            switch valueForOption(regionOption).asInt ?? 0 {
            case 0: return "Auto"
            case 1: return "Japan NTSC"
            case 2: return "Japan PAL"
            case 3: return "US"
            case 4: return "Europe"
            default: return "Auto"
            }
        case "picodrive_aspect":
            switch valueForOption(aspectRatioOption).asInt ?? 0 {
            case 0: return "PAR"
            case 1: return "4/3"
            case 2: return "CRT"
            default: return "PAR"
            }
        case "picodrive_overscan":
            return valueForOption(overscanOption).asBool ? "enabled" : "disabled"
        case "picodrive_overclk68k":
            switch valueForOption(overclock68kOption).asInt ?? 0 {
            case 0: return "disabled"
            case 1: return "+25%"
            case 2: return "+50%"
            case 3: return "+75%"
            case 4: return "+100%"
            case 5: return "+200%"
            case 6: return "+400%"
            default: return "disabled"
            }
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
