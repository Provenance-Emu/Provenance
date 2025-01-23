//
//  GameWithCheat.swift
//  PVCoreBridge
//
import Foundation
import PVPrimitives

@objc public protocol GameWithCheat {
    @objc(setCheatWithCode:type:enabled:)
    optional func setCheat(code: String, type: String, enabled: Bool ) -> Bool

    @objc(setCheatWithCode:type:codeType:cheatIndex:enabled:)
    func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool

    @objc(supportsCheatCode)
    var supportsCheatCode: Bool { get }

    @objc(cheatCodeTypes)
    var cheatCodeTypes: [String] { get }

    @objc(resetCheatCodes)
    optional func resetCheatCodes()
}

//extension GameWithCheat where Self: ObjCBridgedCore {
//    public var supportsCheatCode: Bool { (((bridge as? GameWithCheat)?.supportsCheatCode) != nil) }
//}
