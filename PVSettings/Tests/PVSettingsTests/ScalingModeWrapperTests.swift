//
//  ScalingModeWrapperTests.swift
//  PVSettings
//

import Testing
@testable import PVSettings
import Foundation

/// ObjC cores (Dolphin, PPSSPP, the RetroArch wrapper) read the scaling mode
/// only through these flags, so each mode must set exactly the right one.
@Suite("PVSettingsWrapper scaling flags", .serialized)
struct ScalingModeWrapperTests {

    @Test("Each scaling mode sets only its own flag", arguments: ScalingMode.allCases)
    func flagsMatchMode(mode: ScalingMode) {
        defer { Defaults.reset(.scalingMode) }
        Defaults[.scalingMode] = mode

        #expect(PVSettingsWrapper.useStretchScale == (mode == .stretch))
        #expect(PVSettingsWrapper.useIntegerScale == (mode == .integerScale))
        #expect(PVSettingsWrapper.useNativeResolution == (mode == .nativeResolution))
    }
}
