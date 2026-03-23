// CompanionKeyboardBridgeTests.swift
// PVUIBaseTests
//
// Unit tests for CompanionKeyboardBridge — verifies that VirtualKeyboardDelegate
// callbacks are forwarded correctly to CompanionInputRouter as keyboard events.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import Testing
import GameController
import Combine
import PVCoreBridge
@testable import PVUIBase

// MARK: - CompanionKeyboardBridge tests

@Suite("CompanionKeyboardBridge")
@MainActor
struct CompanionKeyboardBridgeTests {

    @Test("virtualKeyboard(_:keyDown:) forwards key to router as .keyDown")
    func keyDownForwardedToRouter() throws {
        let router = CompanionInputRouter()
        let bridge = CompanionKeyboardBridge(inputRouter: router)

        var received: [CompanionKeyboardMouseEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        let vm = VirtualKeyboardViewModel()
        bridge.virtualKeyboard(vm, keyDown: .keyA)

        try #require(received.count == 1)
        if case .keyDown(let key) = received[0] {
            #expect(key == .keyA)
        } else {
            Issue.record("Expected .keyDown(.keyA)")
        }
        _ = cancellable
    }

    @Test("virtualKeyboard(_:keyUp:) forwards key to router as .keyUp")
    func keyUpForwardedToRouter() throws {
        let router = CompanionInputRouter()
        let bridge = CompanionKeyboardBridge(inputRouter: router)

        var received: [CompanionKeyboardMouseEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        let vm = VirtualKeyboardViewModel()
        bridge.virtualKeyboard(vm, keyUp: .escape)

        try #require(received.count == 1)
        if case .keyUp(let key) = received[0] {
            #expect(key == .escape)
        } else {
            Issue.record("Expected .keyUp(.escape)")
        }
        _ = cancellable
    }
}

#endif // !os(tvOS)
