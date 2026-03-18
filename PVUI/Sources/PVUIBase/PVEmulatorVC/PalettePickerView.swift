//
//  PalettePickerView.swift
//  PVUI
//
//  Part of #2649 — Custom Palette System (sub-task 5: Palette Picker SwiftUI View)
//
//  Shows all palettes exposed by a ``PaletteProviding`` core as a scrollable grid of
//  colour swatches.  The current palette is highlighted with a neon ring.
//  Tapping any swatch applies it immediately so the user can preview in real time.
//

import SwiftUI
import PVCoreBridge
import PVThemes
#if os(iOS)
import UIKit
#endif

// MARK: - PalettePickerView

/// Sheet that lets the user pick a palette from the core's `availablePalettes`.
///
/// - Parameters:
///   - paletteCore: Any emulator core conforming to `PaletteProviding`.
///   - onDismiss: Called when the user confirms / dismisses the sheet.
struct PalettePickerView: View {

    let paletteCore: any PaletteProviding
    let onDismiss: () -> Void

    /// Tracks the id of the currently-selected palette so the UI stays reactive.
    @State private var selectedID: String

    init(paletteCore: any PaletteProviding, onDismiss: @escaping () -> Void) {
        self.paletteCore = paletteCore
        self.onDismiss = onDismiss
        self._selectedID = State(initialValue: paletteCore.currentPaletteID)
    }

    // MARK: - Grid layout

    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 140), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(paletteCore.availablePalettes) { pal in
                        Button {
                            selectedID = pal.id
                            paletteCore.selectPalette(id: pal.id)
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        } label: {
                            PaletteSwatchView(
                                palette: pal,
                                isSelected: pal.id == selectedID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "Choose Palette"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { onDismiss() }
                        .foregroundColor(.retroPurple)
                        .fontWeight(.semibold)
                }
            }
        }
        #if os(tvOS)
        // On tvOS the hardware Menu button is the standard way to dismiss sheets.
        .onExitCommand { onDismiss() }
        #else
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.black.opacity(0.95))
        #endif
    }
}

// MARK: - PaletteSwatchView

/// A single palette swatch cell: coloured stripes + label, with a selection ring.
private struct PaletteSwatchView: View {

    let palette: CorePalette
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            swatchStripes
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected
                                ? Color.retroPurple
                                : Color.white.opacity(0.15),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .shadow(
                    color: isSelected ? Color.retroPurple.opacity(0.7) : .clear,
                    radius: 8, x: 0, y: 0
                )

            Text(palette.displayName)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .retroPurple : .white.opacity(0.75))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }

    /// Horizontal colour stripes representing the palette shades.
    @ViewBuilder
    private var swatchStripes: some View {
        let colors = palette.colors
        if colors.isEmpty {
            Color.gray.opacity(0.3)
        } else {
            GeometryReader { geo in
                let stripeWidth = geo.size.width / CGFloat(colors.count)
                HStack(spacing: 0) {
                    ForEach(colors.indices, id: \.self) { i in
                        let c = colors[i]
                        Color(
                            red: Double(c.red),
                            green: Double(c.green),
                            blue: Double(c.blue)
                        )
                        .frame(width: stripeWidth)
                    }
                }
            }
        }
    }
}
