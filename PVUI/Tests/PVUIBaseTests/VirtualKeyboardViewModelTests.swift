// VirtualKeyboardViewModelTests.swift
// PVUIBaseTests
//
// Unit tests for VirtualKeyboardViewModel — verifies the vertical reposition
// offset clamping that keeps the draggable on-screen keyboard within bounds.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import Testing
import CoreGraphics
@testable import PVUIBase

// MARK: - VirtualKeyboardViewModel tests

@Suite("VirtualKeyboardViewModel")
@MainActor
struct VirtualKeyboardViewModelTests {

    @Test("clampVerticalOffset never returns a positive (downward) offset")
    func clampNeverPositive() {
        // The sheet is bottom-anchored; positive (downward) offsets are clamped to 0.
        let result = VirtualKeyboardViewModel.clampVerticalOffset(
            120, sheetHeight: 200, containerHeight: 800, topInset: 40
        )
        #expect(result == 0)
    }

    @Test("clampVerticalOffset allows lifting the sheet up to the top inset")
    func clampAllowsLiftWithinBounds() {
        // containerHeight 800, sheetHeight 200, topInset 40 → max lift = -(800-200-40) = -560
        let result = VirtualKeyboardViewModel.clampVerticalOffset(
            -300, sheetHeight: 200, containerHeight: 800, topInset: 40
        )
        #expect(result == -300)
    }

    @Test("clampVerticalOffset stops at the top inset")
    func clampStopsAtTopInset() {
        // Requesting more lift than possible clamps to the min offset (-560).
        let result = VirtualKeyboardViewModel.clampVerticalOffset(
            -10_000, sheetHeight: 200, containerHeight: 800, topInset: 40
        )
        #expect(result == -560)
    }

    @Test("clampVerticalOffset with sheet larger than container cannot lift")
    func clampDegenerateLargeSheet() {
        // When the sheet is taller than the available space, minOffset clamps to 0.
        let result = VirtualKeyboardViewModel.clampVerticalOffset(
            -100, sheetHeight: 900, containerHeight: 800, topInset: 40
        )
        #expect(result == 0)
    }

    @Test("verticalOffset and keyboardFrame default to neutral values")
    func defaultsAreNeutral() {
        let vm = VirtualKeyboardViewModel()
        #expect(vm.verticalOffset == 0)
        #expect(vm.keyboardFrame == .zero)
    }
}
#endif // !os(tvOS)
