//
//  GLenum+Extensions.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/12/25.
//

import OpenGLES

// MARK: - GLenum Extensions
public extension GLenum {
    /// Convert GLenum to String
    public var toString: String {
        switch self {
        case GLenum(GL_UNSIGNED_BYTE): return "GL_UNSIGNED_BYTE"
        case GLenum(GL_BGRA): return "GL_BGRA"
        case GLenum(GL_RGBA): return "GL_RGBA"
        case GLenum(GL_RGB): return "GL_RGB"
        case GLenum(GL_RGB8): return "GL_RGB8"
        case GLenum(GL_RGB565): return "GL_RGB565"
        case GLenum(GL_RGB5_A1): return "GL_RGB5_A1"
        case GLenum(GL_RGB10_A2): return "GL_RGB10_A2"
        case GLenum(GL_RGB10_A2UI): return "GL_RGB10_A2UI"
        case GLenum(GL_UNSIGNED_SHORT_4_4_4_4): return "GL_UNSIGNED_SHORT_4_4_4_4"
            // Add more cases as needed
        default: return String(format: "0x%04X", self)
        }
    }
}
