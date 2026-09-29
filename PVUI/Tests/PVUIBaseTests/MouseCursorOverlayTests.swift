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

    @Test func atariSTDrawsOwnPointer() {
        #expect(MouseCursorOverlayView.systemDrawsOwnPointer(SystemIdentifier.AtariST.rawValue))
    }

    @Test func otherSystemsKeepTheOverlay() {
        #expect(!MouseCursorOverlayView.systemDrawsOwnPointer(SystemIdentifier.DOS.rawValue))
        #expect(!MouseCursorOverlayView.systemDrawsOwnPointer(nil))
        #expect(!MouseCursorOverlayView.systemDrawsOwnPointer("not.a.system"))
    }
}
