//
//  RetroProgressBar.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI

// Retrowave progress bar
public struct RetroProgressBar: View {
    /// When set, the bar tracks this real value instead of animating.
    private let realProgress: Double?

    @State private var animatedProgress: CGFloat = 0

    // Accessibility setting for reduce motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Create a progress bar.
    /// - Parameter progress: If `nil`, the bar uses a looping fake animation
    ///   (legacy behaviour). Pass a value in 0.0–1.0 to show real progress.
    public init(progress: Double? = nil) {
        self.realProgress = progress
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // Animated progress
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.retroBlue, .retroPink]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(x: displayProgress, y: 1, anchor: .leading)
                .cornerRadius(4)
                .animation(.easeInOut(duration: 0.3), value: displayProgress)
        }
        .onAppear {
            guard realProgress == nil else { return }
            // Legacy fake animation — only used when no real progress is supplied.
            if reduceMotion {
                animatedProgress = 0.6
            } else {
                withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    animatedProgress = 1.0
                }
            }
        }
    }

    private var displayProgress: CGFloat {
        if let real = realProgress {
            return CGFloat(max(0, min(1, real)))
        }
        return animatedProgress
    }
}
