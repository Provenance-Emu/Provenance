// CompanionInputEventTests.swift
// PVUIBaseTests
//
// Unit tests for CompanionInputEvent and CompanionButton types defined in
// PVCoreBridge, plus a mock conformance that validates the mapping
// contract that PVVecXCore+CompanionController implements.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Testing
import PVCoreBridge

// MARK: - CompanionButton bitmask tests

@Suite("CompanionButton")
struct CompanionButtonTests {

    @Test("Each button has a unique raw value")
    func uniqueRawValues() {
        let values = CompanionButton.allCases.map(\.rawValue)
        let uniqueValues = Set(values)
        #expect(values.count == uniqueValues.count, "Duplicate raw values detected")
    }

    @Test("Face buttons have expected raw values")
    func faceButtonRawValues() {
        #expect(CompanionButton.south.rawValue == 0x0001)
        #expect(CompanionButton.east.rawValue  == 0x0002)
        #expect(CompanionButton.west.rawValue  == 0x0004)
        #expect(CompanionButton.north.rawValue == 0x0008)
    }

    @Test("Button bitmasks can be combined without collision")
    func bitmaskCombination() {
        let southAndNorth: UInt32 = CompanionButton.south.rawValue | CompanionButton.north.rawValue
        #expect(southAndNorth == 0x0009)
        #expect(southAndNorth & CompanionButton.east.rawValue == 0)
    }
}

// MARK: - CompanionAxisID tests

@Suite("CompanionAxisID")
struct CompanionAxisIDTests {

    @Test("CompanionAxisID is Hashable")
    func hashable() {
        var seen: Set<CompanionAxisID> = []
        seen.insert(.leftX)
        seen.insert(.leftY)
        seen.insert(.rightX)
        seen.insert(.rightY)
        seen.insert(.l2Analog)
        seen.insert(.r2Analog)
        #expect(seen.count == 6)
    }
}

// MARK: - CompanionInputEvent tests

@Suite("CompanionInputEvent")
struct CompanionInputEventTests {

    @Test("buttonDown carries the button")
    func buttonDownCarriesButton() {
        let event = CompanionInputEvent.buttonDown(.south)
        if case .buttonDown(let btn) = event {
            #expect(btn == .south)
        } else {
            Issue.record("Expected .buttonDown(.south)")
        }
    }

    @Test("buttonUp carries the button")
    func buttonUpCarriesButton() {
        let event = CompanionInputEvent.buttonUp(.north)
        if case .buttonUp(let btn) = event {
            #expect(btn == .north)
        } else {
            Issue.record("Expected .buttonUp(.north)")
        }
    }

    @Test("axisChanged carries axis ID and value")
    func axisChangedCarriesValue() {
        let event = CompanionInputEvent.axisChanged(.leftX, 0.75)
        if case .axisChanged(let axis, let value) = event {
            #expect(axis == .leftX)
            #expect(value == 0.75)
        } else {
            Issue.record("Expected .axisChanged(.leftX, 0.75)")
        }
    }
}

// MARK: - Vectrex button mapping contract

/// Mock that records calls without needing the real VecX core.
/// Tests the same mapping logic that PVVecXCore+CompanionController uses.
private final class MockVectrexResponder {

    enum Call: Equatable {
        case push(button: Int)
        case release(button: Int)
        case moveJoystick(direction: Int, value: Double)
    }

    var calls: [Call] = []

    func vectrexButton(for companionButton: CompanionButton) -> PVVectrexButton? {
        switch companionButton {
        case .south: return .button1
        case .east:  return .button2
        case .west:  return .button3
        case .north: return .button4
        default:     return nil
        }
    }

    func handle(_ event: CompanionInputEvent) {
        switch event {
        case .buttonDown(let btn):
            if let vBtn = vectrexButton(for: btn) {
                calls.append(.push(button: vBtn.rawValue))
            }
        case .buttonUp(let btn):
            if let vBtn = vectrexButton(for: btn) {
                calls.append(.release(button: vBtn.rawValue))
            }
        case .axisChanged(let axis, let value):
            handleAxis(axis, value: value)
        }
    }

    private func handleAxis(_ axis: CompanionAxisID, value: Float) {
        let magnitude = Double(abs(value))
        switch axis {
        case .leftX:
            if value >= 0 {
                calls.append(.moveJoystick(direction: PVVectrexButton.analogRight.rawValue, value: magnitude))
                calls.append(.moveJoystick(direction: PVVectrexButton.analogLeft.rawValue,  value: 0))
            } else {
                calls.append(.moveJoystick(direction: PVVectrexButton.analogLeft.rawValue,  value: magnitude))
                calls.append(.moveJoystick(direction: PVVectrexButton.analogRight.rawValue, value: 0))
            }
        case .leftY:
            if value >= 0 {
                calls.append(.moveJoystick(direction: PVVectrexButton.analogDown.rawValue, value: magnitude))
                calls.append(.moveJoystick(direction: PVVectrexButton.analogUp.rawValue,   value: 0))
            } else {
                calls.append(.moveJoystick(direction: PVVectrexButton.analogUp.rawValue,   value: magnitude))
                calls.append(.moveJoystick(direction: PVVectrexButton.analogDown.rawValue, value: 0))
            }
        default:
            break
        }
    }
}

@Suite("Vectrex companion button mapping")
struct VectrexCompanionButtonMappingTests {

    // MARK: - Button press / release

    @Test("south → button1 press")
    func southMapsToButton1() {
        let mock = MockVectrexResponder()
        mock.handle(.buttonDown(.south))
        #expect(mock.calls == [.push(button: PVVectrexButton.button1.rawValue)])
    }

    @Test("east → button2 press")
    func eastMapsToButton2() {
        let mock = MockVectrexResponder()
        mock.handle(.buttonDown(.east))
        #expect(mock.calls == [.push(button: PVVectrexButton.button2.rawValue)])
    }

    @Test("west → button3 press")
    func westMapsToButton3() {
        let mock = MockVectrexResponder()
        mock.handle(.buttonDown(.west))
        #expect(mock.calls == [.push(button: PVVectrexButton.button3.rawValue)])
    }

    @Test("north → button4 press")
    func northMapsToButton4() {
        let mock = MockVectrexResponder()
        mock.handle(.buttonDown(.north))
        #expect(mock.calls == [.push(button: PVVectrexButton.button4.rawValue)])
    }

    @Test("south release → button1 release")
    func southReleaseButton1() {
        let mock = MockVectrexResponder()
        mock.handle(.buttonUp(.south))
        #expect(mock.calls == [.release(button: PVVectrexButton.button1.rawValue)])
    }

    @Test("Unmapped buttons produce no calls")
    func unmappedButtonProducesNoCalls() {
        let mock = MockVectrexResponder()
        mock.handle(.buttonDown(.start))
        mock.handle(.buttonDown(.select))
        mock.handle(.buttonDown(.l1))
        mock.handle(.buttonDown(.r1))
        #expect(mock.calls.isEmpty)
    }

    // MARK: - Analog axis

    @Test("leftX positive → analogRight active, analogLeft zeroed")
    func leftXPositiveIsRight() {
        let mock = MockVectrexResponder()
        mock.handle(.axisChanged(.leftX, 0.8))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogRight.rawValue, value: 0.8)))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogLeft.rawValue,  value: 0)))
    }

    @Test("leftX negative → analogLeft active, analogRight zeroed")
    func leftXNegativeIsLeft() {
        let mock = MockVectrexResponder()
        mock.handle(.axisChanged(.leftX, -0.6))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogLeft.rawValue,  value: 0.6)))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogRight.rawValue, value: 0)))
    }

    @Test("leftX zero → both directions zeroed")
    func leftXZeroBothZeroed() {
        let mock = MockVectrexResponder()
        mock.handle(.axisChanged(.leftX, 0))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogRight.rawValue, value: 0)))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogLeft.rawValue,  value: 0)))
    }

    @Test("leftY positive → analogDown active, analogUp zeroed")
    func leftYPositiveIsDown() {
        let mock = MockVectrexResponder()
        mock.handle(.axisChanged(.leftY, 0.5))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogDown.rawValue, value: 0.5)))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogUp.rawValue,   value: 0)))
    }

    @Test("leftY negative → analogUp active, analogDown zeroed")
    func leftYNegativeIsUp() {
        let mock = MockVectrexResponder()
        mock.handle(.axisChanged(.leftY, -1.0))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogUp.rawValue,   value: 1.0)))
        #expect(mock.calls.contains(.moveJoystick(direction: PVVectrexButton.analogDown.rawValue, value: 0)))
    }

    @Test("rightX axis is ignored (Vectrex has one stick)")
    func rightXIgnored() {
        let mock = MockVectrexResponder()
        mock.handle(.axisChanged(.rightX, 1.0))
        #expect(mock.calls.isEmpty)
    }
}
