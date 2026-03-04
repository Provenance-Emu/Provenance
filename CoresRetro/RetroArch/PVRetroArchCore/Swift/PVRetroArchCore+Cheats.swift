//
//  PVRetroArchCore+Cheats.swift
//  PVRetroArchCore
//
//  Created by Joseph Mattiello on 3/4/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVEmulatorCore
import PVPrimitives

// MARK: - GameWithCheat
extension PVRetroArchCoreCore: GameWithCheat {
    public var supportsCheatCode: Bool { true }

    /// RetroArch's libretro cheat API accepts raw code strings and passes
    /// them through to the active libretro core. "Raw Code" covers the
    /// generic passthrough; individual cores may support additional formats.
    public var cheatCodeTypes: [String] {
        CheatCodeTypesMakeStringArray([.rawCode])
    }

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        do {
            return try _bridge.setCheat(
                code,
                setType: type,
                setCodeType: codeType,
                setIndex: cheatIndex,
                setEnabled: enabled
            )
        } catch {
            return false
        }
    }
}
