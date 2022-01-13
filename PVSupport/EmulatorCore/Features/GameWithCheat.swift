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

    func supportsCheatCode() -> Bool
}
