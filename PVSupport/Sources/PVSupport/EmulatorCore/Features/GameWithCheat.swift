//
//  GameWithCheat.swift
//  PVSupport
//
import Foundation
@objc public protocol GameWithCheat {
    @objc(setCheatWithCode:type:enabled:)
    optional func setCheat(
        code: String,
        type: String,
        enabled: Bool
    ) -> Bool
    @objc(setCheatWithCode:type:codeType:cheatIndex:enabled:)
    func setCheat(
        code: String,
        type: String,
        codeType: String,
        cheatIndex: UInt8,
        enabled: Bool
    ) -> Bool
    @objc(supportsCheatCode)
    func supportsCheatCode() -> Bool
    @objc(cheatCodeTypes)
    func cheatCodeTypes() -> NSArray
}

