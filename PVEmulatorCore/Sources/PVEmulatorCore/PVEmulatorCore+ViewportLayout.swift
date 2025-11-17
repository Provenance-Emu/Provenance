//
//  PVEmulatorCore+ViewportLayout.swift
//
//  Protocol-based viewport layout communication for DeltaSkins
//  Replaces notification-based system with proper protocol
//

import Foundation
import CoreGraphics

/// Protocol for objects that can provide viewport layout information
/// Used by DeltaSkins to calculate screen frame positions
@objc
public protocol PVViewportLayoutProvider: AnyObject {
    /// Calculate the viewport frame for the given constraints
    /// - Parameters:
    ///   - containerSize: Size of the container view
    ///   - safeInsets: Safe area insets
    ///   - isLandscape: Whether the device is in landscape orientation
    /// - Returns: The calculated viewport frame wrapped in NSValue, or nil if calculation failed
    @objc func calculateViewportFrame(
        containerSize: CGSize,
        safeInsets: UIEdgeInsets,
        isLandscape: Bool
    ) -> NSValue?

    /// Notify that viewport frame should be recalculated
    /// Called when layout constraints change (rotation, safe area changes, etc.)
    @objc func requestViewportRecalculation()
}

/// Protocol for objects that need to receive viewport frame updates
/// Implemented by PVEmulatorViewController to receive layout updates
@objc
public protocol PVViewportLayoutDelegate: AnyObject {
    /// Called when a new viewport frame is calculated
    /// - Parameter frame: The new viewport frame
    @objc func viewportFrameDidUpdate(_ frame: CGRect)
}

/// Extension to PVEmulatorCore to support viewport layout protocol
@objc
extension PVEmulatorCore {
    /// Weak reference to viewport layout provider (typically a DeltaSkin view)
    @objc public weak var viewportLayoutProvider: PVViewportLayoutProvider? {
        get {
            // Use associated object to store weak reference
            return objc_getAssociatedObject(self, &AssociatedKeys.viewportLayoutProvider) as? PVViewportLayoutProvider
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.viewportLayoutProvider,
                newValue,
                .OBJC_ASSOCIATION_ASSIGN
            )
        }
    }

    /// Weak reference to viewport layout delegate (typically PVEmulatorViewController)
    @objc public weak var viewportLayoutDelegate: PVViewportLayoutDelegate? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.viewportLayoutDelegate) as? PVViewportLayoutDelegate
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.viewportLayoutDelegate,
                newValue,
                .OBJC_ASSOCIATION_ASSIGN
            )
        }
    }

    /// Request viewport recalculation from the layout provider
    /// Called when rotation or layout changes occur
    @objc public func requestViewportRecalculation() {
        viewportLayoutProvider?.requestViewportRecalculation()
    }
}

/// Associated object keys - using static addresses
/// Note: Associated objects are accessed via objc runtime which handles thread safety
private struct AssociatedKeys {
    nonisolated(unsafe) static var viewportLayoutProvider: UInt8 = 0
    nonisolated(unsafe) static var viewportLayoutDelegate: UInt8 = 0
}

#if !os(macOS) && !os(watchOS)
import UIKit
#endif
