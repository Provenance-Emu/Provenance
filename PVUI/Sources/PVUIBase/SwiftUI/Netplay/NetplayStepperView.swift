//
//  NetplayStepperView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI

/// A stepper used across netplay forms: `−` and `+` buttons, which touch, the tvOS focus
/// engine (where `Stepper` is unavailable) and the iOS controller cursor can all press.
///
/// A screen that lists it as cursor targets passes `cursorID` and `cursor`, and adds
/// `NetplayStepperView.cursorRow(...)` with the same ID to its rows.
@MainActor
public struct NetplayStepperView: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let cursorID: String?
    let cursor: String?

    public init(label: String, value: Binding<Int>, in range: ClosedRange<Int>) {
        self.init(label: label, value: value, in: range, cursorID: nil, cursor: nil)
    }

    init(label: String, value: Binding<Int>, in range: ClosedRange<Int>, cursorID: String?, cursor: String?) {
        self.label = label
        self._value = value
        self.range = range
        self.cursorID = cursorID
        self.cursor = cursor
    }

    public var body: some View {
        HStack {
            Text("\(label): \(value)")
            Spacer()
            Button {
                value = Self.decremented(value, in: range)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.title2)
                    .frame(minWidth: NetplayStepperMetrics.buttonSize, minHeight: NetplayStepperMetrics.buttonSize)
                    .contentShape(Rectangle())
            }
            .retroFocusButtonStyle(focusScale: 1.05)
            .netplayCursorItem(cursorID.map(Self.minusID), cursor: cursor)
            .accessibilityLabel("Decrease \(label)")
            .accessibilityHint("Current: \(value), minimum: \(range.lowerBound)")
            .disabled(value <= range.lowerBound)
            Button {
                value = Self.incremented(value, in: range)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .frame(minWidth: NetplayStepperMetrics.buttonSize, minHeight: NetplayStepperMetrics.buttonSize)
                    .contentShape(Rectangle())
            }
            .retroFocusButtonStyle(focusScale: 1.05)
            .netplayCursorItem(cursorID.map(Self.plusID), cursor: cursor)
            .accessibilityLabel("Increase \(label)")
            .accessibilityHint("Current: \(value), maximum: \(range.upperBound)")
            .disabled(value >= range.upperBound)
        }
    }

    static func minusID(_ id: String) -> String { "\(id).minus" }
    static func plusID(_ id: String) -> String { "\(id).plus" }

    static func decremented(_ value: Int, in range: ClosedRange<Int>) -> Int {
        max(range.lowerBound, min(range.upperBound, value - 1))
    }

    static func incremented(_ value: Int, in range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value + 1))
    }

    /// The cursor row for a stepper drawn with `cursorID: id`.
    static func cursorRow(_ id: String, value: Binding<Int>, in range: ClosedRange<Int>) -> NetplayCursorRow {
        NetplayCursorRow(id: "row.\(id)", targets: [
            NetplayCursorTarget(id: minusID(id), isEnabled: value.wrappedValue > range.lowerBound) {
                value.wrappedValue = decremented(value.wrappedValue, in: range)
            },
            NetplayCursorTarget(id: plusID(id), isEnabled: value.wrappedValue < range.upperBound) {
                value.wrappedValue = incremented(value.wrappedValue, in: range)
            }
        ])
    }
}

private enum NetplayStepperMetrics {
    static let buttonSize: CGFloat = 52
}
#endif
