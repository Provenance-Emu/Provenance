//
//  PVTGBDualCore+Options.swift
//  PVTGBDualCore
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVLogging
import libatari800
import PVEmulatorCore

extension PVAtari800: @preconcurrency CoreOptional {
    @MainActor public static var options: [CoreOption] {
        var options = [CoreOption]()
 
        #warning("TODO: Impliment this the options")
        let coreGroup = CoreOption.group(.init(title: "Core",
                                                description: nil),
                                          subOptions: [sioAccelerationOption])


        let videoGroup = CoreOption.group(.init(title: "Video",
                                                description: nil),
                                          subOptions: [videoScaleOption, videoArtifcatingOption])


        options.append(videoGroup)

        return options
    }

    // MARK: ---- Core ---- //
    
    // MARK - atari800_sioaccel
    
    @MainActor static let sioAccelerationOption = CoreOption.bool(.init(title: "SIO Acceleration",
                                                      description: "This enables ALL SIO acceleration.  Enabled improves loading speed for Disk and Cassette images.  Disable only for protected disk (.ATX) and protected cassette images.  Reboot required if change made while loading a cassette image",
                                                      requiresRestart: true), defaultValue: true)
    
    // MARK: ----- Video ------ //
    
    // MARK: - atari800_resolution

#warning("TODO: Impliment this the options")
    @MainActor static let videoScaleValues: [CoreOptionMultiValue] = CoreOptionMultiValue.values(fromArray:
        [
            "336x240",   // 0
            "320x240",   // 1
            "384x240",   // 2
            "384x272",   // 3
            "384x288",   // 4
            "400x300",   // 5
    ])
    
    @MainActor static var videoScaleOption: CoreOption = {
        .multi(.init(
                title: "Video Scaling",
                description: "Scale from the original screen size"),
            values: videoScaleValues)
    }()
    
    
    // MARK: - atari800_artifacting_mode
#warning("TODO: Impliment this the options")
    @MainActor static let videoArtifcatingValues: [CoreOptionMultiValue] = CoreOptionMultiValue.values(fromArray:
        [
            "none",         // 0
            "blue/brown 1", // 1
            "blue/brown 2", // 2
            "GTIA",         // 3
            "CTIA",         // 4
    ])
    
    @MainActor static var videoArtifcatingOption: CoreOption = {
        .multi(.init(
                title: "Hi-Res Artifacting Mode",
                description: "Set Hi-Res Artifacting mode used. Typically dependant on the actual emulated system. Pick the color combination that pleases you."),
            values: videoArtifcatingValues)
    }()

    @MainActor
    public func get(variable: String) -> Any? {
        switch variable {
        case "atari800_resolution":
            return Self.valueForOption(Self.sioAccelerationOption).asBool
        case "atari800_resolution":
            switch Self.valueForOption(Self.videoScaleOption).asInt ?? 0 {
            case 0: return "336x240"
            case 1: return "320x240"
            case 2: return "384x240"
            case 3: return "384x272"
            case 4: return "384x288"
            case 5: return "400x300"
            default: return "336x240"
            }
        case "atari800_artifacting_mode":
            switch Self.valueForOption(Self.videoArtifcatingOption).asInt ?? 0 {
            case 0: return "None"
            case 1: return "Blue/Brown 1"
            case 2: return "Blue/Brown 2"
            case 3: return "GTIA"
            case 4: return "CTIA"
            default: return "None"
            }
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
