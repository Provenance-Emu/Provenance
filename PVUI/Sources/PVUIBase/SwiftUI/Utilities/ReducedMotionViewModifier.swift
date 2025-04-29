//
//  ReducedMotionViewModifier.swift
//  PVUIBase
//
//  Created by Joseph Mattiello on 4/27/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI

/// A view modifier that applies animations conditionally based on reduced motion settings
public struct ReducedMotionViewModifier<Value: Equatable>: ViewModifier {
    /// Whether to respect reduced motion settings
    let respectReducedMotion: Bool
    
    /// The animation to apply when reduced motion is not enabled
    let animation: Animation?
    
    /// The value to animate
    let value: Value
    
    /// The environment's reduced motion setting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    /// Initialize a new ReducedMotionViewModifier
    /// - Parameters:
    ///   - respectReducedMotion: Whether to respect reduced motion settings
    ///   - animation: The animation to apply when reduced motion is not enabled
    ///   - value: The value to animate
    public init(respectReducedMotion: Bool = true, animation: Animation?, value: Value) {
        self.respectReducedMotion = respectReducedMotion
        self.animation = animation
        self.value = value
    }
    
    public func body(content: Content) -> some View {
        if respectReducedMotion && reduceMotion {
            // No animation when reduced motion is enabled
            content
        } else {
            // Apply animation when reduced motion is not enabled
            content.animation(animation, value: value)
        }
    }
}

/// A view modifier that applies transitions conditionally based on reduced motion settings
public struct ReducedMotionTransitionViewModifier: ViewModifier {
    /// Whether to respect reduced motion settings
    let respectReducedMotion: Bool
    
    /// The transition to apply when reduced motion is not enabled
    let transition: AnyTransition
    
    /// The fallback transition to use when reduced motion is enabled
    let fallbackTransition: AnyTransition
    
    /// The environment's reduced motion setting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    /// Initialize a new ReducedMotionTransitionViewModifier
    /// - Parameters:
    ///   - respectReducedMotion: Whether to respect reduced motion settings
    ///   - transition: The transition to apply when reduced motion is not enabled
    ///   - fallbackTransition: The fallback transition to use when reduced motion is enabled
    public init(
        respectReducedMotion: Bool = true,
        transition: AnyTransition,
        fallbackTransition: AnyTransition = .opacity
    ) {
        self.respectReducedMotion = respectReducedMotion
        self.transition = transition
        self.fallbackTransition = fallbackTransition
    }
    
    public func body(content: Content) -> some View {
        if respectReducedMotion && reduceMotion {
            // Use fallback transition when reduced motion is enabled
            content.transition(fallbackTransition)
        } else {
            // Apply transition when reduced motion is not enabled
            content.transition(transition)
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Apply animation with respect to reduced motion settings
    /// - Parameters:
    ///   - respectReducedMotion: Whether to respect reduced motion settings
    ///   - animation: The animation to apply when reduced motion is not enabled
    ///   - value: The value to animate
    /// - Returns: A view with conditional animation
    func animateWithReducedMotion<Value>(
        respectReducedMotion: Bool = true,
        _ animation: Animation?,
        value: Value
    ) -> some View where Value: Equatable {
        modifier(ReducedMotionViewModifier<Value>(
            respectReducedMotion: respectReducedMotion,
            animation: animation,
            value: value
        ))
    }
    
    /// Apply transition with respect to reduced motion settings
    /// - Parameters:
    ///   - respectReducedMotion: Whether to respect reduced motion settings
    ///   - transition: The transition to apply when reduced motion is not enabled
    ///   - fallbackTransition: The fallback transition to use when reduced motion is enabled
    /// - Returns: A view with conditional transition
    func transitionWithReducedMotion(
        respectReducedMotion: Bool = true,
        _ transition: AnyTransition,
        fallbackTransition: AnyTransition = .opacity
    ) -> some View {
        modifier(ReducedMotionTransitionViewModifier(
            respectReducedMotion: respectReducedMotion,
            transition: transition,
            fallbackTransition: fallbackTransition
        ))
    }
}
