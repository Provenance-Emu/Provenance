//
//  HapticFeedbackService.swift
//  PVUIBase
//
//  Created by Joseph Mattiello on 4/27/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import UIKit
import PVLogging

#if !os(tvOS)
/// A service that provides haptic feedback for user interactions.
/// No switch of its own: iOS Settings › Sounds & Haptics › System Haptics already governs these.
public final class HapticFeedbackService {
    /// The shared instance of the haptic feedback service
    public static let shared = HapticFeedbackService()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Play success feedback
    /// - Parameter intensity: The intensity of the feedback (0.0-1.0)
    public func playSuccess(intensity: CGFloat = 1.0) {
        VLOG("Playing success haptic feedback")
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Play error feedback
    public func playError() {
        VLOG("Playing error haptic feedback")
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Play warning feedback
    public func playWarning() {
        VLOG("Playing warning haptic feedback")
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Play selection feedback
    /// - Parameter style: The style of the feedback
    public func playSelection(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        VLOG("Playing selection haptic feedback")
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

/// A view modifier that adds haptic feedback to a view
public struct HapticFeedbackModifier: ViewModifier {
    /// The style of the haptic feedback
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    
    /// Initialize a new HapticFeedbackModifier
    /// - Parameter style: The style of the haptic feedback
    public init(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        self.style = style
    }
    
    public func body(content: Content) -> some View {
        content
            .onTapGesture {
                HapticFeedbackService.shared.playSelection(style: style)
            }
    }
}

// MARK: - View Extension

public extension View {
    /// Add haptic feedback to a view
    /// - Parameter style: The style of the haptic feedback
    /// - Returns: A view with haptic feedback
    func withHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        modifier(HapticFeedbackModifier(style: style))
    }
}
#endif
