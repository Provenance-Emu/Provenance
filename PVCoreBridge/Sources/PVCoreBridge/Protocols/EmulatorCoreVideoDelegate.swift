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
    @objc dynamic var alwaysUseMetal: Bool { get }
    @objc dynamic var aspectSize: CGSize  { get }
    @objc dynamic var emulationFPS: Double { get }
    @objc dynamic var isDoubleBuffered: Bool { get }
    @objc dynamic var renderFPS: Double { get }
    @objc dynamic var rendersToOpenGL: Bool { get }
    @objc dynamic var screenRect: CGRect  { get }
    @objc dynamic var videoBuffer: UnsafeMutableRawPointer? { get }
    
    @objc dynamic var bufferSize: CGSize { get }
    
//    @objc dynamic var videoBufferSize: CGSize { get }
    
    @objc dynamic weak var renderDelegate: PVRenderDelegate? { get set }
    
    @objc func executeFrame()
    @objc optional func swapBuffers()

#if canImport(OpenGLES) || canImport(OpenGL)
    @objc dynamic var depthFormat: GLenum  { get }
    @objc dynamic var glesVersion: GLESVersion { get }
    @objc dynamic var internalPixelFormat: GLenum { get }
    @objc dynamic var pixelFormat: GLenum  { get }
    @objc dynamic var pixelType: GLenum  { get }
#endif
}

//public extension EmulatorCoreVideoDelegate {
//    var emulationFPS: Double { 0.0 }
//    var renderFPS: Double { 0.0 }
//    var isDoubleBuffered: Bool { false }
//    var rendersToOpenGL: Bool { false }
//#if canImport(OpenGLES) || canImport(OpenGL)
//    var glesVersion: GLESVersion  { .version3 }
//    var pixelFormat: GLenum  { 0 }
//    var pixelType: GLenum {  0 }
//    var internalPixelFormat: GLenum  { 0 }
//    var depthFormat: GLenum { 0 }
//#endif
//    var screenRect: CGRect { .zero }
//    var aspectSize: CGSize { .zero }
//    var bufferSize: CGSize { .zero }
//    var alwaysUseMetal: Bool { false }
//}
