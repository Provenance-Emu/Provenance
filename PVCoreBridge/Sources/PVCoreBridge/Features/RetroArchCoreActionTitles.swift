import Foundation

/// Stable ``CoreAction`` titles exposed by RetroArch / libretro cores for UI routing.
///
/// Keep these aligned with ``PVRetroArchCoreCore``'s ``CoreActions`` implementation.
public enum RetroArchCoreActionTitles {
    /// Toggles the in-core RetroArch menu (RGUI/XMB) via ``menuToggle()``.
    public static let internalMenu = "RetroArch Menu"
}
