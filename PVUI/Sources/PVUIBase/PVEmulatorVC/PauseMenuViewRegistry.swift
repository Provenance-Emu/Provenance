//
//  PauseMenuViewRegistry.swift
//  PVUIBase
//
//  Static registry allowing higher-level modules (PVSwiftUI) to inject
//  views into the pause menu without creating circular dependencies.
//

import SwiftUI

/// Registry for views that are defined in modules above PVUIBase (e.g. PVSwiftUI)
/// but need to appear in the pause menu (which lives in PVUIBase).
///
/// Higher-level modules call the `register*` methods at app launch; PVUIBase
/// reads the stored view builders at presentation time.
@MainActor
public enum PauseMenuViewRegistry {
    /// Builder for the RetroArch quick-settings view.
    /// Set by PVSwiftUI at app startup via `registerRetroArchSettingsView(_:)`.
    nonisolated(unsafe) private static var _retroArchSettingsBuilder: (() -> AnyView)?

    /// Register the RetroArch settings view builder.
    /// Call once at app launch from PVSwiftUI.
    public static func registerRetroArchSettingsView(_ builder: @escaping () -> AnyView) {
        _retroArchSettingsBuilder = builder
    }

    /// Returns the registered RetroArch settings view, or `nil` if none was registered.
    public static func retroArchSettingsView() -> AnyView? {
        _retroArchSettingsBuilder?()
    }
}
