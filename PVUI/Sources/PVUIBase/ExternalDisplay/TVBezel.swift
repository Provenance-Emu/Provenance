//
//  TVBezel.swift
//  PVUI
//
//  The TVs that can surround the game picture on an external display.
//

import CoreGraphics
import Foundation
import PVLogging
import PVSettings
import PVShaders

/// One TV: a cabinet and room drawn from a format 2 skin document, the look of its frame and
/// glass, and the tube look it suggests. Or a picture with a hole in it: a bezel the player
/// imported or downloaded, laid plainly over the game.
///
/// A TV is data. The bundled ones live in `Resources/TVBezels`: `catalog.json` lists them and
/// each names a skin document beside it. The player's own live in `TVBezelLibrary`.
public struct TVBezel: Decodable, Identifiable, Equatable, Sendable {

    /// A bezel that is one image with a see-through screen.
    public struct ImageArtwork: Equatable, Sendable {
        public let fileURL: URL
        /// The image's size in pixels.
        public let size: CGSize
        /// The see-through screen in the image's pixels, origin at the top left.
        public let screen: CGRect
    }

    /// Where a TV came from.
    public enum Source: String, Codable, Sendable {
        case builtIn
        /// A file the player brought in.
        case imported
        /// Downloaded from The Bezel Project.
        case bezelProject
    }

    /// A filter and the values it runs with: the tube look a TV suggests.
    public struct Look: Decodable, Equatable, Sendable {
        /// A `ShaderID` raw value (`slang:crt/crt-geom`, `native:…`).
        public let shader: String
        public let values: [String: Float]

        public var shaderID: ShaderID { ShaderID(rawValue: shader) }

        private enum CodingKeys: String, CodingKey { case shader, values }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            shader = try container.decode(String.self, forKey: .shader)
            values = try container.decodeIfPresent([String: Float].self, forKey: .values) ?? [:]
        }
    }

    /// The stored value of `Defaults[.externalDisplayBezel]`.
    public let id: String
    public let name: String
    /// System identifiers this TV is the natural screen for (`SystemIdentifier` raw values).
    public let preferredSystems: [String]
    /// Parameters of the bezel preset: frame colour and widths, corner radius, curvature,
    /// reflection strength. The tube's place and shape come from the artwork, not from here.
    public let frame: [String: Float]
    /// The tube look used until the player picks a filter for the external display.
    public let look: Look?
    /// The picture may light this TV's room (`TVBezelShader.ambientID`). Off for a TV that
    /// looks wrong or runs too slowly with it.
    public let lightsRoom: Bool
    /// File name of the format 2 skin document that draws the cabinet and the room. Empty for
    /// an image bezel.
    public let artwork: String
    /// The image of a bezel the player imported or downloaded; `nil` for a built-in TV.
    public let image: ImageArtwork?
    /// A standalone shader that draws its own cabinet and screen.
    public let presetID: ShaderID?
    public let source: Source
    /// Shown in the picker. Artwork fetched for a single game is on the device without
    /// being listed.
    public let isListed: Bool

    private enum CodingKeys: String, CodingKey { case id, name, preferredSystems, frame, look, lightsRoom, artwork }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        preferredSystems = try container.decodeIfPresent([String].self, forKey: .preferredSystems) ?? []
        frame = try container.decodeIfPresent([String: Float].self, forKey: .frame) ?? [:]
        look = try container.decodeIfPresent(Look.self, forKey: .look)
        lightsRoom = try container.decodeIfPresent(Bool.self, forKey: .lightsRoom) ?? true
        artwork = try container.decode(String.self, forKey: .artwork)
        image = nil
        presetID = nil
        source = .builtIn
        isListed = true
    }

    /// A bundled shader bezel that was checked with its own artwork.
    init(presetID: ShaderID, name: String) {
        id = presetID.rawValue
        self.name = name
        preferredSystems = []
        frame = [:]
        look = nil
        lightsRoom = false
        artwork = ""
        image = nil
        self.presetID = presetID
        source = .builtIn
        isListed = true
    }

    /// An image bezel.
    init(id: String, name: String, preferredSystems: [String], image: ImageArtwork, source: Source, isListed: Bool) {
        self.id = id
        self.name = name
        self.preferredSystems = preferredSystems
        frame = [:]
        look = nil
        lightsRoom = false
        artwork = ""
        self.image = image
        presetID = nil
        self.source = source
        self.isListed = isListed
    }
}

/// The TVs that ship with the app.
public enum TVBezelCatalog {
    /// Folder of the catalogue inside the module's bundle.
    static let folderName = "TVBezels"
    static let catalogFileName = "catalog.json"

    private struct File: Decodable {
        let bezels: [TVBezel]
    }

    /// The bundled catalogue's folder, or `nil` when the resources are missing.
    static var folderURL: URL? {
        Bundle.module.url(forResource: folderName, withExtension: nil)
    }

    /// Decodes a catalogue file.
    static func decode(_ data: Data) throws -> [TVBezel] {
        try JSONDecoder().decode(File.self, from: data).bezels
    }

    /// Every bundled TV, in the order the picker shows them. Empty when the catalogue cannot
    /// be read, which leaves the picture alone on the display.
    public static let bundled: [TVBezel] = {
        guard let url = folderURL?.appendingPathComponent(catalogFileName) else {
            ELOG("TV bezels: no catalogue in the bundle")
            return []
        }
        do {
            return try decode(Data(contentsOf: url))
        } catch {
            ELOG("TV bezels: could not read the catalogue: \(error)")
            return []
        }
    }()

    /// Standalone presets that showed a usable picture and frame at both preview sizes and at 1080p.
    /// The shader browser's Bezels category also includes append presets and border effects.
    public static let shaderPresets: [TVBezel] = [
        TVBezel(presetID: .slang("bezel/uborder/uborder-bezel-reflections"), name: "uBorder Reflections"),
        TVBezel(presetID: TVBezelShader.ambientID, name: "uBorder Ambient"),
        TVBezel(presetID: .slang("bezel/uborder/base_presets/uborder-bezel-reflections/crt/crt-geom"), name: "uBorder CRT Geom"),
        TVBezel(presetID: .slang("bezel/uborder/base_presets/uborder-bezel-reflections/crt/phosphor-persistence"), name: "uBorder Phosphor Persistence"),
        TVBezel(presetID: .slang("bezel/uborder/base_presets/uborder-bezel-reflections/vector/uborder-bezel-reflections-vector"), name: "uBorder Vector"),
        TVBezel(presetID: .slang("bezel/uborder/base_presets/uborder-koko-ambi/crt/crt-geom"), name: "uBorder Ambient CRT Geom")
    ].filter { bezel in
        bezel.presetID.flatMap { ShaderCatalog.shared.entry(for: $0) } != nil
    }

    /// Every TV on the device, including artwork fetched for a single game.
    public static var all: [TVBezel] { bundled + shaderPresets + TVBezelLibrary.shared.bezels }

    public static func bezel(id: String) -> TVBezel? {
        bundled.first { $0.id == id }
            ?? shaderPresets.first { $0.id == id }
            ?? TVBezelLibrary.shared.bezel(id: id)
    }

    /// The catalogue as the selection rules see it. Only a TV shown in the picker can stand
    /// for a system.
    public static var candidates: [ExternalDisplayBezelRules.Candidate] {
        all.map {
            .init(id: $0.id, preferredSystems: $0.isListed ? Set($0.preferredSystems) : [], isUserAdded: $0.source != .builtIn)
        }
    }

    /// The TV to show for a game from the current settings, or `nil` for the picture alone.
    ///
    /// - Parameters:
    ///   - pinned: the TV pinned to the game (`ExternalDisplayBezelRules.bezelID`).
    ///   - gameArt: artwork for the game that is on the device, when game artwork is wanted.
    public static func bezel(chosen: String, matchesSystem: Bool, systemID: String?,
                             pinned: String? = nil, gameArt: String? = nil) -> TVBezel? {
        ExternalDisplayBezelRules.bezelID(chosen: chosen, matchesSystem: matchesSystem, systemID: systemID,
                                          candidates: candidates, pinned: pinned, gameArt: gameArt).flatMap(bezel(id:))
    }
}
