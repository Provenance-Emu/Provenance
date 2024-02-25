//
//  PVGameControllerUtilities.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/16/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
@_exported import GameController
import simd

private let thumbstickSensitivity: Float = 0.2

@objc
public enum PVControllerAxisDirection : UInt, CustomDebugStringConvertible {
    case None
    case Up
    case Down
    case Left
    case Right
    case UpRight
    case UpLeft
    case DownRight
    case DownLeft

    public var debugDescription: String {
        let label: String
        switch self {
        case .None: label = "None"
        case .Up: label = "Up"
        case .Down: label = "Down"
        case .Left: label = "Left"
        case .Right: label = "Right"
        case .UpRight: label = "UpRight"
        case .UpLeft: label = "UpLeft"
        case .DownRight: label = "DownRight"
        case .DownLeft: label = "DownLeft"
        }
        return "\(rawValue): \(label)"
    }

    public init(forThumbstick thumbstick :GCControllerDirectionPad) {
        let xValue = fabsf(thumbstick.xAxis.value)
        let yValue = fabsf(thumbstick.yAxis.value)

        if xValue <= thumbstickSensitivity && yValue <= thumbstickSensitivity {
            self = .None
            return
        }

        var angleInRadians: Double = atan2(Double(thumbstick.yAxis.value), Double(thumbstick.xAxis.value))
        // We have 8 sectors, so get the size of each in degrees.
        let sectorSize:Double = 360.0 / 8
        // We also need the size of half a sector
        let halfSectorSize: Double = sectorSize / 2.0

        // Atan2 gives us a negative value for angles in the 3rd and 4th quadrants.
            // We want a full 360 degrees, so we will add 2 PI to negative values.
        if angleInRadians < 0.0 { angleInRadians += (.pi * 2.0) }
        // Convert the radians to degrees.  Degrees are easier to visualize.
        let angleInDegrees: Double = (180.0 * angleInRadians / .pi)

        // Next, rotate our angle to match the offset of our sectors.
        let convertedAngle: Double = angleInDegrees + halfSectorSize

        // Finally, we get the current direction by dividing the angle
        // by the size of the sectors
        let direction: Int = Int(floor(convertedAngle / sectorSize))
        switch direction {
        case 0:
            self = .Right
        case 1:
            self = .UpRight
        case 2:
            self = .Up
        case 3:
            self = .UpLeft
        case 4:
            self = .Left
        case 5:
            self = .DownLeft
        case 6:
            self = .Down
        case 7:
            self = .DownRight
        case 8:
            self = .Right
        default:
            self = .None
        }
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
