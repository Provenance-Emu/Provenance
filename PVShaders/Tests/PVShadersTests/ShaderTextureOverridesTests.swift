//
//  TVBezelShaderTests.swift
//  PVShadersTests
//
//  The parameter values that place a tube inside the bezel presets.
//

import CoreGraphics
import Foundation
import Testing
@testable import PVShaders

@Suite("TVBezelShader")
struct TVBezelShaderTests {

    private func entry(_ path: String, category: String = "crt", parameters: [ShaderParameterDescriptor]) -> ShaderCatalogEntry {
        ShaderCatalogEntry(id: .slang(path), name: path, category: category, passes: 1, historyFrames: 0,
                           usesFeedback: false, lutCount: 0, parameters: parameters, directory: nil)
    }

    private func parameter(_ name: String, initial: Float = 1, minimum: Float = 0, maximum: Float = 1) -> ShaderParameterDescriptor {
        ShaderParameterDescriptor(name: name, label: name, initial: initial, minimum: minimum, maximum: maximum, step: 1)
    }

    @Test("A 4:3 tube 72 % of the scene's height")
    func geometry() throws {
        let values = TVBezelShader.geometryValues(tubeAspect: 4.0 / 3.0, tubeHeightFraction: 0.72)
        // Tube height as a percentage of the scene's width: 0.72 * 9 / 16.
        #expect(abs(try #require(values["fr_zoom"]) - 40.5) < 0.001)
        let aspect = try #require(values["fr_aspect_x"]) / (try #require(values["fr_aspect_y"]))
        #expect(abs(aspect - 4.0 / 3.0) < 0.0001)
        #expect(values["fr_center_x"] == 0)
        #expect(values["bz_center_y"] == 0)
    }

    @Test("The tube's aspect is the TV's, whatever was asked of the frame")
    func geometryWinsOverFrame() {
        let values = TVBezelShader.values(frame: ["fr_zoom": 99, "fr_aspect_x": 16, "bz_red": 40],
                                          tubeAspect: 4.0 / 3.0, tubeHeightFraction: 0.72, lightsRoom: false)
        #expect(abs((values["fr_zoom"] ?? 0) - 40.5) < 0.001)
        #expect(abs((values["fr_aspect_x"] ?? 0) - 8 * 4.0 / 3.0) < 0.0001)
        #expect(values["bz_red"] == 40)
    }

    @Test("Room light uses the ambient preset with its built-in tube look turned down")
    func roomLight() {
        let lit = TVBezelShader.values(frame: [:], tubeAspect: 4.0 / 3.0, tubeHeightFraction: 0.7, lightsRoom: true)
        #expect(lit["CN_MASK_STRENGTH"] == 0)
        #expect(lit["CN_InputGamma"] == lit["CN_OutputGamma"])
        #expect(TVBezelShader.presetID(lightsRoom: true) == TVBezelShader.ambientID)

        let unlit = TVBezelShader.values(frame: [:], tubeAspect: 4.0 / 3.0, tubeHeightFraction: 0.7, lightsRoom: false)
        #expect(unlit["CN_MASK_STRENGTH"] == nil)
        #expect(TVBezelShader.presetID(lightsRoom: false) == TVBezelShader.bezelOnlyID)
    }

    @Test("A TV may override the neutral tube values on purpose")
    func frameOverridesNeutral() {
        let values = TVBezelShader.values(frame: ["CN_VIG_TOGGLE": 1], tubeAspect: 1, tubeHeightFraction: 0.5, lightsRoom: true)
        #expect(values["CN_VIG_TOGGLE"] == 1)
    }

    @Test("A filter's own curvature is switched off inside a TV")
    func curvatureOff() {
        let geom = entry("crt/crt-geom", parameters: [parameter("CURVATURE"), parameter("R", initial: 2, minimum: 0.1, maximum: 10)])
        #expect(TVBezelShader.curvatureOffValues(for: geom) == ["CURVATURE": 0])

        let lottes = entry("crt/crt-lottes", parameters: [parameter("warpX", initial: 0.031, maximum: 0.125),
                                                           parameter("warpY", initial: 0.041, maximum: 0.125)])
        #expect(TVBezelShader.curvatureOffValues(for: lottes) == ["warpX": 0, "warpY": 0])
    }

    @Test("A filter with no curvature switch is left alone")
    func noCurvature() {
        let plain = entry("crt/scanline", parameters: [parameter("SCANLINE_STRENGTH")])
        #expect(TVBezelShader.curvatureOffValues(for: plain).isEmpty)
        // A parameter that cannot be 0 is not a switch.
        let radius = entry("crt/other", parameters: [parameter("curvature", initial: 2, minimum: 1, maximum: 4)])
        #expect(TVBezelShader.curvatureOffValues(for: radius).isEmpty)
    }

    @Test("A built-in filter with its own curvature flattens the glass instead")
    func nativeCurvature() {
        let native = ShaderCatalogEntry(id: .native(.complexCRT), name: "Complex CRT", category: ShaderCatalog.nativeCategory,
                                        passes: 1, historyFrames: 0, usesFeedback: false, lutCount: 0,
                                        parameters: [parameter("complexCRTWarpX", initial: 0.03, maximum: 0.05)], directory: nil)
        #expect(TVBezelShader.bendsPictureItself(native))
        // A library filter is told to stop instead (curvatureOffValues), so the glass keeps its curve.
        let library = entry("crt/crt-geom", parameters: [parameter("CURVATURE")])
        #expect(!TVBezelShader.bendsPictureItself(library))
        let flat = ShaderCatalogEntry(id: .native(.lcd), name: "LCD", category: ShaderCatalog.nativeCategory,
                                      passes: 1, historyFrames: 0, usesFeedback: false, lutCount: 0,
                                      parameters: [parameter("lcdGridOpacity")], directory: nil)
        #expect(!TVBezelShader.bendsPictureItself(flat))
    }

    @Test("Filters with a frame of their own are recognised")
    func bezelFilters() {
        #expect(TVBezelShader.isBezelFilter(entry("bezel/uborder/uborder-koko-ambi", category: "bezel", parameters: [])))
        #expect(TVBezelShader.isBezelFilter(entry("border/sgb/sgb", category: "border", parameters: [])))
        #expect(!TVBezelShader.isBezelFilter(entry("crt/crt-geom", parameters: [])))
    }

    @Test("Texture overrides with the same key and data are equal")
    func overridesEquality() {
        let a = ShaderTextureOverrides(key: "studio|1920x1080", textures: ["BORDER": Data([1, 2])])
        #expect(a == ShaderTextureOverrides(key: "studio|1920x1080", textures: ["BORDER": Data([1, 2])]))
        #expect(a != ShaderTextureOverrides(key: "studio|3840x2160", textures: ["BORDER": Data([1, 2])]))
    }
}
