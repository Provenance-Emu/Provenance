// NumpadLayout.swift
// PVUI
//
// A generic numeric keypad overlay for companion controller sessions.
// Used by Atari 5200, ColecoVision, Vectrex (overlay), and Odyssey²-style systems.
//
// Parameterised by the key definitions so each system can customise labels
// and the CompanionButton each key sends. The grid geometry is controlled
// by the `keysPerRow` parameter (e.g. keysPerRow=3 → 4 rows × 3 columns
// for a standard 12-key phone/keypad layout).
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI

// MARK: - NumpadKey

/// A single key in a numeric keypad overlay.
public struct NumpadKey: Identifiable, Sendable {
    public let id: UUID
    /// Display label shown on the key.
    public let label: String
    /// The companion button event this key generates.
    public let button: CompanionButton
    /// Visual width multiplier relative to a standard key.
    public let widthMultiplier: CGFloat
    /// Optional SF Symbol icon.
    public let symbolName: String?

    public init(
        label: String,
        button: CompanionButton,
        widthMultiplier: CGFloat = 1.0,
        symbolName: String? = nil
    ) {
        self.id              = UUID()
        self.label           = label
        self.button          = button
        self.widthMultiplier = widthMultiplier
        self.symbolName      = symbolName
    }
}

// MARK: - NumpadLayout

/// A SwiftUI view that renders a configurable numeric keypad.
///
/// Pass a flat array of ``NumpadKey`` values together with `keysPerRow` to
/// control the grid geometry. With the default `keysPerRow: 3` and 12 keys
/// you get **4 rows × 3 columns** (left-to-right, top-to-bottom):
///
/// ```
/// Row 0:  key[0]  key[1]  key[2]
/// Row 1:  key[3]  key[4]  key[5]
/// Row 2:  key[6]  key[7]  key[8]
/// Row 3:  key[9]  key[10] key[11]
/// ```
///
/// Common arrangements:
/// - Atari 5200 / ColecoVision: `1 2 3 / 4 5 6 / 7 8 9 / * 0 #` (keysPerRow: 3)
/// - Generic numpad: `7 8 9 / 4 5 6 / 1 2 3 / * 0 #` (keysPerRow: 3)
public struct NumpadLayout: View {

    // MARK: - Configuration

    /// Rows of keys. Each sub-array is one row; each row may contain any number of keys.
    private let rows: [[NumpadKey]]
    private let router: CompanionInputRouter
    private let keySize: CGFloat
    private let keySpacing: CGFloat
    private let keyCornerRadius: CGFloat
    private let keyColor: Color
    private let pressedColor: Color
    private let labelFont: Font

    // MARK: - Init

    /// Creates a ``NumpadLayout`` from pre-split rows.
    public init(
        rows: [[NumpadKey]],
        router: CompanionInputRouter,
        keySize: CGFloat = 60,
        keySpacing: CGFloat = 8,
        keyCornerRadius: CGFloat = 8,
        keyColor: Color = Color.white.opacity(0.15),
        pressedColor: Color = Color.white.opacity(0.35),
        labelFont: Font = .system(size: 18, weight: .semibold, design: .rounded)
    ) {
        self.rows            = rows
        self.router          = router
        self.keySize         = keySize
        self.keySpacing      = keySpacing
        self.keyCornerRadius = keyCornerRadius
        self.keyColor        = keyColor
        self.pressedColor    = pressedColor
        self.labelFont       = labelFont
    }

    /// Convenience init that slices a flat key array into rows of `keysPerRow` keys.
    public init(
        keys: [NumpadKey],
        router: CompanionInputRouter,
        keysPerRow: Int = 3,
        keySize: CGFloat = 60,
        keySpacing: CGFloat = 8,
        keyCornerRadius: CGFloat = 8,
        keyColor: Color = Color.white.opacity(0.15),
        pressedColor: Color = Color.white.opacity(0.35),
        labelFont: Font = .system(size: 18, weight: .semibold, design: .rounded)
    ) {
        var sliced: [[NumpadKey]] = []
        var current: [NumpadKey] = []
        for key in keys {
            current.append(key)
            if current.count == keysPerRow {
                sliced.append(current)
                current = []
            }
        }
        if !current.isEmpty { sliced.append(current) }
        self.init(
            rows: sliced,
            router: router,
            keySize: keySize,
            keySpacing: keySpacing,
            keyCornerRadius: keyCornerRadius,
            keyColor: keyColor,
            pressedColor: pressedColor,
            labelFont: labelFont
        )
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: keySpacing) {
            ForEach(rows.indices, id: \.self) { rowIdx in
                HStack(spacing: keySpacing) {
                    ForEach(rows[rowIdx]) { key in
                        NumpadKeyView(
                            key: key,
                            router: router,
                            keySize: keySize,
                            cornerRadius: keyCornerRadius,
                            normalColor: keyColor,
                            pressedColor: pressedColor,
                            labelFont: labelFont
                        )
                        .frame(
                            width:  keySize * key.widthMultiplier + keySpacing * (key.widthMultiplier - 1),
                            height: keySize
                        )
                    }
                }
            }
        }
    }
}

// MARK: - NumpadKeyView

private struct NumpadKeyView: View {
    let key: NumpadKey
    let router: CompanionInputRouter
    let keySize: CGFloat
    let cornerRadius: CGFloat
    let normalColor: Color
    let pressedColor: Color
    let labelFont: Font

    @GestureState private var isPressed = false

    private var pressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0)
            .updating($isPressed) { value, state, _ in
                state = value
            }
    }

    var body: some View {
        CompanionControllerButton(button: key.button, router: router) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(isPressed ? pressedColor : normalColor)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .overlay(keyLabel)
        }
        .simultaneousGesture(pressGesture)
    }

    @ViewBuilder
    private var keyLabel: some View {
        if let symbol = key.symbolName {
            Image(systemName: symbol)
                .font(labelFont)
                .foregroundColor(.white)
        } else {
            Text(key.label)
                .font(labelFont)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Standard Key Sets

/// Pre-built key arrays for common numpad configurations.
public enum StandardNumpadKeys {

    /// Atari 5200 / ColecoVision phone-layout numpad: 1–9 top-down, then * 0 #.
    public static let phoneLayout: [NumpadKey] = [
        NumpadKey(label: "1", button: .num1),
        NumpadKey(label: "2", button: .num2),
        NumpadKey(label: "3", button: .num3),
        NumpadKey(label: "4", button: .num4),
        NumpadKey(label: "5", button: .num5),
        NumpadKey(label: "6", button: .num6),
        NumpadKey(label: "7", button: .num7),
        NumpadKey(label: "8", button: .num8),
        NumpadKey(label: "9", button: .num9),
        NumpadKey(label: "*", button: .numStar),
        NumpadKey(label: "0", button: .num0),
        NumpadKey(label: "#", button: .numHash),
    ]

    /// Calculator-layout numpad: 7–9 top, 4–6, 1–3, then * 0 #.
    public static let calcLayout: [NumpadKey] = [
        NumpadKey(label: "7", button: .num7),
        NumpadKey(label: "8", button: .num8),
        NumpadKey(label: "9", button: .num9),
        NumpadKey(label: "4", button: .num4),
        NumpadKey(label: "5", button: .num5),
        NumpadKey(label: "6", button: .num6),
        NumpadKey(label: "1", button: .num1),
        NumpadKey(label: "2", button: .num2),
        NumpadKey(label: "3", button: .num3),
        NumpadKey(label: "*", button: .numStar),
        NumpadKey(label: "0", button: .num0),
        NumpadKey(label: "#", button: .numHash),
    ]
}

// MARK: - Preview

#if DEBUG
#Preview("Phone layout") {
    NumpadLayout(keys: StandardNumpadKeys.phoneLayout, router: CompanionInputRouter())
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
}

#Preview("Calc layout") {
    NumpadLayout(keys: StandardNumpadKeys.calcLayout, router: CompanionInputRouter())
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
}
#endif

#endif // !os(tvOS)
