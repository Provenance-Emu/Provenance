//
//  PVRetroArchCore+LightGun.swift
//  PVRetroArch
//
//  Created by Claude (Agent) on 2026-03-27.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Adds LightGunResponder conformance to PVRetroArchCoreCore so that the
//  shared emulator view controller (PVEmulatorViewController+LightGun) can
//  route GCMouse deltas and touch gestures to the RetroArch thick wrapper.
//
//  Coordinate space:
//    The LightGunResponder protocol delivers normalised coordinates (0.0–1.0).
//    RETRO_DEVICE_ID_LIGHTGUN_SCREEN_X/Y expect the range [-0x7FFF, +0x7FFF].
//    The transform is: retro = Int16((normalised * 2.0 - 1.0) * 0x7FFF)
//

import Foundation
import PVCoreBridge
import PVSystems

// MARK: - LightGunResponder

extension PVRetroArchCoreCore: LightGunResponder {

    /// True when the currently-loaded libretro core declared
    /// `RETRO_DEVICE_LIGHTGUN` as a supported device type on any port,
    /// **or** when the system identifier is known to require a light gun
    /// (NES Zapper, SNES Super Scope/Justifier, PSX GunCon, etc.).
    public var gameSupportsLightGun: Bool {
        // Dynamic path: core declared RETRO_DEVICE_LIGHTGUN after load.
        if _bridge.coreDeclaresLightGunDevice {
            // Cache into the session registry so that future queries
            // (before a core is loaded) return the right answer.
            if let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") {
                LightGunSystemRegistry.shared.register(system: sysID)
            }
            return true
        }
        // Static fallback: consult the registry (built-in baseline + cached
        // discoveries from prior game sessions this run).
        return SystemIdentifier(rawValue: systemIdentifier ?? "")?.supportsLightGun ?? false
    }

    public var requiresLightGun: Bool {
        SystemIdentifier(rawValue: systemIdentifier ?? "")?.requiresLightGun ?? false
    }

    // MARK: - Aim

    public func lightGunMovedToPoint(_ point: CGPoint, isOffscreen: Bool) {
        let x = Int16(clamping: Int((Double(point.x) * 2.0 - 1.0) * Double(Int16.max)))
        let y = Int16(clamping: Int((Double(point.y) * 2.0 - 1.0) * Double(Int16.max)))
        _bridge.setLightGunX(x, y: y, offscreen: isOffscreen)
    }

    // MARK: - Trigger

    public func lightGunTriggerDown() {
        _bridge.setLightGunTrigger(true)
    }

    public func lightGunTriggerUp() {
        _bridge.setLightGunTrigger(false)
    }

    // MARK: - Reload (off-screen shot)

    public func lightGunReloadDown() {
        _bridge.setLightGunReload(true)
    }

    public func lightGunReloadUp() {
        _bridge.setLightGunReload(false)
    }

    // MARK: - Aux buttons

    public func lightGunAuxADown() {
        _bridge.setLightGunAuxA(true)
    }

    public func lightGunAuxAUp() {
        _bridge.setLightGunAuxA(false)
    }

    public func lightGunAuxBDown() {
        _bridge.setLightGunAuxB(true)
    }

    public func lightGunAuxBUp() {
        _bridge.setLightGunAuxB(false)
    }

    // MARK: - Start / Select

    public func lightGunStartDown() {
        _bridge.setLightGunStart(true)
    }

    public func lightGunStartUp() {
        _bridge.setLightGunStart(false)
    }

    public func lightGunSelectDown() {
        _bridge.setLightGunSelect(true)
    }

    public func lightGunSelectUp() {
        _bridge.setLightGunSelect(false)
    }
}
