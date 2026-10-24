import UIKit
import PVEmulatorCore
import PVLibrary
import PVLogging
import SkinKitCore

// MARK: - Screen Filter Extension

/// The skin's own screen filters on the single-screen picture. Dual-screen layouts carry
/// each screen's filters in their layout instead (`DualScreenRenderInfo.skinFilterInfos`).
extension PVEmulatorViewController {

    /// Runs `filters` in order over the game picture; an empty list removes them.
    public func applyScreenFilters(_ filters: [DeltaSkinScreenFilter]) {
        guard let metalVC = gpuViewController as? PVMetalViewController else {
            if !filters.isEmpty { ELOG("Cannot apply screen filters - no Metal view controller found") }
            return
        }
        // Clearing is called on every skin change; stay quiet when there is nothing to clear.
        if filters.isEmpty && metalVC.skinScreenFilters.isEmpty { return }
        ILOG(filters.isEmpty ? "Removing screen filters" : "Applying screen filters: \(filters.map(\.filter.name))")
        metalVC.skinScreenFilters = filters
        // Paused: show the change behind the pause menu.
        metalVC.redrawPausedFrame()
    }
}
