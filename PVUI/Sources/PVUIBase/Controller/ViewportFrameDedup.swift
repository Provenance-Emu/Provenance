//
//  ViewportFrameDedup.swift
//  PVUIBase
//
//  The "has the game viewport actually changed?" decision shared by the skin
//  viewport paths of PVEmulatorViewController.
//

import CoreGraphics

enum ViewportFrameDedup {
    /// Frames closer than this on every edge count as the same frame.
    static let tolerance: CGFloat = 0.5

    static func isSame(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < tolerance && abs(lhs.origin.y - rhs.origin.y) < tolerance
            && abs(lhs.width - rhs.width) < tolerance && abs(lhs.height - rhs.height) < tolerance
    }

    /// Whether `new` should be applied over `current`. `force` re-applies an unchanged
    /// frame, for changes that alter how the frame is used rather than the frame itself
    /// (a scaling-mode switch).
    static func shouldApply(new: CGRect, current: CGRect?, force: Bool) -> Bool {
        guard !force, let current else { return true }
        return !isSame(new, current)
    }
}
