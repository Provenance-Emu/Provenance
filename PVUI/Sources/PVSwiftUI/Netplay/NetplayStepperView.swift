//
//  NetplayStepperView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI

/// tvOS-compatible stepper used across netplay forms.
///
/// On tvOS, `Stepper` is unavailable, so this renders `+`/`−` buttons instead.
/// On iOS/macOS, it renders the standard `Stepper`.
@MainActor
struct NetplayStepperView: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(label: String, value: Binding<Int>, in range: ClosedRange<Int>) {
        self.label = label
        self._value = value
        self.range = range
    }

    var body: some View {
        #if os(tvOS)
        HStack {
            Text("\(label): \(value)")
            Spacer()
            Button {
                value = max(range.lowerBound, value - 1)
            } label: {
                Image(systemName: "minus.circle")
            }
            .accessibilityLabel("Decrease \(label)")
            .accessibilityHint("Current: \(value), minimum: \(range.lowerBound)")
            .disabled(value <= range.lowerBound)
            Button {
                value = min(range.upperBound, value + 1)
            } label: {
                Image(systemName: "plus.circle")
            }
            .accessibilityLabel("Increase \(label)")
            .accessibilityHint("Current: \(value), maximum: \(range.upperBound)")
            .disabled(value >= range.upperBound)
        }
        #else
        Stepper("\(label): \(value)", value: $value, in: range)
        #endif
    }
}
#endif
