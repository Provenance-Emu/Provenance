//
//  GameWithCheat.swift
//  PVSupport
//
import Foundation
@objc public protocol GameWithCheat {
    @objc(setCheatWithCode:type:codeType:enabled:)
    func setCheat(
        code: String,
        type: String,
        codeType: String,
        enabled: Bool
    ) -> Bool
    @objc(setCheatWithCode:type:enabled:)
    optional
    func setCheat(
        code: String,
        type: String,
        enabled: Bool
    ) -> Bool
    @objc(supportsCheatCode)
    func supportsCheatCode() -> Bool
    @objc(cheatCodeTypes)
    func cheatCodeTypes() -> NSArray
}

