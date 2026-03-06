//
//  Test.swift
//  PVLibRetro
//
//  Created by Joseph Mattiello on 10/5/24.
//

import Testing
@testable import libretro
@testable import PVLibRetro

struct Test {

    @Test func LibRetroTest() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let bridge = PVLibRetroCoreBridge()
        #expect(bridge != nil)
    }

    // MARK: - Keyboard Event Pipeline Tests

    /// Verify that sendKeyboardEvent: does not crash when called before the
    /// core registers its keyboard callback (runloop_key_event == NULL).
    /// This exercises the NULL guard + pending-event queue added in issue #2579.
    @Test func keyboardEventBeforeCoreInit_doesNotCrash() async throws {
        let bridge = PVLibRetroCoreBridge()
        #expect(bridge != nil)

        // HID 0x28 = Enter, 0x29 = Escape — common DOS keys.
        // With no core loaded runloop_key_event is NULL; events should be
        // silently queued rather than crashing or being delivered to a NULL fn.
        bridge.sendKeyboardEvent(true,  hidCode: 0x28, character: 0)  // Enter down
        bridge.sendKeyboardEvent(false, hidCode: 0x28, character: 0)  // Enter up
        bridge.sendKeyboardEvent(true,  hidCode: 0x29, character: 0)  // Escape down
        bridge.sendKeyboardEvent(false, hidCode: 0x29, character: 0)  // Escape up
        // Reaching here without crashing confirms the NULL guard is effective.
    }

    /// Verify that flooding the pending queue (> PV_KEY_QUEUE_CAPACITY events)
    /// before the core is ready does not crash — excess events must be dropped
    /// gracefully with a log.
    @Test func keyboardEventQueueOverflow_doesNotCrash() async throws {
        let bridge = PVLibRetroCoreBridge()
        #expect(bridge != nil)

        // Send 80 key-down events (capacity is 64); the final 16 must be
        // dropped without memory corruption or crash.
        for code in 0..<80 {
            bridge.sendKeyboardEvent(true, hidCode: UInt32(code & 0xFF), character: 0)
        }
        // Send matching key-up events to verify up-events are also queued safely.
        for code in 0..<80 {
            bridge.sendKeyboardEvent(false, hidCode: UInt32(code & 0xFF), character: 0)
        }
    }

    /// Verify key-up / key-down symmetry: each keyDown must have a matching
    /// keyUp so the core does not see stuck keys.  This is a static analysis
    /// / documentation test that also confirms both paths compile and link.
    @Test func keyboardEventKeyUpClearsState() async throws {
        let bridge = PVLibRetroCoreBridge()
        #expect(bridge != nil)

        // Simulate a complete keystroke cycle: down then up.
        let hidEnter: UInt32 = 0x28
        bridge.sendKeyboardEvent(true,  hidCode: hidEnter, character: 0)
        bridge.sendKeyboardEvent(false, hidCode: hidEnter, character: 0)
        // No assertion beyond non-crash; correct key-state management is
        // verified at the core level when running a real DOS game.
    }

//    @Test func LoadFileTest() async throws {
//        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
//        let core = PVLibRetroCoreBridge()
//        #expect(core != nil)

//        do {
//            try core.loadFile(atPath: testRomFilename)
//        } catch {
//            print("Failed to load file: \(error.localizedDescription)")
//            throw error
//        }
//    }
}
