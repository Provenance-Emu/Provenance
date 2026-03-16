// CompanionLayoutProtocol.swift
// PVUI
//
// Protocol that every system-specific companion controller layout conforms to.
// Layouts are SwiftUI Views that describe the overlay rendered on the companion
// device (iPhone/iPad) while the game video plays on a larger screen.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import SwiftUI

// MARK: - CompanionLayoutProtocol

/// A SwiftUI view that provides a system-specific input overlay for a companion controller session.
///
/// Implement this protocol for each retro system that needs a custom overlay
/// (numpad, keyboard, trackball, etc.). The host view (`CompanionControllerHostView`)
/// instantiates the correct layout based on the active system identifier.
///
/// Example:
/// ```swift
/// struct Atari5200Layout: CompanionLayout {
///     var systemID: String { "com.provenance.atari5200" }
///     var displayName: String { "Atari 5200" }
///     let inputRouter: CompanionInputRouter
///
///     var body: some View {
///         NumpadOverlayView(router: inputRouter)
///     }
/// }
/// ```
public protocol CompanionLayout: View {
    /// The system identifier this layout targets (e.g. `"com.provenance.atari5200"`).
    var systemID: String { get }

    /// Human-readable system name shown in the session UI.
    var displayName: String { get }

    /// Routes touch events from this layout to the DSU slot.
    var inputRouter: CompanionInputRouter { get }
}

// MARK: - CompanionLayoutFactory

/// Returns the appropriate `CompanionLayout` for a given system identifier.
///
/// Register new system layouts here. Falls back to `GenericCompanionLayout` for unknown systems.
@MainActor
public enum CompanionLayoutFactory {
    public static func makeLayout(
        systemID: String,
        router: CompanionInputRouter
    ) -> any CompanionLayout {
        switch systemID {
        default:
            return GenericCompanionLayout(router: router)
        }
    }
}
