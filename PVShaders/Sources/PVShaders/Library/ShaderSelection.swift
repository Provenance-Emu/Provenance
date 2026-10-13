//
//  ShaderSelection.swift
//  PVShaders
//
//  Which filter applies, chosen everywhere, per system or per game.
//

import Foundation
import PVSettings
import PVPrimitives

/// The filter choice for one scope.
public enum ShaderSelection: Codable, Hashable, Sendable {
    /// No filter. (Not `none`: that would read as `Optional.none` wherever a
    /// `ShaderSelection?` is expected, silently clearing the scope instead.)
    case off
    /// This filter for every game in the scope.
    case always(ShaderID)
    /// Pick by the core's screen type: `crt` for CRT systems, `lcd` for handhelds.
    case auto(crt: ShaderID?, lcd: ShaderID?)
    /// Use the CIFilter the current skin ships, and no shader.
    case skinFilter

    /// The filter to draw for a core whose screen type is `screenType`.
    public func shader(for screenType: ScreenTypeObjC) -> ShaderID? {
        switch self {
        case .off, .skinFilter:
            return nil
        case .always(let id):
            return id
        case .auto(let crt, let lcd):
            switch screenType {
            case .colorLCD, .monochromaticLCD:
                return lcd
            case .dotMatrix:
                return .native(.gameBoy)
            case .crt:
                return crt
            case .modern, .unknown:
                return nil
            }
        }
    }

    /// Converts the legacy `metalFilterMode` value.
    public init(legacy mode: MetalFilterModeOption) {
        func id(_ option: MetalFilterSelectionOption) -> ShaderID? {
            option == .none ? nil : .native(option)
        }
        switch mode {
        case .none:
            self = .off
        case .always(let filter):
            self = id(filter).map(ShaderSelection.always) ?? .off
        case .auto(let crt, let lcd):
            self = .auto(crt: id(crt), lcd: id(lcd))
        }
    }

    /// The legacy value that renders the same, when one exists (only native filters do).
    public var legacyMode: MetalFilterModeOption? {
        switch self {
        case .off, .skinFilter:
            return MetalFilterModeOption.none
        case .always(let id):
            return id.nativeOption.map { MetalFilterModeOption.always(filter: $0) }
        case .auto(let crt, let lcd):
            func option(_ id: ShaderID?) -> MetalFilterSelectionOption? {
                guard let id else { return MetalFilterSelectionOption.none }
                return id.nativeOption
            }
            guard let crt = option(crt), let lcd = option(lcd) else { return nil }
            return .auto(crt: crt, lcd: lcd)
        }
    }
}

/// Where a selection applies.
public enum ShaderScope: Hashable, Sendable {
    case global
    case system(String)
    case game(String)

    var key: String {
        switch self {
        case .global: return "global"
        case .system(let id): return "system:\(id)"
        case .game(let md5): return "game:\(md5)"
        }
    }

    static let gamePrefix = "game:"
}
