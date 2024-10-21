//
//  RenderSettings.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/17/24.
//

@frozen
@usableFromInline
struct RenderSettings: Sendable {
    var crtFilterEnabled = false
    var lcdFilterEnabled = false
    var smoothingEnabled = false
    
    var videoBufferSize: CGSize = .zero
    var videoBufferPixelFormat: GLenum = GLenum(GL_RGB)
    var videoBufferPixelType: GLenum = GLenum(GL_RGB8)
    var videoBuffer: UnsafeMutableRawPointer? = nil
}
