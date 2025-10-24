//
//  PulseAnimation.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/8/25.
//

import SwiftUI

/// Pulse animation modifier for retrowave effect
public struct PulseAnimation: ViewModifier {
    public let isExpanded: Bool
    @State private var isPulsing = false
    
    public init(isExpanded: Bool = false) {
        self.isExpanded = isExpanded
    }
    
    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .onAppear {
                // Only animate when not expanded
                if !isExpanded {
                    withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: isExpanded) { newValue in
                // Stop animation when expanded
                if newValue {
                    isPulsing = false
                } else {
                    withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
    }
}
