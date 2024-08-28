//
//  EmulatorCoreVideoDelegate.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

#if canImport(OpenGLES) || canImport(OpenGL)
@objc public enum GLESVersion: Int {
    @objc(GLESVersion1)
    case version1
    @objc(GLESVersion2)
    case version2
    @objc(GLESVersion3)
    case version3
}
#endif

@objc public protocol EmulatorCoreVideoDelegate {
    var emulationFPS: Double { get }
    var renderFPS: Double { get }
    var isDoubleBuffered: Bool { get }
    var rendersToOpenGL: Bool { get }
#if canImport(OpenGLES) || canImport(OpenGL)
    var glesVersion: GLESVersion { get }
    var pixelFormat: GLenum  { get }
    var pixelType: GLenum  { get }
    var internalPixelFormat: GLenum { get }
    var depthFormat: GLenum  { get }
#endif
    var screenRect: CGRect  { get }
    var aspectSize: CGSize  { get }
    var videoBufferSize: CGSize { get }
    var alwaysUseMetal: Bool { get }

    var renderDelegate: PVRenderDelegate? { get set }
}

public extension EmulatorCoreVideoDelegate {
    var emulationFPS: Double { 0.0 }
    var renderFPS: Double { 0.0 }
    var isDoubleBuffered: Bool { false }
    var rendersToOpenGL: Bool { false }
#if canImport(OpenGLES) || canImport(OpenGL)
    var glesVersion: GLESVersion  { .version3 }
    var pixelFormat: GLenum  { 0 }
    var pixelType: GLenum {  0 }
    var internalPixelFormat: GLenum  { 0 }
    var depthFormat: GLenum { 0 }
#endif
    var screenRect: CGRect { .zero }
    var aspectSize: CGSize { .zero }
    var bufferSize: CGSize { .zero }
    var alwaysUseMetal: Bool { false }
}
