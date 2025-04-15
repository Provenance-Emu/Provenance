//
//  RetroWaveSlider.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI
import PVThemes

/// A custom slider with retrowave styling
public struct RetroWaveSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value.Stride
    let onEditingChanged: (Bool) -> Void
    
    // Optional parameters for customizing the slider appearance
    var minimumValueLabel: (() -> Text)? = nil
    var maximumValueLabel: (() -> Text)? = nil
    var label: (() -> Text)? = nil
    var leadingIcon: (() -> AnyView)? = nil
    var trailingIcon: (() -> AnyView)? = nil
    
    @State private var isEditing = false
    @State private var glowOpacity = 0.0
    @State private var geometry: GeometryProxy? = nil
    
    public init(value: Binding<Value>, 
                in range: ClosedRange<Value>, 
                step: Value.Stride = 1.0,
                onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self._value = value
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
    }
    
    // Initializer with icons
    public init<V1: View, V2: View, V3: View, V4: View>(
                value: Binding<Value>, 
                in range: ClosedRange<Value>, 
                step: Value.Stride = 1.0,
                onEditingChanged: @escaping (Bool) -> Void = { _ in },
                @ViewBuilder label: @escaping () -> Text,
                @ViewBuilder minimumValueLabel: @escaping () -> V1,
                @ViewBuilder maximumValueLabel: @escaping () -> V2,
                @ViewBuilder leadingIcon: @escaping () -> V3,
                @ViewBuilder trailingIcon: @escaping () -> V4) {
        self._value = value
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
        self.label = label
        
        // Store the labels if they're Text views
        if let minLabel = (minimumValueLabel() as? Text) {
            self.minimumValueLabel = { minLabel }
        }
        
        if let maxLabel = (maximumValueLabel() as? Text) {
            self.maximumValueLabel = { maxLabel }
        }
        
        // Store icons
        if !(leadingIcon() is EmptyView) {
            self.leadingIcon = { AnyView(leadingIcon()) }
        }
        
        if !(trailingIcon() is EmptyView) {
            self.trailingIcon = { AnyView(trailingIcon()) }
        }
    }
    
    // Initializer with labels
    public init<V1: View, V2: View>(value: Binding<Value>, 
                in range: ClosedRange<Value>, 
                step: Value.Stride = 1.0,
                onEditingChanged: @escaping (Bool) -> Void = { _ in },
                @ViewBuilder label: @escaping () -> Text,
                @ViewBuilder minimumValueLabel: @escaping () -> V1,
                @ViewBuilder maximumValueLabel: @escaping () -> V2) {
        self._value = value
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
        self.label = label
        
        // Store the labels if they're Text views
        if let minLabel = (minimumValueLabel() as? Text) {
            self.minimumValueLabel = { minLabel }
        }
        
        if let maxLabel = (maximumValueLabel() as? Text) {
            self.maximumValueLabel = { maxLabel }
        }
    }
    
    public var body: some View {
        GeometryReader { geo in
            VStack(spacing: 8) {
                // Optional label at the top
                if let label = label {
                    label()
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Custom slider track and thumb
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                        .frame(height: 8)
                        .overlay(
                            Capsule()
                                .strokeBorder(RetroTheme.retroBlue.opacity(0.5), lineWidth: 1)
                        )
                    
                    // Filled track
                    let fillWidth = calculateFillWidth(in: geo)
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, CGFloat(fillWidth)), height: 8)
                    
                    // Thumb
                    let thumbPosition = calculateThumbPosition(in: geo)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: isEditing ? RetroTheme.retroPink : RetroTheme.retroPurple.opacity(0.7), 
                                radius: isEditing ? 6 : 4)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isEditing ? RetroTheme.retroPink : RetroTheme.retroPurple,
                                    lineWidth: 2
                                )
                        )
                        .position(x: thumbPosition, y: 12) // Position using absolute coordinates
                }
                .frame(height: 24) // Height for the slider track
                .contentShape(Rectangle()) // Make the entire area tappable
#if os(tvOS)
                .focusable(false)
#else
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isEditing {
                                isEditing = true
                                onEditingChanged(true)
                                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                    glowOpacity = 0.8
                                }
                            }
                            updateValue(for: gesture.location.x, in: geo)
                        }
                        .onEnded { _ in
                            isEditing = false
                            onEditingChanged(false)
                            glowOpacity = 0.0
                        }
                )
#endif
                
                // Value labels
                HStack {
                    // Leading icon (if provided)
                    if let leadingIcon = leadingIcon {
                        leadingIcon()
                            .frame(width: 16, height: 16)
                    }
                    
                    // Left label (min value or custom)
                    if let minLabel = minimumValueLabel {
                        minLabel()
                            .font(.caption)
                            .foregroundColor(RetroTheme.retroBlue)
                    } else {
                        Text(formatValue(range.lowerBound))
                            .font(.caption)
                            .foregroundColor(RetroTheme.retroBlue)
                    }
                    
                    Spacer()
                    
                    // Current value in the middle
                    Text(formatValue(value))
                        .font(.caption.bold())
                        .foregroundColor(isEditing ? RetroTheme.retroPink : .white)
                        .shadow(color: isEditing ? RetroTheme.retroPink.opacity(glowOpacity) : Color.clear, radius: 4)
                    
                    Spacer()
                    
                    // Right label (max value or custom)
                    if let maxLabel = maximumValueLabel {
                        maxLabel()
                            .font(.caption)
                            .foregroundColor(RetroTheme.retroBlue)
                    } else {
                        Text(formatValue(range.upperBound))
                            .font(.caption)
                            .foregroundColor(RetroTheme.retroBlue)
                    }
                    
                    // Trailing icon (if provided)
                    if let trailingIcon = trailingIcon {
                        trailingIcon()
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onAppear {
                geometry = geo
            }
        }
        .frame(height: 60) // Fixed height for the entire slider component
    }
    
    // MARK: - Private Methods
    
    /// Calculate the position of the thumb along the track
    private func calculateThumbPosition(in geometry: GeometryProxy) -> CGFloat {
        let width = geometry.size.width - 24 // Subtract thumb width
        let ratio = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
        return 12 + (width * CGFloat(ratio)) // Add half thumb width for centering
    }
    
    /// Calculate the width of the filled portion of the track
    private func calculateFillWidth(in geometry: GeometryProxy) -> CGFloat {
        let width = geometry.size.width - 24 // Subtract thumb width for accurate fill
        let ratio = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
        return (width * CGFloat(ratio)) + 12 // Add half thumb width for alignment
    }
    
    /// Update the slider value based on drag position
    private func updateValue(for position: CGFloat, in geometry: GeometryProxy) {
        let width = geometry.size.width - 24 // Account for thumb width
        let clampedPosition = max(0, min(width, position - 12)) // Clamp and adjust for thumb
        
        // Calculate new value based on position
        let ratio = Double(clampedPosition / width)
        let newValue = Value(Double(range.lowerBound) + ratio * Double(range.upperBound - range.lowerBound))
        
        // Apply step if needed
        if step > Value.Stride(0) {
            let steppedValue = Value(round(Double(newValue) / Double(step)) * Double(step))
            value = max(range.lowerBound, min(range.upperBound, steppedValue))
        } else {
            value = max(range.lowerBound, min(range.upperBound, newValue))
        }
    }
    
    /// Format a numeric value as a string
    private func formatValue(_ value: Value) -> String {
        let doubleValue = Double(value)
        // Use integer format for whole numbers, decimal format otherwise
        if doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(doubleValue))"
        } else {
            return String(format: "%.1f", doubleValue)
        }
    }
}

#Preview {
    VStack {
        RetroWaveSlider(value: .constant(50), in: 0...100)
            .padding()
        
        RetroWaveSlider(value: .constant(25), in: 0...100, step: 5)
            .padding()
    }
    .padding()
    .background(RetroTheme.retroBlack)
}
