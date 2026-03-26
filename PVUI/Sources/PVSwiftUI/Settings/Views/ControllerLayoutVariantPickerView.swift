//
//  ControllerLayoutVariantPickerView.swift
//  PVUI
//
//  SwiftUI picker for selecting a per-system controller layout variant
//  (e.g. Genesis 3-Button vs 6-Button, Wii Wiimote vs Classic Controller).
//

import SwiftUI
import PVCoreBridge

/// An inline settings row that lets the user pick a controller layout variant
/// for a specific console (e.g. Genesis 3-Button vs 6-Button Pad).
struct ControllerLayoutVariantPicker: View {
    let variants: [ControllerLayoutVariant]
    let selectedVariantID: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("CONTROLLER LAYOUT")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.4))
            )

            // Variant options
            VStack(alignment: .leading, spacing: 6) {
                ForEach(variants) { variant in
                    VariantRow(
                        variant: variant,
                        isSelected: variant.id == selectedVariantID
                    ) {
                        onSelect(variant.id)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(Color.black.opacity(0.2))
            .cornerRadius(6)
        }
    }
}

// MARK: - Variant Row

private struct VariantRow: View {
    let variant: ControllerLayoutVariant
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: variant.sfSymbol)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .retroPink : .white.opacity(0.6))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(variant.displayName)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.75))

                    if let desc = variant.description {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.retroPink.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                isSelected ? Color.retroPink.opacity(0.4) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        #if os(tvOS)
        .retroFocusButtonStyle(showBorder: true)
        #else
        .buttonStyle(.plain)
        #endif
    }
}
