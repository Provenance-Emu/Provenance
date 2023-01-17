//
//  PVStellaGameCore+Options.swift
//  PVStella
//
//  Created by Joseph Mattiello on 1/17/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
/*
 { "stella_console", "Console display; auto|ntsc|pal|secam|ntsc50|pal60|secam60" },
 { "stella_palette", "Palette colors; standard|z26|user|custom" },
 { "stella_filter", "TV effects; disabled|composite|s-video|rgb|badly adjusted" },
 { "stella_ntsc_aspect", "NTSC aspect %; par|100|101|102|103|104|105|106|107|108|109|110|111|112|113|114|115|116|117|118|119|120|121|122|123|124|125|50|75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91|92|93|94|95|96|97|98|99" },
 { "stella_pal_aspect", "PAL aspect %; par|100|101|102|103|104|105|106|107|108|109|110|111|112|113|114|115|116|117|118|119|120|121|122|123|124|125|50|75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91|92|93|94|95|96|97|98|99" },
 { "stella_crop_hoverscan", "Crop horizontal overscan; disabled|enabled" },
 { "stella_stereo", "Stereo sound; auto|off|on" },
 { "stella_phosphor", "Phosphor mode; auto|off|on" },
 { "stella_phosphor_blend", "Phosphor blend %; 60|65|70|75|80|85|90|95|100|0|5|10|15|20|25|30|35|40|45|50|55" },
 { "stella_paddle_joypad_sensitivity", "Paddle joypad sensitivity; 3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|1|2" },
 { "stella_paddle_analog_sensitivity", "Paddle analog sensitivity; 20|21|22|23|24|25|26|27|28|29|30|0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19" },
 */

extension PVStellaGameCore: CoreOptional {
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
