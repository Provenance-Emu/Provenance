//
//  GameWithCheat.swift
//  PVSupport
//
import Foundation
@objc public protocol GameWithCheat {
    @objc(setCheatWithCode:type:enabled:)
    func setCheat(
        code: String,
        type: String,
        enabled: Bool
    ) -> Bool

    @objc(supportsCheatCode)
    func supportsCheatCode() -> Bool
}
