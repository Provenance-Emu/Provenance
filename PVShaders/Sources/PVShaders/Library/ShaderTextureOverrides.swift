//
//  ShaderTextureOverrides.swift
//  PVShaders
//
//  Textures handed to a library preset in place of its own.
//

import Foundation

/// Replaces named textures of a library preset (its LUTs) when it loads.
public struct ShaderTextureOverrides: Sendable, Equatable {
    /// Identifies this set of textures: a preset loaded with another key is reloaded.
    public let key: String
    /// Encoded images (PNG or JPEG) by the preset's texture name.
    public let textures: [String: Data]

    public init(key: String, textures: [String: Data]) {
        self.key = key
        self.textures = textures
    }
}
