//
//  RenderSettings.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/17/24.
//

@frozen
@usableFromInline
struct RenderSettings: Sendable {
    var openGLFilterMode: OpenGLFilterModeOption = .none
    var metalFilterMode: MetalFilterModeOption = .none

    var smoothingEnabled = false
    var nativeScaleEnabled = false
    var videoBufferSize: CGSize = .zero
    var videoBufferPixelFormat: GLenum = GLenum(GL_RGB)
    var videoBufferPixelType: GLenum = GLenum(GL_RGB8)
    var videoBuffer: UnsafeMutableRawPointer? = nil
}
