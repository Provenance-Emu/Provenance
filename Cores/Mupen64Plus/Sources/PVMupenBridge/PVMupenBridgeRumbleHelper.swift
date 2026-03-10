//
//  PVMupenBridgeRumbleHelper.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 3/10/26.
//

import Foundation
import PVCoreBridge
import PVLogging
#if canImport(GameController)
import GameController
#endif
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

private protocol MupenBridgeRumbleRouting: AnyObject {
    var supportsRumble: Bool { get }
#if canImport(GameController)
    var controller1: GCController? { get }
    var controller2: GCController? { get }
    var controller3: GCController? { get }
    var controller4: GCController? { get }
    var controller5: GCController? { get }
    var controller6: GCController? { get }
    var controller7: GCController? { get }
    var controller8: GCController? { get }
#endif
}

extension PVMupenBridge: MupenBridgeRumbleRouting {}

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
        guard let bridge = bridgeObject as? any MupenBridgeRumbleRouting else {
            WLOG("PVMupenBridge rumble dropped because bridge object does not conform to MupenBridgeRumbleRouting: \(type(of: bridgeObject))")
            return
        }

        Task { @MainActor in
            guard bridge.supportsRumble else {
                WLOG("PVMupenBridge rumble dropped because supportsRumble is false")
                return
            }

#if canImport(GameController) && canImport(CoreHaptics)
            if #available(iOS 14.0, tvOS 14.0, *) {
                let params = GCControllerHapticsManager.RumbleParams(
                    lowFrequency: lowFrequency,
                    highFrequency: highFrequency,
                    duration: duration
                )
                GCControllerHapticsManager.shared.register(controller: controller(for: player, bridge: bridge), forPlayer: player)
                GCControllerHapticsManager.shared.rumble(player: player, params: params)
                return
            }
#endif

#if os(iOS) && !targetEnvironment(macCatalyst)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
#endif
        }
    }

    @objc(stopRumbleForBridgeObject:player:)
    public static func stopRumble(
        forBridgeObject bridgeObject: NSObject,
        player: Int
    ) {
        guard let bridge = bridgeObject as? any MupenBridgeRumbleRouting else {
            WLOG("PVMupenBridge stopRumble dropped because bridge object does not conform to MupenBridgeRumbleRouting: \(type(of: bridgeObject))")
            return
        }

        Task { @MainActor in
#if canImport(GameController) && canImport(CoreHaptics)
            if #available(iOS 14.0, tvOS 14.0, *) {
                GCControllerHapticsManager.shared.register(controller: nil, forPlayer: player)
                return
            }
#endif

            _ = bridge
        }
    }

    @MainActor
    private static func controller(for player: Int, bridge: any MupenBridgeRumbleRouting) -> GCController? {
#if canImport(GameController)
        switch player + 1 {
        case 1: return bridge.controller1
        case 2: return bridge.controller2
        case 3: return bridge.controller3
        case 4: return bridge.controller4
        case 5: return bridge.controller5
        case 6: return bridge.controller6
        case 7: return bridge.controller7
        case 8: return bridge.controller8
        default:
            WLOG("No Mupen controller registered for player \(player + 1)")
            return nil
        }
#else
        return nil
#endif
    }
}
