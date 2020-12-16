//
//  GameWithCheat.swift
//  PVSupport
//
import Foundation
@objc public protocol GameWithCheat {
    func setCheat(
        code: String,
        type: String,
        enabled: Bool
    ) -> Bool
}
