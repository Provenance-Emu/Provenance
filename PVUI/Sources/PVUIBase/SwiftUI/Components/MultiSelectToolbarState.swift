import SwiftUI

/// Shared observable that lets a deeply-nested view (ConsoleGamesView) surface
/// multi-select toolbar state to a high-level overlay (RetroMainView) that
/// renders above the tab bar.
@MainActor
public final class MultiSelectToolbarState: ObservableObject {
    public static let shared = MultiSelectToolbarState()

    @Published public var isActive: Bool = false
    @Published public var selectedCount: Int = 0

    /// Whether any selected games can be offloaded (downloaded + cloud record).
    @Published public var canOffload: Bool = false
    /// Whether any selected games can be downloaded (not downloaded + cloud record).
    @Published public var canDownload: Bool = false

    /// Callbacks wired by the owning ConsoleGamesView.
    public var onNormalizeTitles: (() -> Void)?
    public var onDelete: (() -> Void)?
    public var onMoveToSystem: (() -> Void)?
    public var onOffload: (() -> Void)?
    public var onDownload: (() -> Void)?
    public var onDone: (() -> Void)?

    private init() {}

    public func activate() {
        isActive = true
        selectedCount = 0
        canOffload = false
        canDownload = false
    }

    public func deactivate() {
        isActive = false
        selectedCount = 0
        canOffload = false
        canDownload = false
        onNormalizeTitles = nil
        onDelete = nil
        onMoveToSystem = nil
        onOffload = nil
        onDownload = nil
        onDone = nil
    }

    public func updateCount(_ count: Int) {
        selectedCount = count
    }
}
