import SwiftUI
import UIKit

/// A component that creates retrowave-styled effects around the Dynamic Island
public struct RetroDynamicIsland: View {
    @State private var isAnimating = false
    @State private var dynamicIslandFrame: CGRect = .zero
    @State private var deviceHasDynamicIsland = false
    
    // Animation properties
    @State private var pulseOpacity: Double = 0.0
    @State private var glowRadius: CGFloat = 2.0
    @State private var colorShift: CGFloat = 0.0
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Only show effects if the device has a Dynamic Island
                if deviceHasDynamicIsland {
                    // Retrowave glow effect around the Dynamic Island
                    dynamicIslandOutlineView
                        .opacity(isAnimating ? 0.8 : 0.4)
                        .blur(radius: glowRadius)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    
                    // Pulse effect
                    dynamicIslandPulseView
                        .opacity(pulseOpacity)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseOpacity)
                }
            }
            .onAppear {
                // Check if device has Dynamic Island
                checkForDynamicIsland()
                
                // Start animations if device has Dynamic Island
                if deviceHasDynamicIsland {
                    startAnimations()
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // Retrowave outline around the Dynamic Island
    private var dynamicIslandOutlineView: some View {
        Path { path in
            if !dynamicIslandFrame.isEmpty {
                // Create a rounded rectangle path around the Dynamic Island
                let expandedFrame = dynamicIslandFrame.insetBy(dx: -6, dy: -6)
                let cornerRadius: CGFloat = dynamicIslandFrame.height / 2 + 6
                
                // Use the correct API for adding a rounded rectangle to a path
                let cornerSize = CGSize(width: cornerRadius, height: cornerRadius)
                path.addRoundedRect(in: expandedFrame, cornerSize: cornerSize)
            }
        }
        .stroke(
            LinearGradient(
                gradient: Gradient(colors: [
                    RetroTheme.retroPink,
                    RetroTheme.retroPurple,
                    RetroTheme.retroBlue
                ]),
                startPoint: UnitPoint(x: colorShift, y: 0),
                endPoint: UnitPoint(x: colorShift + 1, y: 0)
            ),
            lineWidth: 1.5
        )
    }
    
    // Pulse effect that emanates from the Dynamic Island
    private var dynamicIslandPulseView: some View {
        Path { path in
            if !dynamicIslandFrame.isEmpty {
                // Create a rounded rectangle path around the Dynamic Island
                let expandedFrame = dynamicIslandFrame.insetBy(dx: -15, dy: -15)
                let cornerRadius: CGFloat = dynamicIslandFrame.height / 2 + 15
                
                // Use the correct API for adding a rounded rectangle to a path
                let cornerSize = CGSize(width: cornerRadius, height: cornerRadius)
                path.addRoundedRect(in: expandedFrame, cornerSize: cornerSize)
            }
        }
        .stroke(
            RetroTheme.retroPink.opacity(0.3),
            lineWidth: 1
        )
    }
    
    // Check if the device has a Dynamic Island
    private func checkForDynamicIsland() {
        // Get the safe area insets
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            let safeAreaInsets = window.safeAreaInsets
            
            // Calculate the Dynamic Island frame based on safe area insets
            // The Dynamic Island is typically centered at the top of the screen
            let screenWidth = window.screen.bounds.width
            
            // Check if device has a center notch (Dynamic Island)
            // This is a heuristic - devices with Dynamic Island have a distinctive top inset pattern
            let hasCenterNotch = safeAreaInsets.top > 50
            
            if hasCenterNotch {
                deviceHasDynamicIsland = true
                
                // Approximate the Dynamic Island dimensions
                // These values are based on iPhone 14 Pro/15 Pro dimensions
                let islandWidth: CGFloat = 126
                let islandHeight: CGFloat = 37
                
                dynamicIslandFrame = CGRect(
                    x: (screenWidth - islandWidth) / 2,
                    y: 0,
                    width: islandWidth,
                    height: islandHeight
                )
            }
        }
    }
    
    // Start the animations for the Dynamic Island effects
    private func startAnimations() {
        // Start the main animation
        isAnimating = true
        
        // Start the pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.7
        }
        
        // Start the color shift animation
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            colorShift = 1.0
        }
        
        // Start the glow radius animation
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowRadius = 4.0
        }
    }
}

// MARK: - Preview
struct RetroDynamicIsland_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            RetroDynamicIsland()
        }
    }
}
