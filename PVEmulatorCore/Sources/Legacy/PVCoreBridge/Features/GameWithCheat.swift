    //
    //  GameWithCheat.swift
    //  PVSupport
    //
import Foundation
// Re-export CheatCodeTypes so existing consumers do not need to import PVPrimitives directly.
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
    var cheatCodeTypeEnums: [CheatCodeTypes] {
        cheatCodeTypes.compactMap { CheatCodeTypes(string: $0) }
    }
}
