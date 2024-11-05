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
    var mameScreenDstRect: SIMD4<Float>
    var mameScreenSrcRect: SIMD4<Float>
    var curvVert: Float = 5.0   // 5.0 default  1.0, 10.0
    var curvHoriz: Float = 4.0   // 4.0 default 1.0, 10.0
    var curvStrength: Float = 0.25 // 0.25 default 0.0, 1.0
    var lightBoost: Float = 1.2  // 1.3 default 0.1, 3.0
    var vignStrength: Float = 0.05 // 0.05 default 0.0, 1.0
    var zoomOut: Float = 1.1     // 1.1 default 0.01, 5.0
    var brightness: Float = 1.0  // 1.0 default 0.666, 1.333
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
