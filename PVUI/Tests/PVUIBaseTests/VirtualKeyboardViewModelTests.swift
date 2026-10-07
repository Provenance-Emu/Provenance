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
import UIKit
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

    // MARK: - Hit-test gate coordinate conversion

    @Test("containerFrame shifts a safe-area-space frame by the safe-area origin")
    func containerFrameAppliesSafeAreaOrigin() {
        // Portrait notched iPhone: 59pt top inset, 34pt home-indicator inset.
        let insets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        let sheet = CGRect(x: 4, y: 500, width: 382, height: 250)
        let result = VirtualKeyboardViewModel.containerFrame(forSheetFrame: sheet, safeAreaInsets: insets)
        #expect(result == CGRect(x: 4, y: 559, width: 382, height: 250))
    }

    @Test("containerFrame shifts horizontally in landscape")
    func containerFrameLandscape() {
        let insets = UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59)
        let sheet = CGRect(x: 4, y: 100, width: 600, height: 250)
        let result = VirtualKeyboardViewModel.containerFrame(forSheetFrame: sheet, safeAreaInsets: insets)
        #expect(result.minX == 63)
        #expect(result.minY == 100)
    }

    @Test("containerFrame leaves an unmeasured (.zero) frame empty")
    func containerFrameKeepsZeroEmpty() {
        let insets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        let result = VirtualKeyboardViewModel.containerFrame(forSheetFrame: .zero, safeAreaInsets: insets)
        #expect(result.isEmpty)
    }

    @Test("bottom key row stays inside the gate once the safe-area shift is applied")
    func bottomRowInsideGate() {
        let insets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        // Sheet bottom (in safe-area space) sits at 750; the bottom row centre is ~22pt above it.
        let sheet = CGRect(x: 4, y: 500, width: 382, height: 250)
        let gate = VirtualKeyboardViewModel.containerFrame(forSheetFrame: sheet, safeAreaInsets: insets)
        let bottomRowCentre = CGPoint(x: 195, y: 59 + 750 - 22)
        #expect(gate.contains(bottomRowCentre))
        // The un-shifted gate (the original bug) would have rejected it.
        #expect(!sheet.contains(bottomRowCentre))
    }

    @Test("key height meets the 44pt minimum touch target")
    func keyHeightMeetsMinimumTarget() {
        #expect(VirtualKeyboardViewModel.keyHeight >= 44)
    }

    @Test("passthrough view ignores touches until a frame is reported")
    func passthroughIgnoresTouchesWhenUnmeasured() {
        let view = KeyboardPassthroughView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        view.addSubview(UIView(frame: view.bounds))
        #expect(view.hitTest(CGPoint(x: 200, y: 400), with: nil) == nil)
    }
}
#endif // !os(tvOS)
