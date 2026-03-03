//
//  GameWithCheat.swift
//  PVCoreBridge
//
import Foundation
// Re-export CheatCodeTypes so existing consumers of PVCoreBridge do not need
// to explicitly import PVPrimitives.
@_exported import PVPrimitives

@objc public protocol GameWithCheat {
    @objc(setCheatWithCode:type:enabled:)
    optional func setCheat(code: String, type: String, enabled: Bool ) -> Bool

    @objc(setCheatWithCode:type:codeType:cheatIndex:enabled:)
    func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool

    @objc(supportsCheatCode)
    var supportsCheatCode: Bool { get }

    /// The supported cheat code type display names for this core.
    ///
    /// Returns a `[String]` for Objective-C compatibility. Swift callers can use
    /// `cheatCodeTypeEnums` for the type-safe `[CheatCodeTypes]` equivalent.
    @objc(cheatCodeTypes)
    var cheatCodeTypes: [String] { get }

    @objc(resetCheatCodes)
    optional func resetCheatCodes()
}

public extension GameWithCheat {
    /// Type-safe Swift accessor equivalent to `cheatCodeTypes`.
    ///
    /// Converts the string array returned by `cheatCodeTypes` into `[CheatCodeTypes]`,
    /// falling back to `.rawCode` for any strings that do not match a known case so
    /// that cheats remain usable even for cores with custom type names.
    var cheatCodeTypeEnums: [CheatCodeTypes] {
        cheatCodeTypes.map { CheatCodeTypes(string: $0) ?? .rawCode }
    }
}
