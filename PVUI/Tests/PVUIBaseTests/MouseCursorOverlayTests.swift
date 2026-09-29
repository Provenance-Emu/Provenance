//
//  MouseCursorOverlayTests.swift
//  PVUIBaseTests
//
//  The cursor overlay steps aside only for systems that draw their own pointer.
//

import Testing
import PVSystems
@testable import PVUIBase

struct MouseCursorOverlayTests {

    @Test func systemsWithOwnPointerSkipTheOverlay() {
        #expect(MouseCursorOverlayView.systemDrawsOwnPointer(SystemIdentifier.AtariST.rawValue))
        #expect(MouseCursorOverlayView.systemDrawsOwnPointer(SystemIdentifier.DOS.rawValue))
        #expect(MouseCursorOverlayView.systemDrawsOwnPointer(SystemIdentifier.MSX.rawValue))
        #expect(MouseCursorOverlayView.systemDrawsOwnPointer(SystemIdentifier.MSX2.rawValue))
    }

    @Test func amigaIsMatchedByCore() {
        #expect(MouseCursorOverlayView.systemDrawsOwnPointer(
            SystemIdentifier.RetroArch.rawValue, coreIdentifier: "puae2021.libretro.framework"
        ))
        #expect(!MouseCursorOverlayView.systemDrawsOwnPointer(
            SystemIdentifier.RetroArch.rawValue, coreIdentifier: "quicknes.libretro.framework"
        ))
    }

    @Test func otherSystemsKeepTheOverlay() {
        #expect(!MouseCursorOverlayView.systemDrawsOwnPointer(SystemIdentifier.DOOM.rawValue))
        #expect(!MouseCursorOverlayView.systemDrawsOwnPointer(nil))
        #expect(!MouseCursorOverlayView.systemDrawsOwnPointer("not.a.system"))
    }
}
