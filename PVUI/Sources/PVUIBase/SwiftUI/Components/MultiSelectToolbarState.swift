import SwiftUI

/// Shared observable that lets a deeply-nested view (ConsoleGamesView) surface
/// multi-select toolbar state to a high-level overlay (RetroMainView) that
/// renders above the tab bar.
@MainActor
public final class MultiSelectToolbarState: ObservableObject {
    public static let shared = MultiSelectToolbarState()

    @Published public var isActive: Bool = false
    @Published public var selectedCount: Int = 0

    /// Callbacks wired by the owning ConsoleGamesView.
    public var onNormalizeTitles: (() -> Void)?
    public var onDone: (() -> Void)?

    private init() {}

    public func activate() {
        isActive = true
        selectedCount = 0
    }

    public func deactivate() {
        isActive = false
        selectedCount = 0
        onNormalizeTitles = nil
        onDone = nil
    }

    public func updateCount(_ count: Int) {
        selectedCount = count
    }
}
