//
//  PVEmulatorCore+Location.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/2/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

fileprivate let kSetLEDFadeID: UInt32 = 3 // setLEDFade(int, int, int, int *)

@available(iOS 14.0, tvOS 14.0, *)
@objc public extension PVEmulatorCore {
    @objc
    func setLED(led : Int, state : Int) -> Bool {
        DLOG("led index \(led) state \(state)")

        let color: CGColor = state != 0 ? UIColor.white.cgColor : UIColor.black.cgColor
        
        switch led {
        case 0:
            if let light = controller1?.light {
//                light.color = color
                return true
            } else {
                // TODO: iPhone light?
                return false
            }
        case 1:
            if let light = controller2?.light {
//                light.color = color
                return true
            }
            return false
        case 2:
            if let light = controller3?.light {
//                light.color = color
                return true
            }
            return false
        case 3:
            if let light = controller4?.light {
//                light.color = color
                return true
            }
            return false
        default:
            ILOG("led index \(led) not supported")
            return false
        }
    }
}
