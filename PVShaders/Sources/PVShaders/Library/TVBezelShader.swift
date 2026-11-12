//
//  TVBezelShader.swift
//  PVShaders
//
//  The library presets that draw a TV around the picture, and the parameter values that
//  place a tube inside them.
//

import CoreGraphics
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

/// The `bezel/uborder` presets as a TV: a scene the size of the display, with the picture
/// inside a tube whose frame reflects it.
///
/// The presets take the whole scene as their output and are told where the tube is through
/// parameters, so the picture handed to them is already the tube's shape.
public enum TVBezelShader {
    /// Frame, glass and reflections in one pass, with no tube look of its own.
    public static let bezelOnlyID = ShaderID.slang("bezel/uborder/preset_tools/append-uborder-bezel-reflections")
    /// The same, plus passes that spill the picture's light onto the room. Its last pass has
    /// the crt-nobody tube look built in, which `neutralTubeValues` turns down.
    public static let ambientID = ShaderID.slang("bezel/uborder/uborder-koko-ambi")
    /// The preset texture that holds the room and the cabinet.
    public static let borderTextureName = "BORDER"
    /// The scene's proportions. The presets' geometry assumes them.
    public static let sceneAspect = CGSize(width: 16, height: 9)

    public static func presetID(lightsRoom: Bool) -> ShaderID {
        lightsRoom ? ambientID : bezelOnlyID
    }

    /// The denominator the tube's aspect is expressed over (`fr_aspect_x / fr_aspect_y`).
    static let aspectDenominator: Float = 8

    /// Parameters that centre a tube of `tubeAspect` (width over height) taking
    /// `tubeHeightFraction` of the scene's height.
    ///
    /// The presets size the tube by `fr_zoom`: its height as a percentage of the scene's
    /// width (measured: 40.5 gives a 774 px tube on a 1920 px wide scene).
    public static func geometryValues(tubeAspect: CGFloat, tubeHeightFraction: CGFloat) -> [String: Float] {
        let widthsPerHeight = Float(sceneAspect.height / sceneAspect.width)
        return [
            "fr_aspect_x": aspectDenominator * Float(tubeAspect),
            "fr_aspect_y": aspectDenominator,
            "fr_zoom": Float(tubeHeightFraction) * widthsPerHeight * 100,
            "fr_center_x": 0,
            "fr_center_y": 0,
            "bz_center_x": 0,
            "bz_center_y": 0
        ]
    }

    /// Turns `ambientID`'s built-in tube look down to a plain copy, so the screen filter that
    /// ran before it is the only look inside the glass.
    public static let neutralTubeValues: [String: Float] = [
        "CN_InputGamma": 2.2,
        "CN_OutputGamma": 2.2,
        "CN_VIG_TOGGLE": 0,
        "CN_BEAM_MIN_WIDTH": 1,
        "CN_BEAM_MAX_WIDTH": 1,
        "CN_SCAN_SIZE": 1,
        "CN_MASK_STRENGTH": 0,
        "CN_PHOSPHOR_LAYOUT": 0
    ]

    /// Every value a TV's preset runs with.
    ///
    /// - Parameter frame: the TV's own look for the frame and glass (colour, widths, curvature).
    ///   Geometry wins over it: a TV cannot move or resize its tube through these.
    public static func values(frame: [String: Float],
                              tubeAspect: CGFloat,
                              tubeHeightFraction: CGFloat,
                              lightsRoom: Bool) -> [String: Float] {
        var values = lightsRoom ? neutralTubeValues : [:]
        values.merge(frame) { _, tv in tv }
        values.merge(geometryValues(tubeAspect: tubeAspect, tubeHeightFraction: tubeHeightFraction)) { _, geometry in geometry }
        return values
    }

    /// Parameter names filters use to switch their own screen curvature on. Lower-cased.
    static let curvatureSwitchNames: Set<String> = [
        "curvature", "h_curvature", "crt_curvature", "curv", "warpx", "warpy", "warp_x", "warp_y",
        "curvature_x", "curvature_y", "geom_curvature", "crtcurvature"
    ]

    /// Values that switch off `entry`'s own curvature: the TV's glass is the only thing that
    /// bends the picture. Empty when the filter has no such switch.
    public static func curvatureOffValues(for entry: ShaderCatalogEntry) -> [String: Float] {
        var values: [String: Float] = [:]
        for parameter in entry.parameters where !parameter.isHeading
            && curvatureSwitchNames.contains(parameter.name.lowercased())
            && parameter.minimum <= 0 && parameter.maximum >= 0 {
            values[parameter.name] = 0
        }
        return values
    }

    /// A filter that draws a frame of its own, which cannot go inside a TV.
    public static func isBezelFilter(_ entry: ShaderCatalogEntry) -> Bool {
        entry.looks.contains(.bezel)
    }
}
