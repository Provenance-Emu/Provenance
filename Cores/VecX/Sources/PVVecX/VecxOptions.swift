//
//  PVVecx+Options.swift
//  PVVecx
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVLogging

@objc
@objcMembers
public class VecxOptions: NSObject, CoreOptional {
    public static var options: [CoreOption] {
        var options = [CoreOption]()
        
        #if HAS_GPU
        let renderingGroup = CoreOption.group(.init(title: "Rendering",
                                                  description: nil),
                                            subOptions: Options.Rendering.allCases)
        options.append(renderingGroup)
        #endif
        
        let displayGroup = CoreOption.group(.init(title: "Display",
                                                description: nil),
                                          subOptions: Options.Display.allCases)
        options.append(displayGroup)
        
        return options
    }
    
    public enum Options {
        #if HAS_GPU
        public enum Rendering: CaseIterable {
            static var allCases: [CoreOption] {
                [useHardwareOption, resolutionHWOption, lineBrightnessOption,
                 lineWidthOption, bloomBrightnessOption, bloomWidthOption]
            }
            
            static var useHardwareOption: CoreOption {
                .enumeration(.init(title: "vecx_use_hw",
                                 description: "Configure the rendering method. Requires restart.",
                                 requiresRestart: true),
                           values: [
                            .init(title: "Software", value: 0),
                            .init(title: "Hardware", value: 1)
                           ],
                           defaultValue: 1)
            }
            
            static var resolutionHWOption: CoreOption {
                .enumeration(.init(title: "vecx_res_hw",
                                 description: "Hardware rendering resolution"),
                           values: [
                            .init(title: "434x540", value: 0),
                            .init(title: "515x640", value: 1),
                            .init(title: "580x720", value: 2),
                            .init(title: "618x768", value: 3),
                            .init(title: "824x1024", value: 4),
                            .init(title: "845x1050", value: 5),
                            .init(title: "869x1080", value: 6),
                            .init(title: "966x1200", value: 7),
                            .init(title: "1159x1440", value: 8),
                            .init(title: "1648x2048", value: 9)
                           ],
                           defaultValue: 4)
            }
            
            static var lineBrightnessOption: CoreOption {
                .range(.init(title: "vecx_line_brightness",
                           description: "How bright the lines are"),
                      range: .init(defaultValue: 4, min: 1, max: 9),
                      defaultValue: 4)
            }
            
            static var lineWidthOption: CoreOption {
                .range(.init(title: "vecx_line_width",
                           description: "How wide the lines are. Set higher in low resolutions to avoid aliasing"),
                      range: .init(defaultValue: 4, min: 1, max: 9),
                      defaultValue: 4)
            }
            
            static var bloomBrightnessOption: CoreOption {
                .range(.init(title: "vecx_bloom_brightness",
                           description: "How bright the bloom is. 0 to switch bloom off"),
                      range: .init(defaultValue: 4, min: 0, max: 9),
                      defaultValue: 4)
            }
            
            static var bloomWidthOption: CoreOption {
                .enumeration(.init(title: "vecx_bloom_width",
                                 description: "Bloom width relative to the line width"),
                           values: [
                            .init(title: "2x", value: 0),
                            .init(title: "3x", value: 1),
                            .init(title: "4x", value: 2),
                            .init(title: "6x", value: 3),
                            .init(title: "8x", value: 4),
                            .init(title: "10x", value: 5),
                            .init(title: "12x", value: 6),
                            .init(title: "14x", value: 7),
                            .init(title: "16x", value: 8)
                           ],
                           defaultValue: 4)
            }
        }
        #endif
        
        public enum Display: CaseIterable {
            static var allCases: [CoreOption] {
                [resolutionMultiOption, scaleXOption, scaleYOption, shiftXOption, shiftYOption]
            }
            
            static var resolutionMultiOption: CoreOption {
                .range(.init(title: "vecx_res_multi",
                           description: "Internal resolution multiplier"),
                      range: .init(defaultValue: 1, min: 1, max: 4),
                      defaultValue: 1)
            }
            
            static var scaleXOption: CoreOption {
                .enumeration(.init(title: "vecx_scale_x",
                                 description: "Scale vector display horizontally"),
                           values: Array(stride(from: 0.845, through: 1.01, by: 0.005)).enumerated().map {
                            .init(title: String(format: "%.3f", $0.element), value: $0.offset)
                           },
                           defaultValue: 31) // Index of "1.000"
            }
            
            static var scaleYOption: CoreOption {
                .enumeration(.init(title: "vecx_scale_y",
                                 description: "Scale vector display vertically"),
                           values: Array(stride(from: 0.845, through: 1.01, by: 0.005)).enumerated().map {
                            .init(title: String(format: "%.3f", $0.element), value: $0.offset)
                           },
                           defaultValue: 31) // Index of "1.000"
            }
            
            static var shiftXOption: CoreOption {
                .enumeration(.init(title: "vecx_shift_x",
                                 description: "Horizontal shift"),
                           values: Array(stride(from: -0.03, through: 0.03, by: 0.005)).enumerated().map {
                            .init(title: String(format: "%.3f", $0.element), value: $0.offset)
                           },
                           defaultValue: 6) // Index of "0.000"
            }
            
            static var shiftYOption: CoreOption {
                .enumeration(.init(title: "vecx_shift_y",
                                 description: "Vertical shift"),
                           values: Array(stride(from: -0.035, through: 0.1, by: 0.005)).enumerated().map {
                            .init(title: String(format: "%.3f", $0.element), value: $0.offset)
                           },
                           defaultValue: 7) // Index of "0.000"
            }
        }
    }
}

// MARK: - Variable Accessors
public extension VecxOptions {
    #if HAS_GPU
    @objc static var useHardware: String { valueForOption(Options.Rendering.useHardwareOption).asString }
    @objc static var resolutionHW: String { valueForOption(Options.Rendering.resolutionHWOption).asString }
    @objc static var lineBrightness: Int { valueForOption(Options.Rendering.lineBrightnessOption).asInt ?? 4 }
    @objc static var lineWidth: Int { valueForOption(Options.Rendering.lineWidthOption).asInt ?? 4 }
    @objc static var bloomBrightness: Int { valueForOption(Options.Rendering.bloomBrightnessOption).asInt ?? 4 }
    @objc static var bloomWidth: String { valueForOption(Options.Rendering.bloomWidthOption).asString }
    #endif
    
    @objc static var resolutionMulti: Int { valueForOption(Options.Display.resolutionMultiOption).asInt ?? 1 }
    @objc static var scaleX: String { valueForOption(Options.Display.scaleXOption).asString }
    @objc static var scaleY: String { valueForOption(Options.Display.scaleYOption).asString }
    @objc static var shiftX: String { valueForOption(Options.Display.shiftXOption).asString }
    @objc static var shiftY: String { valueForOption(Options.Display.shiftYOption).asString }
    
    @objc(getVariable:)
    static func get(variable: String) -> Any? {
        switch variable {
        #if HAS_GPU
        case "vecx_use_hw": return useHardware
        case "vecx_res_hw": return resolutionHW
        case "vecx_line_brightness": return lineBrightness
        case "vecx_line_width": return lineWidth
        case "vecx_bloom_brightness": return bloomBrightness
        case "vecx_bloom_width": return bloomWidth
        #endif
        case "vecx_res_multi": return resolutionMulti
        case "vecx_scale_x": return scaleX
        case "vecx_scale_y": return scaleY
        case "vecx_shift_x": return shiftX
        case "vecx_shift_y": return shiftY
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
