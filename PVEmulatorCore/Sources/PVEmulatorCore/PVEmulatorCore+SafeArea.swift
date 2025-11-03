//
//  PVEmulatorCore+SafeArea.swift
//  Provenance
//
//  Created by AI Assistant
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Protocol for cores that support safe area inset updates
@objc
public protocol EmulatorCoreSafeAreaSupport {
    /// Update safe area insets for the core
    /// - Parameter safeInsets: The safe area insets from the view controller
    @objc func updateSafeAreaInsets(_ safeInsets: UIEdgeInsets)
}

/// Protocol for view controllers that support custom positioning (for DeltaSkin support)
/// Defined in PVEmulatorCore so cores can use it without UI dependencies
@objc
public protocol CustomPositioningSupport {
    /// Flag to indicate that custom positioning is being used
    var useCustomPositioning: Bool { get set }

    /// Custom frame to use when useCustomPositioning is true
    var customFrame: CGRect { get set }
}
