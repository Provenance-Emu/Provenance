//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  PVGameControllerUtilities.swift
//  PVSupport
//
//  Created by Tyler Hedrick on 4/3/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//
import GameController


@objc
public enum PVControllerAxisDirection : Int {
    case none
    case up
    case down
    case left
    case right
    case upRight
    case upLeft
    case downRight
    case downLeft
}

@objc
@objcMembers
public final
class PVGameControllerUtilities: NSObject {
    public static let axisDirectionThumbstickSensitivty: Float = 0.2

    @objc
    public static func axisDirection(forThumbstick thumbstick: GCControllerDirectionPad) -> PVControllerAxisDirection {
        if abs(thumbstick.xAxis.value) <= axisDirectionThumbstickSensitivty && abs(thumbstick.yAxis.value) <= axisDirectionThumbstickSensitivty {
            return .none
        }
        let angle = atan2(thumbstick.yAxis.value, thumbstick.xAxis.value)
        if angle >= 7 * .pi / 8 || angle <= -7 * .pi / 8 {
            return .left
        }
        if angle > 5 * .pi / 8 {
            return .upLeft
        }
        if angle >= 3 * .pi / 8 {
            return .up
        }
        if angle > 1 * .pi / 8 {
            return .upRight
        }
        if angle < -5 * .pi / 8 {
            return .downLeft
        }
        if angle <= -3 * .pi / 8 {
            return .down
        }
        if angle < -1 * .pi / 8 {
            return .downRight
        }
        return .right
    }
}
