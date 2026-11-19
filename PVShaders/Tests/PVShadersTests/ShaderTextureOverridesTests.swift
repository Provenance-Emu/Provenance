//
//  ShaderTextureOverridesTests.swift
//  PVShadersTests
//
//  Textures handed to a library preset in place of its own.
//

import Foundation
import Testing
@testable import PVShaders

@Suite("ShaderTextureOverrides")
struct ShaderTextureOverridesTests {

    @Test("Texture overrides with the same key and data are equal")
    func overridesEquality() {
        let a = ShaderTextureOverrides(key: "studio|1920x1080", textures: ["BORDER": Data([1, 2])])
        #expect(a == ShaderTextureOverrides(key: "studio|1920x1080", textures: ["BORDER": Data([1, 2])]))
        #expect(a != ShaderTextureOverrides(key: "studio|3840x2160", textures: ["BORDER": Data([1, 2])]))
    }
}
