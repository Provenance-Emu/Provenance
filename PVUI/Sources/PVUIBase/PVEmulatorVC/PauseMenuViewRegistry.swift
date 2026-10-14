//
//  PauseMenuViewRegistry.swift
//  PVUIBase
//
//  Static registry allowing higher-level modules (PVSwiftUI) to inject
//  views into the pause menu without creating circular dependencies.
//

import SwiftUI
import GameController

/// Registry for views that are defined in modules above PVUIBase (e.g. PVSwiftUI)
/// but need to appear in the pause menu (which lives in PVUIBase).
///
/// Higher-level modules call the `register*` methods at app launch; PVUIBase
/// reads the stored view builders at presentation time.
@MainActor
public enum PauseMenuViewRegistry {
    /// Builder for the app-wide settings SwiftUI view.
    nonisolated(unsafe) private static var _appSettingsBuilder: (((() -> Void)?) -> AnyView)?

    /// Builder for the button remapping screen of one controller.
    nonisolated(unsafe) private static var _controllerRemapBuilder: ((GCController, (() -> Void)?) -> AnyView)?

    /// Register the app settings view builder.
    /// Call once at app launch from PVSwiftUI.
    public static func registerAppSettingsView(_ builder: @escaping (((() -> Void)?) -> AnyView)) {
        _appSettingsBuilder = builder
    }

    /// Returns the registered app settings view, or `nil` if none was registered.
    /// - Parameter dismissAction: Optional callback invoked by the embedded settings UI "Done" action.
    public static func appSettingsView(dismissAction: (() -> Void)? = nil) -> AnyView? {
        _appSettingsBuilder?(dismissAction)
    }

    /// Register the controller remapping view builder (pause menu "Remap Controller").
    /// Call once at app launch from PVSwiftUI.
    public static func registerControllerRemapView(_ builder: @escaping (GCController, (() -> Void)?) -> AnyView) {
        _controllerRemapBuilder = builder
    }

    /// Whether a controller remapping view was registered.
    public static var hasControllerRemapView: Bool {
        _controllerRemapBuilder != nil
    }

    /// Returns the registered remapping view for `controller`, or `nil` if none was registered.
    /// - Parameter dismissAction: Callback invoked by the view's "Done" action.
    public static func controllerRemapView(for controller: GCController,
                                           dismissAction: (() -> Void)? = nil) -> AnyView? {
        _controllerRemapBuilder?(controller, dismissAction)
    }
}
