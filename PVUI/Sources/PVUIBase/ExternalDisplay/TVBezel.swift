//
//  TVBezel.swift
//  PVUI
//
//  The TVs that can surround the game picture on an external display.
//

import Foundation
import PVLogging
import PVSettings
import PVShaders

/// One TV: a cabinet and room drawn from a format 2 skin document, the look of its frame and
/// glass, and the tube look it suggests.
///
/// A TV is data. The bundled ones live in `Resources/TVBezels`: `catalog.json` lists them and
/// each names a skin document beside it.
public struct TVBezel: Decodable, Identifiable, Equatable, Sendable {

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
    /// File name of the format 2 skin document that draws the cabinet and the room.
    public let artwork: String

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

    public static func bezel(id: String) -> TVBezel? {
        bundled.first { $0.id == id }
    }

    /// The catalogue as the selection rules see it.
    public static var candidates: [ExternalDisplayBezelRules.Candidate] {
        bundled.map { .init(id: $0.id, preferredSystems: Set($0.preferredSystems)) }
    }

    /// The TV to show for a game from the current settings, or `nil` for the picture alone.
    public static func bezel(chosen: String, matchesSystem: Bool, systemID: String?) -> TVBezel? {
        ExternalDisplayBezelRules.bezelID(chosen: chosen, matchesSystem: matchesSystem,
                                          systemID: systemID, candidates: candidates).flatMap(bezel(id:))
    }
}
