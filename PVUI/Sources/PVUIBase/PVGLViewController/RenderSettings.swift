//
//  RenderSettings.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/17/24.
//

import PVSettings

@frozen
@usableFromInline
struct RenderSettings: Sendable {
    var openGLFilterMode: OpenGLFilterModeOption = .none
    var metalFilterMode: MetalFilterModeOption = .none

    var smoothingEnabled = false
    var scalingMode: ScalingMode = .aspectFit
    var videoBufferSize: CGSize = .zero
    var videoBufferPixelFormat: GLenum = GLenum(GL_RGB)
    var videoBufferPixelType: GLenum = GLenum(GL_RGB8)
    var videoBuffer: UnsafeRawPointer? = nil

    /// Convenience shim — true when `scalingMode == .nativeResolution`.
    var nativeScaleEnabled: Bool {
        get { scalingMode == .nativeResolution }
        set { if newValue { scalingMode = .nativeResolution } }
    }
}
