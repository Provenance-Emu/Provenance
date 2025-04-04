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
    var backgroundColor: Color = Color(.systemBackground)
    var borderGradient: LinearGradient? = nil
    
    // Animation states
    @State private var glowOpacity: Double = 0.7
    @State private var isHovered: Bool = false

    /// Computed property to determine what text to display
    private var displayText: String {
        if let value = value, !value.isEmpty {
            return value
        } else if isEditable {
            return "Tap to edit"
        } else {
            return "Not available"
        }
    }

    /// Computed property to determine text color
    private var textColor: Color {
        if value == nil || value?.isEmpty == true {
            return isEditable ? RetroTheme.retroBlue.opacity(0.7) : .gray
        } else {
            return valueColor
        }
    }

    var body: some View {
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
            
            // Content
            HStack {
                // Label side - right aligned with retrowave styling
                Text(label + ":")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 120, alignment: .trailing)
                    .foregroundColor(labelColor)
                    .shadow(color: labelColor.opacity(glowOpacity * 0.5), radius: 2, x: 0, y: 0)

                // Value side - left aligned with placeholder for empty values
                HStack {
                    Text(displayText)
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isEditable {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(RetroTheme.retroPink)
                            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                    }
                }
                .contentShape(Rectangle()) // Make entire area tappable
                .onTapGesture {
                    if isEditable {
                        #if !os(tvOS)
                        Haptics.impact(style: .light)
                        #endif
                        onLongPress?()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 40)
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering && isEditable
            }
        }
        .onAppear {
            // Start animations
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}
