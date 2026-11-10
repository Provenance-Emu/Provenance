//
//  MenuButtonPlacementTests.swift
//  PVUIBaseTests
//

import CoreGraphics
import Testing
@testable import PVUIBase

@Suite("MenuButtonPlacement")
struct MenuButtonPlacementTests {
    /// A landscape iPhone canvas (874×402 points) and the button's top-left corner there.
    private let bounds = CGRect(x: 62, y: 0, width: 750, height: 381)
    private let preferred = CGRect(origin: CGPoint(x: 82, y: 10), size: MenuButtonPlacement.size)

    @Test("Keeps the preferred corner when no control is in the way")
    func clearCorner() {
        let dPad = CGRect(x: 70, y: 120, width: 140, height: 140)
        #expect(MenuButtonPlacement.frame(preferred: preferred, avoiding: [dPad], within: bounds) == preferred)
        #expect(MenuButtonPlacement.frame(preferred: preferred, avoiding: [], within: bounds) == preferred)
    }

    @Test("Moves below a shoulder button that covers the corner")
    func belowShoulder() {
        let shoulderL = CGRect(x: 70, y: 6, width: 100, height: 48)
        let placed = MenuButtonPlacement.frame(preferred: preferred, avoiding: [shoulderL], within: bounds)
        #expect(placed == CGRect(x: 82, y: 54 + MenuButtonPlacement.spacing, width: 42, height: 42))
    }

    @Test("Moves beside the shoulder when the gap below it is taken")
    func besideShoulder() {
        let shoulderL = CGRect(x: 70, y: 6, width: 100, height: 48)
        let dPad = CGRect(x: 70, y: 70, width: 140, height: 140)
        let placed = MenuButtonPlacement.frame(preferred: preferred, avoiding: [shoulderL, dPad], within: bounds)
        #expect(placed == CGRect(x: 170 + MenuButtonPlacement.spacing, y: 10, width: 42, height: 42))
        #expect(![shoulderL, dPad].contains { $0.intersects(placed) })
    }

    @Test("Falls back to the preferred corner when nothing fits")
    func nothingFits() {
        let wall = bounds.insetBy(dx: -20, dy: -20)
        #expect(MenuButtonPlacement.frame(preferred: preferred, avoiding: [wall], within: bounds) == preferred)
    }
}
