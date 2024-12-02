//
//  PVGPUViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/27/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import Defaults
import PVSettings
#if canImport(UIKit)
import UIKit
#endif

#if os(macOS)
public typealias BaseViewController = NSViewController
#elseif targetEnvironment(macCatalyst)
public typealias BaseViewController = UIViewController
#else
import GLKit
#if USE_METAL
public typealias BaseViewController = UIViewController  /// Use UIViewController for Metal
#else
public typealias BaseViewController = GLKViewController /// Use GLKViewController for OpenGL
#endif
#endif

@usableFromInline
struct float2: Sendable {
    var x: Float
    var y: Float
}

@usableFromInline
struct float4: Sendable {
    var x: Float
    var y: Float
    var z: Float
    var w: Float
}

@usableFromInline
struct CRT_Data: Sendable {
    var DisplayRect: SIMD4<Float> // float4
    var EmulatedImageSize: SIMD2<Float> //float2
    var FinalRes: SIMD2<Float> // float2
}

//#pragma pack(push,4)
//@_rawLayout(size: 16, alignment: 4)
@usableFromInline
struct SimpleCrtUniforms: Sendable {
    var mame_screen_dst_rect: SIMD4<Float>
    var mame_screen_src_rect: SIMD4<Float>
    var curv_vert: Float        = 5.0   // 5.0 default  1.0, 10.0
    var curv_horiz: Float       = 4.0   // 4.0 default 1.0, 10.0
    var curv_strength: Float    = 0.25 // 0.25 default 0.0, 1.0
    var light_boost: Float      = 1.3  // 1.3 default 0.1, 3.0
    var vign_strength: Float    = 0.05 // 0.05 default 0.0, 1.0
    var zoom_out: Float         = 1.1     // 1.1 default 0.01, 5.0
    var brightness: Float       = 1.0  // 1.0 default 0.666, 1.333
}

//#pragma pack(pop)

@frozen
@usableFromInline
struct PVVertex {
    var x, y, z: GLfloat
    var u, v: GLfloat
}

//#define BUFFER_OFFSET(x) ((char *)NULL + (x))

import Metal
import CoreGraphics
#if canImport(OpenGL)
import OpenGL
#endif
#if canImport(OpenGLES)
import OpenGLES.ES3
#endif

@objc
@objcMembers
public class PVGPUViewController: BaseViewController {
    var screenType: String = "crt"

    #if os(macOS) || targetEnvironment(macCatalyst)
    public var isPaused: Bool = false
    public var framesPerSecond: Double = 0
    public var timeSinceLastDraw: TimeInterval = 0
    #endif
}

@usableFromInline
struct LineTronUniforms: Sendable {
    var SourceSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var OutputSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var width_scale: Float     /// Line width multiplier
    var line_time: Float       /// Time in seconds (0 = now, 1 = 1sec ago)
    var falloff: Float         /// Line edge falloff
    var strength: Float        /// Line brightness
}

@usableFromInline
struct MegaTronUniforms: Sendable {
    var SourceSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var OutputSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var MASK: Float                   /// 0=none, 1=RGB, 2=RGB(2), 3=RGB(3)
    var MASK_INTENSITY: Float         /// Mask intensity (0.0-1.0)
    var SCANLINE_THINNESS: Float      /// Scanline thickness
    var SCAN_BLUR: Float             /// Scanline blur
    var CURVATURE: Float             /// Screen curvature
    var TRINITRON_CURVE: Float       /// 0=normal curve, 1=trinitron style
    var CORNER: Float                /// Corner size
    var CRT_GAMMA: Float             /// CRT gamma correction
}

@usableFromInline
struct UlTronUniforms: Sendable {
    var SourceSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var OutputSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var hardScan: Float              /// Scanline intensity
    var hardPix: Float               /// Pixel sharpness
    var warpX: Float                 /// Horizontal curvature
    var warpY: Float                 /// Vertical curvature
    var maskDark: Float              /// Dark color mask
    var maskLight: Float             /// Light color mask
    var shadowMask: Float            /// Mask type (0-4)
    var brightBoost: Float           /// Brightness boost
    var hardBloomScan: Float         /// Bloom scanline
    var hardBloomPix: Float          /// Bloom pixel
    var bloomAmount: Float           /// Bloom strength
    var shape: Float                 /// Curvature shape
}

@usableFromInline
struct GameBoyUniforms: Sendable {
    var SourceSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var OutputSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var dotMatrix: Float              /// Dot matrix effect intensity
    var contrast: Float               /// Screen contrast
    var palette: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)  /// Classic Game Boy palette
}

@usableFromInline
struct VHSUniforms: Sendable {
    var SourceSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var OutputSize: SIMD4<Float>      /// x,y = size, z,w = 1/size
    var time: Float                   /// Current time for animated effects
    var noiseAmount: Float            /// Static noise intensity
    var scanlineJitter: Float         /// Horizontal line displacement
    var colorBleed: Float            /// Vertical color bleeding
    var trackingNoise: Float         /// Vertical noise bands
    var tapeWobble: Float           /// Horizontal wobble amount
    var ghosting: Float             /// Double-image effect
    var vignette: Float            /// Screen edge darkening
}
