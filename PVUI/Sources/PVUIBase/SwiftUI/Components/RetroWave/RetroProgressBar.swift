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
            // Animate progress
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                progress = 1.0
            }
        }
    }
}
