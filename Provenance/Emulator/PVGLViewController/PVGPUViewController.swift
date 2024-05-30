//
//  PVGPUViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/27/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation

#if os(macOS)
public typealias BaseViewController = NSViewController
#elseif targetEnvironment(macCatalyst)
public typealias BaseViewController = UIViewController
#else
import GLKit
public typealias BaseViewController = GLKViewController
#endif

@usableFromInline
struct float2 {
    var x: Float
    var y: Float
}

@usableFromInline
struct float4 {
    var x: Float
    var y: Float
    var z: Float
    var w: Float
}

@usableFromInline
struct CRT_Data {
    var DisplayRect: float4
    var EmulatedImageSize: float2
    var FinalRes: float2
}

//#pragma pack(push,4)
//@_rawLayout(size: 16, alignment: 4)
@usableFromInline
struct SimpleCrtUniforms {
    var mame_screen_dst_rect: float4
    var mame_screen_src_rect: float4
    var curv_vert: Float = 5.0   // 5.0 default  1.0, 10.0
    var curv_horiz: Float = 4.0   // 4.0 default 1.0, 10.0
    var curv_strength: Float = 0.25 // 0.25 default 0.0, 1.0
    var light_boost: Float = 1.2  // 1.3 default 0.1, 3.0
    var vign_strength: Float = 0.05 // 0.05 default 0.0, 1.0
    var zoom_out: Float = 1.1     // 1.1 default 0.01, 5.0
    var brightness: Float = 1.0  // 1.0 default 0.666, 1.333
};
//#pragma pack(pop)

@frozen
@usableFromInline
struct PVVertex {
    var x, y, z: GLfloat
    var u, v: GLfloat
}

//#define BUFFER_OFFSET(x) ((char *)NULL + (x))

@frozen
public struct RenderSettings {
    var crtFilterEnabled = false
    var lcdFilterEnabled = false
    var smoothingEnabled = false
}

@objc
@objcMembers
public class PVGPUViewController: BaseViewController {
    var screenType: String? = nil

    #if os(macOS) || targetEnvironment(macCatalyst)
    public var isPaused: Bool = false
    public var framesPerSecond: Double = 0
    public var timeSinceLastDraw: TimeInterval = 0
    #endif
}
