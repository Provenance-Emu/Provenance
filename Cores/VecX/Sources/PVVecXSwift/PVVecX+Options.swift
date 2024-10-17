//
//  PVVecXGameCore+Options.swift
//  PVVecX
//
//  Created by Joseph Mattiello on 1/17/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVLogging

/*

 */
#if false
extension PVVecXGameCore: CoreOptional {
    public static var options: [CoreOption] = {
        var options = [CoreOption]()

        let videoGroup = CoreOption.group(.init(title: "Video",
                                                description: nil),
                                          subOptions: [videoCropOverscan])

        let audioGroup = CoreOption.group(.init(title: "Audio",
                                                description: nil),
                                          subOptions: [audioStereoOption])

        options.append(videoGroup)
        options.append(audioGroup)

        return options
    }()

    static var audioStereoOption: CoreOption = {
        .enumeration(.init(title: "Stereo sound"),
                     values: [
                        .init(title: "Auto", value: 0),
                        .init(title: "On", value: 1),
                        .init(title: "Off", value: 2)
                     ])
    }()

    static var videoCropOverscan: CoreOption = {
        .bool(.init(title: "Crop overscan",
                    description: "Crop horizontal oversca", requiresRestart: true), defaultValue: false)
    }()

    @objc(getVariable:)
    public func get(variable: String) -> Any? {
        switch variable {
        case "stella_stereo":
            switch Self.valueForOption(Self.videoCropOverscan).asInt ?? 0 {
            case 0: return "auto"
            case 1: return "on"
            case 2: return "off"
            default: return "auto"
            }
        case "stella_crop_hoverscan":
            return Self.valueForOption(Self.videoCropOverscan).asBool
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
#endif
