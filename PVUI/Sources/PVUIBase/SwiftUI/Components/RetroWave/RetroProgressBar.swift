//
//  RetroProgressBar.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI

// Retrowave progress bar
public struct RetroProgressBar: View {
    @State private var progress: CGFloat = 0
    
    // Accessibility setting for reduce motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Animated progress
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.retroBlue, .retroPink]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * progress, height: geometry.size.height)
                    .cornerRadius(4)
            }
        }
        .onAppear {
            if reduceMotion {
                // If reduce motion is enabled, set a static progress value
                // Use a value between 0.5-0.7 to indicate progress without animation
                progress = 0.6
            } else {
                // Animate progress only if reduce motion is disabled
                withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    progress = 1.0
                }
            }
        }
    }
}
