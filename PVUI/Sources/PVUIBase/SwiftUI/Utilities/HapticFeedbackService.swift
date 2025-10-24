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
/// A service that provides haptic feedback for user interactions
public final class HapticFeedbackService {
    /// The shared instance of the haptic feedback service
    public static let shared = HapticFeedbackService()
    
    /// Whether haptic feedback is enabled
    @AppStorage("hapticFeedbackEnabled") private var isEnabled: Bool = true
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Play success feedback
    /// - Parameter intensity: The intensity of the feedback (0.0-1.0)
    public func playSuccess(intensity: CGFloat = 1.0) {
        guard isEnabled else { return }
        
        VLOG("Playing success haptic feedback")
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Play error feedback
    public func playError() {
        guard isEnabled else { return }
        
        VLOG("Playing error haptic feedback")
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Play warning feedback
    public func playWarning() {
        guard isEnabled else { return }
        
        VLOG("Playing warning haptic feedback")
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Play selection feedback
    /// - Parameter style: The style of the feedback
    public func playSelection(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        
        VLOG("Playing selection haptic feedback")
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    /// Play custom feedback pattern
    /// - Parameter events: The haptic events to play
//    public func playCustomPattern(events: [UIHapticEvent]) {
//        guard isEnabled else { return }
//        
//        VLOG("Playing custom haptic pattern")
//        if #available(iOS 17.0, *) {
//            do {
//                let engine = try CHHapticEngine()
//                try engine.start()
//                
//                let pattern = try CHHapticPattern(events: events, parameters: [])
//                let player = try engine.makePlayer(with: pattern)
//                try player.start(atTime: 0)
//            } catch {
//                ELOG("Failed to play haptic pattern: \(error.localizedDescription)")
//            }
//        } else {
//            // Fallback for older iOS versions
//            playSelection()
//        }
//    }
    
    /// Toggle haptic feedback
    /// - Returns: The new state
    @discardableResult
    public func toggle() -> Bool {
        isEnabled.toggle()
        return isEnabled
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
