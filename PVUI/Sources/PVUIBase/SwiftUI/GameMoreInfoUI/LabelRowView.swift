//
//  LabelRowView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/9/24.
//

import SwiftUI

/// A reusable view for displaying a label and value pair with optional editing
struct LabelRowView: View {
    let label: String
    let value: String?
    var onLongPress: (() -> Void)?
    var isEditable: Bool = true

    // RetroWave styling properties
    var labelColor: Color = .secondary
    var valueColor: Color = .primary
    #if os(tvOS)
    var backgroundColor: Color = .init(red: 0.96, green: 0.96, blue: 0.96)
    #else
    var backgroundColor: Color = Color(.systemBackground)
    #endif
    var borderGradient: LinearGradient? = nil

    // Animation states
    @State private var glowOpacity: Double = 0.7
    @State private var isHovered: Bool = false
    #if os(tvOS)
    @FocusState private var isFocused: Bool
    #endif

    /// Computed property to determine what text to display
    private var displayText: String {
        if let value = value, !value.isEmpty {
            return value
        } else if isEditable {
            #if os(tvOS)
            return "Select to edit"
            #else
            return "Tap to edit"
            #endif
        } else {
            return "Not available"
        }
    }

    /// Computed property to determine text color
    private var textColor: Color {
        if value == nil || value?.isEmpty == true {
            return isEditable ? labelColor.opacity(0.7) : .gray
        } else {
            return valueColor
        }
    }

    var body: some View {
        #if os(tvOS)
        // tvOS: Use Button for proper focus handling
        Button(action: {
            if isEditable {
                onLongPress?()
            }
        }) {
            rowContent
        }
        .buttonStyle(TVOSLabelRowButtonStyle(
            isEditable: isEditable,
            labelColor: labelColor,
            backgroundColor: backgroundColor,
            borderGradient: borderGradient,
            glowOpacity: glowOpacity
        ))
        .disabled(!isEditable)
        .focused($isFocused)
        .onChange(of: isFocused) { focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = focused
            }
        }
        .frame(height: 60)
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
        #else
        ZStack {
            // Background with retrowave styling
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)

            // Optional border with gradient
            if let gradient = borderGradient {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(gradient, lineWidth: isHovered || isEditable ? 1.5 : 1.0)
                    .shadow(color: labelColor.opacity(glowOpacity * (isHovered ? 0.8 : 0.4)),
                            radius: isHovered ? 5 : 3,
                            x: 0,
                            y: 0)
            }

            rowContent
        }
        .frame(height: 40)
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering && isEditable
            }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
        #endif
    }

    private var rowContent: some View {
        HStack {
            // Label side - right aligned with retrowave styling
            Text(label + ":")
                #if os(tvOS)
                .font(.system(size: 20, weight: .bold))
                .frame(width: 180, alignment: .trailing)
                #else
                .font(.system(size: 14, weight: .bold))
                .frame(width: 120, alignment: .trailing)
                #endif
                .foregroundColor(labelColor)
                .shadow(color: labelColor.opacity(glowOpacity * 0.5), radius: 2, x: 0, y: 0)

            // Value side - left aligned with placeholder for empty values
            HStack {
                Text(displayText)
                    #if os(tvOS)
                    .font(.system(size: 22, weight: .medium))
                    #endif
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isEditable {
                    Image(systemName: "pencil")
                        #if os(tvOS)
                        .font(.system(size: 20))
                        #else
                        .font(.caption)
                        #endif
                        .foregroundColor(labelColor)
                        .shadow(color: labelColor.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                }
            }
            #if !os(tvOS)
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditable {
                    Haptics.impact(style: .light)
                    onLongPress?()
                }
            }
            #endif
        }
        .padding(.horizontal, 12)
        #if os(tvOS)
        .padding(.vertical, 12)
        #else
        .padding(.vertical, 8)
        #endif
    }
}

#if os(tvOS)
/// Custom button style for tvOS LabelRowView
private struct TVOSLabelRowButtonStyle: ButtonStyle {
    let isEditable: Bool
    let labelColor: Color
    let backgroundColor: Color
    let borderGradient: LinearGradient?
    let glowOpacity: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor.opacity(configuration.isPressed ? 0.9 : 0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        borderGradient ?? LinearGradient(colors: [labelColor], startPoint: .leading, endPoint: .trailing),
                        lineWidth: isEditable ? 2 : 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 1.02 : 1.0)
            .shadow(
                color: isEditable ? labelColor.opacity(glowOpacity * 0.6) : .clear,
                radius: configuration.isPressed ? 8 : 4,
                x: 0,
                y: 0
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
#endif
