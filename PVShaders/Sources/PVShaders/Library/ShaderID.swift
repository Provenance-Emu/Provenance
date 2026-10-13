//
//  ShaderID.swift
//  PVShaders
//
//  Stable identifier for any filter the app can apply.
//

import Foundation
import PVSettings

/// Identifies a filter across launches, devices and library updates.
///
/// - `native:<name>`: a hand-written Provenance filter (`MetalFilterSelectionOption.rawValue`).
/// - `slang:<path>`: a preset in the bundled slang library, by its path without
///   extension (`crt/crt-royale`, `native-metal/hologram`).
public struct ShaderID: RawRepresentable, Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public enum Kind: String, Sendable {
        case native
        case slang
    }

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(kind: Kind, path: String) {
        rawValue = "\(kind.rawValue):\(path)"
    }

    public static func native(_ option: MetalFilterSelectionOption) -> ShaderID {
        ShaderID(kind: .native, path: option.rawValue)
    }

    public static func slang(_ path: String) -> ShaderID {
        ShaderID(kind: .slang, path: path)
    }

    public var kind: Kind? {
        guard let colon = rawValue.firstIndex(of: ":") else { return nil }
        return Kind(rawValue: String(rawValue[..<colon]))
    }

    /// Everything after `kind:`.
    public var path: String {
        guard let colon = rawValue.firstIndex(of: ":") else { return rawValue }
        return String(rawValue[rawValue.index(after: colon)...])
    }

    /// The native filter this ID names, if it is one.
    public var nativeOption: MetalFilterSelectionOption? {
        kind == .native ? MetalFilterSelectionOption(rawValue: path) : nil
    }

    public var description: String { rawValue }

    public static func < (lhs: ShaderID, rhs: ShaderID) -> Bool { lhs.rawValue < rhs.rawValue }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
