//
//  TVBezelScene.swift
//  PVUI
//
//  A TV made ready to draw: its preset, the values it runs with and its artwork.
//

import CoreGraphics
import Foundation
import PVLogging
import PVShaders

/// Everything the second draw stage needs for one TV on one display.
struct TVBezelScene: Sendable {
    /// The tube in the artwork's canvas points (`TVBezelArtwork.canvas`).
    let tubeRect: CGRect
    /// The bezel preset with this TV's values.
    let shader: ResolvedShader
    /// The cabinet and room, as the preset's background texture.
    let textures: ShaderTextureOverrides?

    /// The tube's width over its height: the shape the picture is fitted into.
    var tubeAspect: CGSize { tubeRect.size }

    /// Loads `bezel`'s artwork and draws it `scenePixelWidth` pixels wide. Slow: call it off
    /// the main thread. `nil` when the preset is not in the library or the artwork is bad.
    ///
    /// - Parameters:
    ///   - lightsRoom: use the preset that lights the room, falling back to the plain one
    ///     when the library does not have it.
    ///   - flatGlass: switch the glass's own curvature off.
    ///   - key: identifies this TV at this size (`ShaderTextureOverrides.key`).
    static func make(bezel: TVBezel, lightsRoom: Bool, flatGlass: Bool, scenePixelWidth: CGFloat,
                     key: String, catalog: ShaderCatalog = .shared) -> TVBezelScene? {
        if let presetID = bezel.presetID {
            guard let entry = catalog.entry(for: presetID) else { return nil }
            // Both standalone presets place a centred 4:3 tube at 37.8% of the scene width.
            let canvas = TVBezelArtwork.canvas
            let height = canvas.width * 0.378
            let width = height * 4 / 3
            let tube = CGRect(x: (canvas.width - width) / 2, y: (canvas.height - height) / 2,
                              width: width, height: height)
            let shader = ResolvedShader(entry: entry, values: [:], revision: key.hashValue)
            return TVBezelScene(tubeRect: tube, shader: shader, textures: nil)
        }
        let lit = lightsRoom && catalog.entry(for: TVBezelShader.ambientID) != nil
        guard let entry = catalog.entry(for: TVBezelShader.presetID(lightsRoom: lit)) else {
            ELOG("TV bezels: the shader library has no \(TVBezelShader.presetID(lightsRoom: lit))")
            return nil
        }
        let artwork: TVBezelArtwork
        do {
            artwork = try TVBezelArtwork(bezel: bezel)
        } catch {
            ELOG("TV bezels: artwork of '\(bezel.id)' is unusable: \(error)")
            return nil
        }
        guard let png = artwork.pngData(pixelWidth: scenePixelWidth) else {
            ELOG("TV bezels: artwork of '\(bezel.id)' did not render at \(Int(scenePixelWidth)) px")
            return nil
        }
        var values = TVBezelShader.values(frame: bezel.frame, tubeAspect: artwork.tubeAspect,
                                          tubeHeightFraction: artwork.tubeHeightFraction, lightsRoom: lit)
        if flatGlass {
            values[TVBezelShader.glassCurvatureName] = 0
        }
        // The values never change for a key, so any revision does: a new scene is a new load.
        let shader = ResolvedShader(entry: entry, values: values, revision: key.hashValue)
        let textures = ShaderTextureOverrides(key: key, textures: [TVBezelShader.borderTextureName: png])
        return TVBezelScene(tubeRect: artwork.tubeRect, shader: shader, textures: textures)
    }
}
