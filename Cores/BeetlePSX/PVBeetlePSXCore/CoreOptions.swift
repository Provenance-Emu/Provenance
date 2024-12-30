//
//  CoreOptions.swift
//  Core-VirtualJaguar
//
//  Created by Joseph Mattiello on 9/19/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation
//import PVSupport
import PVCoreBridge
import PVCoreObjCBridge
import PVEmulatorCore

@objc
public final class PVBeetlePSXCoreOptions: NSObject, CoreOptions, Sendable {

    public static var options: [CoreOption] {
        var options = [CoreOption]()

        let coreGroup = CoreOption.group(.init(title: "Core", description: nil),
                                         subOptions: Options.Core.allOptions)
        let videoGroup = CoreOption.group(.init(title: "Video", description: nil),
                                          subOptions: Options.Video.allOptions)
        options.append(coreGroup)
        options.append(videoGroup)

        return options
    }
    
    enum Options {
        enum Core {
            
            static var allOptions: [CoreOption] { [] }
        }
        enum Video {
            static var renderer: CoreOption {
                .enumeration(.init(
                    title: "Video Renderer",
                    description: "Which video backend to render with.",
                    requiresRestart: true),
                             // hardware, hardware_gl, hardware_vk, software
                             values:[
                                .init(title: "Hardware", description: "", value: 0),
                                .init(title: "Hardware GL", description: "OpenGL/ES", value: 1),
                                .init(title: "Hardware Vulkan", description: "Vulkan", value: 2),
                                .init(title: "Software", description: "Software Renderer", value: 3),
                             ],
                             defaultValue: 2)
            }
            
            static var rendererUpscale: CoreOption {
                .enumeration(.init(
                    title: "Video Interal Upscale",
                    description: "Render to a larger internal buffer before scaling to screen.",
                    requiresRestart: true),
                             values:[
                                .init(title: "1x", description: "", value: 0),
                                .init(title: "2x", description: "", value: 1),
                                .init(title: "4x", description: "", value: 2),
                                .init(title: "8x", description: "", value: 3),
                                .init(title: "16x", description: "", value: 4),
                             ],
                             defaultValue: 1)
            }
            
            
            static var rendererSoftwareFramebuffer: CoreOption {
                .bool(.init(title: "Software Framebuffer", description: "Enable accurate emulation of framebuffer effects (e.g. motion blur, FF7 battle swirl) when using hardware renderers by running a copy of the software renderer at native resolution in the background. If disabled, these operations are omitted (OpenGL) or rendered on the GPU (Vulkan). Disabling can improve performance but may cause severe graphical errors. Leave enabled if unsure.", requiresRestart: true), defaultValue: true)
            }
            
            static var allOptions: [CoreOption] { [renderer, rendererSoftwareFramebuffer] }
        }
    }
}

extension PVBeetlePSXCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVBeetlePSXCoreOptions.options
    }
}

@objc
public extension PVBeetlePSXCoreOptions {
    @objc static var video_renderer: NSInteger { valueForOption(Options.Video.renderer) }
    @objc static var video_renderer_upscale: NSInteger { valueForOption(Options.Video.rendererUpscale) }
    @objc static var video_renderer_software_framebuffer: Bool { valueForOption(Options.Video.rendererSoftwareFramebuffer) }
}

//
//extension PVBeetlePSXCore: CoreActions {
//	public var coreActions: [CoreAction]? {
//		let bios = CoreAction(title: "Use Jaguar BIOS", options: nil)
//		let fastBlitter =  CoreAction(title: "Use fast blitter", options:nil)
//		return [bios, fastBlitter]
//	}
//
//	public func selected(action: CoreAction) {
//		DLOG("\(action.title), \(String(describing: action.options))")
//	}
//}
