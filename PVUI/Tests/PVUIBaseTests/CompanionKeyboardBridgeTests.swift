// CompanionKeyboardBridgeTests.swift
// PVUIBaseTests
//
// Unit tests for CompanionKeyboardBridge and the keyboard/mouse extension of
// CompanionInputEvent / CompanionInputRouter.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import Testing
import GameController
import Combine
@testable import PVUIBase

// MARK: - CompanionInputRouter keyboard/mouse event tests

@Suite("CompanionInputRouter — keyboard and mouse events")
@MainActor
struct CompanionInputRouterKeyboardTests {

    // MARK: - keyDown / keyUp publish to keyboardMouseEvents

    @Test("send(.keyDown) publishes on keyboardMouseEvents and does not update DSU state")
    func keyDownPublishesOnKeyboardMouseEvents() async throws {
        let router = CompanionInputRouter()
        var received: [CompanionInputEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.send(.keyDown(.keyA))

        #expect(received.count == 1)
        if case .keyDown(let key) = received[0] {
            #expect(key == .keyA)
        } else {
            Issue.record("Expected .keyDown event, got \(received[0])")
        }
        // Button state must not be mutated
        #expect(router.heldButtons == 0)
        _ = cancellable
    }

    @Test("send(.keyUp) publishes on keyboardMouseEvents and does not update DSU state")
    func keyUpPublishesOnKeyboardMouseEvents() async throws {
        let router = CompanionInputRouter()
        var received: [CompanionInputEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.send(.keyUp(.returnOrEnter))

        #expect(received.count == 1)
        if case .keyUp(let key) = received[0] {
            #expect(key == .returnOrEnter)
        } else {
            Issue.record("Expected .keyUp event, got \(received[0])")
        }
        #expect(router.heldButtons == 0)
        _ = cancellable
    }

    // MARK: - mouseMove / mouseButton publish to keyboardMouseEvents

    @Test("send(.mouseMove) publishes delta on keyboardMouseEvents")
    func mouseMovePublishesOnKeyboardMouseEvents() {
        let router = CompanionInputRouter()
        var received: [CompanionInputEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        let delta = CGPoint(x: 3.5, y: -2.0)
        router.send(.mouseMove(delta))

        #expect(received.count == 1)
        if case .mouseMove(let pt) = received[0] {
            #expect(pt == delta)
        } else {
            Issue.record("Expected .mouseMove event, got \(received[0])")
        }
        _ = cancellable
    }

    @Test("send(.mouseButton) publishes button index and state on keyboardMouseEvents")
    func mouseButtonPublishesOnKeyboardMouseEvents() {
        let router = CompanionInputRouter()
        var received: [CompanionInputEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.send(.mouseButton(0, true))
        router.send(.mouseButton(1, false))

        #expect(received.count == 2)
        if case .mouseButton(let idx, let down) = received[0] {
            #expect(idx == 0)
            #expect(down == true)
        }
        if case .mouseButton(let idx, let down) = received[1] {
            #expect(idx == 1)
            #expect(down == false)
        }
        _ = cancellable
    }

    // MARK: - Button events do NOT publish on keyboardMouseEvents

    @Test("send(.buttonDown) does not publish on keyboardMouseEvents")
    func buttonDownDoesNotPublishOnKeyboardMouseEvents() {
        let router = CompanionInputRouter()
        var received: [CompanionInputEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.send(.buttonDown(.south))

        #expect(received.isEmpty)
        #expect(router.heldButtons == CompanionButton.south.rawValue)
        _ = cancellable
    }

    // MARK: - sendKeyDown / sendKeyUp convenience methods

    @Test("sendKeyDown publishes .keyDown on keyboardMouseEvents")
    func sendKeyDownConvenience() {
        let router = CompanionInputRouter()
        var received: [CompanionInputEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.sendKeyDown(.escape)

        #expect(received.count == 1)
        if case .keyDown(let key) = received[0] {
            #expect(key == .escape)
        } else {
            Issue.record("Expected .keyDown(.escape)")
        }
        _ = cancellable
    }

    @Test("sendKeyUp publishes .keyUp on keyboardMouseEvents")
    func sendKeyUpConvenience() {
        let router = CompanionInputRouter()
        var received: [CompanionInputEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        router.sendKeyUp(.spacebar)

        #expect(received.count == 1)
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
    func keyDownForwardedToRouter() {
        let router = CompanionInputRouter()
        let bridge = CompanionKeyboardBridge(inputRouter: router)

        var received: [CompanionInputEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        let vm = VirtualKeyboardViewModel()
        bridge.virtualKeyboard(vm, keyDown: .keyA)

        #expect(received.count == 1)
        if case .keyDown(let key) = received[0] {
            #expect(key == .keyA)
        } else {
            Issue.record("Expected .keyDown(.keyA)")
        }
        _ = cancellable
    }

    @Test("virtualKeyboard(_:keyUp:) forwards key to router as .keyUp")
    func keyUpForwardedToRouter() {
        let router = CompanionInputRouter()
        let bridge = CompanionKeyboardBridge(inputRouter: router)

        var received: [CompanionInputEvent] = []
        let cancellable = router.keyboardMouseEvents.sink { received.append($0) }

        let vm = VirtualKeyboardViewModel()
        bridge.virtualKeyboard(vm, keyUp: .escape)

        #expect(received.count == 1)
        if case .keyUp(let key) = received[0] {
            #expect(key == .escape)
        } else {
            Issue.record("Expected .keyUp(.escape)")
        }
        _ = cancellable
    }
}

#endif // !os(tvOS)
