// CompanionKeyboardBridgeTests.swift
// PVUIBaseTests
//
// Unit tests for CompanionKeyboardBridge and the keyboard/mouse event routing
// through CompanionKeyboardMouseEvent / CompanionInputRouter.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import Testing
import GameController
import Combine
import PVCoreBridge
@testable import PVUIBase

// MARK: - CompanionInputRouter keyboard/mouse event tests

@Suite("CompanionInputRouter — keyboard and mouse events")
@MainActor
struct CompanionInputRouterKeyboardTests {

    // MARK: - sendKeyDown / sendKeyUp publish to keyboardMouseEvents

    @Test("sendKeyDown publishes .keyDown on keyboardMouseEvents and does not update DSU state")
    func keyDownPublishesOnKeyboardMouseEvents() async throws {
        let router = CompanionInputRouter()
        var received: [CompanionKeyboardMouseEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.sendKeyDown(.keyA)

        try #require(received.count == 1)
        if case .keyDown(let key) = received[0] {
            #expect(key == .keyA)
        } else {
            Issue.record("Expected .keyDown event, got \(received[0])")
        }
        // Button state must not be mutated
        #expect(router.heldButtons == 0)
        _ = cancellable
    }

    @Test("sendKeyUp publishes .keyUp on keyboardMouseEvents and does not update DSU state")
    func keyUpPublishesOnKeyboardMouseEvents() async throws {
        let router = CompanionInputRouter()
        var received: [CompanionKeyboardMouseEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.sendKeyUp(.returnOrEnter)

        try #require(received.count == 1)
        if case .keyUp(let key) = received[0] {
            #expect(key == .returnOrEnter)
        } else {
            Issue.record("Expected .keyUp event, got \(received[0])")
        }
        #expect(router.heldButtons == 0)
        _ = cancellable
    }

    // MARK: - sendMouseMove / sendMouseButton publish to keyboardMouseEvents

    @Test("sendMouseMove publishes delta on keyboardMouseEvents")
    func mouseMovePublishesOnKeyboardMouseEvents() throws {
        let router = CompanionInputRouter()
        var received: [CompanionKeyboardMouseEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        let delta = CGPoint(x: 3.5, y: -2.0)
        router.sendMouseMove(delta)

        try #require(received.count == 1)
        if case .mouseMove(let pt) = received[0] {
            #expect(pt == delta)
        } else {
            Issue.record("Expected .mouseMove event, got \(received[0])")
        }
        _ = cancellable
    }

    @Test("sendMouseButton publishes button index and state on keyboardMouseEvents")
    func mouseButtonPublishesOnKeyboardMouseEvents() throws {
        let router = CompanionInputRouter()
        var received: [CompanionKeyboardMouseEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.sendMouseButton(0, isDown: true)
        router.sendMouseButton(1, isDown: false)

        try #require(received.count == 2)
        if case .mouseButton(let idx, let down) = received[0] {
            #expect(idx == 0)
            #expect(down == true)
        } else {
            Issue.record("Expected first event to be .mouseButton(0, true), got \(received[0])")
        }
        if case .mouseButton(let idx, let down) = received[1] {
            #expect(idx == 1)
            #expect(down == false)
        } else {
            Issue.record("Expected second event to be .mouseButton(1, false), got \(received[1])")
        }
        _ = cancellable
    }

    // MARK: - Button events do NOT publish on keyboardMouseEvents

    @Test("send(.buttonDown) does not publish on keyboardMouseEvents")
    func buttonDownDoesNotPublishOnKeyboardMouseEvents() {
        let router = CompanionInputRouter()
        var received: [CompanionKeyboardMouseEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.send(.buttonDown(.south))

        #expect(received.isEmpty)
        #expect(router.heldButtons == CompanionButton.south.rawValue)
        _ = cancellable
    }

    // MARK: - sendKeyDown / sendKeyUp convenience methods (re-test via convenience path)

    @Test("sendKeyDown convenience publishes .keyDown on keyboardMouseEvents")
    func sendKeyDownConvenience() throws {
        let router = CompanionInputRouter()
        var received: [CompanionKeyboardMouseEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.sendKeyDown(.escape)

        try #require(received.count == 1)
        if case .keyDown(let key) = received[0] {
            #expect(key == .escape)
        } else {
            Issue.record("Expected .keyDown(.escape)")
        }
        _ = cancellable
    }

    @Test("sendKeyUp convenience publishes .keyUp on keyboardMouseEvents")
    func sendKeyUpConvenience() throws {
        let router = CompanionInputRouter()
        var received: [CompanionKeyboardMouseEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.sendKeyUp(.spacebar)

        try #require(received.count == 1)
        if case .keyUp(let key) = received[0] {
            #expect(key == .spacebar)
        } else {
            Issue.record("Expected .keyUp(.spacebar)")
        }
        _ = cancellable
    }
}

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
