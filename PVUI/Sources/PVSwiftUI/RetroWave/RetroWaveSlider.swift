//
//  RetroWaveSlider.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI
import PVThemes

/// A custom slider with retrowave styling
public struct RetroWaveSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onEditingChanged: (Bool) -> Void
    
    @State private var isEditing = false
    @State private var glowOpacity = 0.0
    
    public init(value: Binding<Double>, 
                in range: ClosedRange<Double>, 
                step: Double = 1.0,
                onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self._value = value
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Slider
            ZStack(alignment: .leading) {
                // Track background
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(height: 8)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(RetroTheme.retroBlue.opacity(0.5), lineWidth: 1)
                    )
                
                // Filled track
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth, height: 8)
                    .cornerRadius(4)
                
                // Thumb
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
                    .offset(x: thumbOffset - 12) // Center the thumb
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
                                
                                let width = geometry?.size.width ?? 0
                                let dragPosition = gesture.location.x
                                
                                // Calculate new value based on drag position
                                let ratio = max(0, min(1, dragPosition / width))
                                let newValue = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                                
                                // Apply step if needed
                                if step > 0 {
                                    let steppedValue = round(newValue / step) * step
                                    value = max(range.lowerBound, min(range.upperBound, steppedValue))
                                } else {
                                    value = max(range.lowerBound, min(range.upperBound, newValue))
                                }
                            }
                            .onEnded { _ in
                                isEditing = false
                                onEditingChanged(false)
                                glowOpacity = 0.0
                            }
                    )
            }
            .frame(height: 24) // Height for the slider track
            .background(GeometryReader { geo in
                Color.clear.onAppear {
                    geometry = geo
                }
            })
            
            // Value labels
            HStack {
                Text("\(range.lowerBound, specifier: "%.0f")")
                    .font(.caption)
                    .foregroundColor(RetroTheme.retroBlue)
                
                Spacer()
                
                Text("\(value, specifier: "%.0f")")
                    .font(.caption.bold())
                    .foregroundColor(isEditing ? RetroTheme.retroPink : .white)
                    .shadow(color: isEditing ? RetroTheme.retroPink.opacity(glowOpacity) : Color.clear, radius: 4)
                
                Spacer()
                
                Text("\(range.upperBound, specifier: "%.0f")")
                    .font(.caption)
                    .foregroundColor(RetroTheme.retroBlue)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Private Properties
    
    @State private var geometry: GeometryProxy?
    
    private var thumbOffset: CGFloat {
        let width = geometry?.size.width ?? 0
        if width == 0 { return 0 }
        
        let ratio = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return width * CGFloat(ratio)
    }
    
    private var fillWidth: CGFloat {
        let width = geometry?.size.width ?? 0
        if width == 0 { return 0 }
        
        let ratio = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return width * CGFloat(ratio)
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
