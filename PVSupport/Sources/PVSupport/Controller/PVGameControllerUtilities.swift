//
//  PVGameControllerUtilities.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/16/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
@_exported import GameController

fileprivate let thumbstickSensitivty: Float = 0.2;

@objc
public enum PVControllerAxisDirection : UInt {
    case None
    case Up
    case Down
    case Left
    case Right
    case UpRight
    case UpLeft
    case DownRight
    case DownLeft
    
    public init(forThumbstick thumbstick :GCControllerDirectionPad) {
        if (fabsf(thumbstick.xAxis.value) <= thumbstickSensitivty && fabsf(thumbstick.yAxis.value) <= thumbstickSensitivty) {
            self = .None;
        }
        
        let angle: Double = atan2(Double(thumbstick.yAxis.value), Double(thumbstick.xAxis.value))

        if angle >= (7 * .pi / 8) || angle <= (-7 * .pi / 8) {
            self = .Left
        }
        
        if (angle > 5 * .pi / 8) {
            self = .UpLeft
        }
        if (angle >= 3 * .pi / 8) {
            self = .Up
        }
        if (angle > 1 * .pi / 8) {
            self = .UpRight
        }
        
        if (angle < -5 * .pi / 8) {
            self = .DownLeft
        }
        if (angle <= -3 * .pi / 8) {
            self = .Down
        }
        if (angle < -1 * .pi / 8) {
            self = .DownRight
        }
        
        self = .Right
    }
}

@objc
public final class PVGameControllerUtilities : NSObject {

    @objc(axisDirectionForThumbstick:)
    public
    static func axisDirection(forThumbstick thumbstick :GCControllerDirectionPad) -> PVControllerAxisDirection {
        return .init(forThumbstick: thumbstick)
    }
}
