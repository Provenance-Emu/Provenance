//
//  EmulatorWithSkinView+DefaultSkin.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/28/25.
//

import SwiftUI

// MARK: - Default Controller
extension EmulatorWithSkinView {

    /// Default controller skin as a fallback
    internal func defaultControllerSkin() -> some View {
        VStack(spacing: 20) {
            // D-Pad
            dPadView()
            
            // Action buttons
            HStack(spacing: 10) {
                VStack(spacing: 10) {
                    circleButton(label: "Y", color: .yellow)
                    circleButton(label: "X", color: .blue)
                }
                
                VStack(spacing: 10) {
                    circleButton(label: "B", color: .red)
                    circleButton(label: "A", color: .green)
                }
            }
            
            // Start/Select buttons
            HStack(spacing: 20) {
                pillButton(label: "SELECT", color: .black)
                pillButton(label: "START", color: .black)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.5))
        .cornerRadius(20)
    }
    
    /// D-Pad view
    private func dPadView() -> some View {
        VStack(spacing: 0) {
            Button(action: { inputHandler.buttonPressed("up") }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in inputHandler.buttonReleased("up") }
            )
            
            HStack(spacing: 0) {
                Button(action: { inputHandler.buttonPressed("left") }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in inputHandler.buttonReleased("left") }
                )
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
                
                Button(action: { inputHandler.buttonPressed("right") }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in inputHandler.buttonReleased("right") }
                )
            }
            
            Button(action: { inputHandler.buttonPressed("down") }) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in inputHandler.buttonReleased("down") }
            )
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
    }
    
    /// Circle button view
    private func circleButton(label: String, color: Color) -> some View {
        Button(action: { inputHandler.buttonPressed(label.lowercased()) }) {
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in inputHandler.buttonReleased(label.lowercased()) }
        )
    }
    
    /// Pill-shaped button view
    private func pillButton(label: String, color: Color) -> some View {
        Button(action: { inputHandler.buttonPressed(label.lowercased()) }) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 30)
                .background(color)
                .cornerRadius(15)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in inputHandler.buttonReleased(label.lowercased()) }
        )
    }
}
