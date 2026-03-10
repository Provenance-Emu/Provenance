//
//  PVMupenBridgeRumbleHelper.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 3/10/26.
//

import Foundation
import PVCoreBridge

/// ObjC-visible adapter that forwards classic Mupen bridge callbacks into the
/// shared PVCoreBridge rumble pipeline.
@objc(PVMupenBridgeRumbleHelper)
public final class PVMupenBridgeRumbleHelper: NSObject {
    @objc(rumbleForBridgeObject:player:lowFrequency:highFrequency:duration:)
    public static func rumble(
        forBridgeObject bridgeObject: NSObject,
        player: Int,
        lowFrequency: Float,
        highFrequency: Float,
        duration: TimeInterval
    ) {
        guard let bridge = bridgeObject as? any EmulatorCoreRumbleDataSource else {
            return
        }

        Task { @MainActor in
            bridge.rumble(lowFrequency: lowFrequency,
                          highFrequency: highFrequency,
                          duration: duration,
                          player: player)
        }
    }

    @objc(stopRumbleForBridgeObject:player:)
    public static func stopRumble(
        forBridgeObject bridgeObject: NSObject,
        player: Int
    ) {
        guard let bridge = bridgeObject as? any EmulatorCoreRumbleDataSource else {
            return
        }

        Task { @MainActor in
            bridge.stopRumble(player: player)
        }
    }
}
