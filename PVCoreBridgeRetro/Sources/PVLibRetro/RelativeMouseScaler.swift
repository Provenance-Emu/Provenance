//
//  RelativeMouseScaler.swift
//  PVLibRetro
//
//  Turns changes in a normalised (0–1) cursor position into whole libretro mouse
//  units. The fraction lost to rounding is carried into the next event, so slow
//  finger movement adds up instead of truncating to zero every time.
//

import Foundation

struct RelativeMouseScaler {
    private var remainderX = 0.0
    private var remainderY = 0.0

    /// - Parameters:
    ///   - dx: Normalised horizontal change.
    ///   - dy: Normalised vertical change.
    ///   - scaleX: Mouse units for a full horizontal sweep (0 → 1).
    ///   - scaleY: Mouse units for a full vertical sweep (0 → 1).
    mutating func units(dx: Double, dy: Double, scaleX: Double, scaleY: Double) -> (x: Int16, y: Int16) {
        let x = dx * scaleX + remainderX
        let y = dy * scaleY + remainderY
        let wholeX = x.rounded(.towardZero)
        let wholeY = y.rounded(.towardZero)
        remainderX = x - wholeX
        remainderY = y - wholeY
        return (Int16(clamping: Int(wholeX)), Int16(clamping: Int(wholeY)))
    }
}
