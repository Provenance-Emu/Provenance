//
//  PVEmulatorViewController+FirstFrameWatchdog.swift
//  PVUI
//

import Foundation
import PVEmulatorCore
import PVLogging

extension PVEmulatorViewController {

    /// How long a booted core gets to put a frame on screen before the miss is logged.
    private static let firstFrameWatchdogDelay: TimeInterval = 5

    /// Logs the render pipeline's state when a core has booted but nothing has
    /// been presented.
    ///
    /// "The game starts and the screen stays black" reaches us with no way to
    /// tell which stage failed: the core never produced a frame, it rendered
    /// somewhere the presenter doesn't read, the presenter skipped its draw, or
    /// the view is hidden, zero-sized or covered. A successful boot and a black
    /// one look identical in the log up to this point, so this records the one
    /// line that separates those cases, per core, on the device it happened on.
    ///
    /// Cores that draw into their own view (Dolphin, PPSSPP's native core,
    /// RetroArch `skipLayout`) never present through the shared presenter and
    /// are expected to trip this; the line says so rather than guessing.
    @MainActor
    func scheduleFirstFrameWatchdog() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.firstFrameWatchdogDelay) { [weak self] in
            guard let self, self.core.isOn, self.gpuViewController.isViewLoaded else { return }
            guard !self.gpuViewController.hasPresentedFirstFrame else { return }

            let core = self.core
            let gpuView = self.gpuViewController.view
            let siblings = gpuView?.superview?.subviews ?? []
            let zIndex = gpuView.flatMap { siblings.firstIndex(of: $0) } ?? -1
            WLOG("""
                 [NO-FRAME] Nothing presented \(Int(Self.firstFrameWatchdogDelay))s after boot \
                 (expected only for cores that draw to their own view). \
                 core=\(core.coreIdentifier ?? "?") system=\(core.systemIdentifier ?? "?") \
                 presenter=\(type(of: self.gpuViewController)) \
                 gl=\(core.rendersToOpenGL) vulkan=\(core.rendersToVulkan) skipLayout=\(core.skipLayout) \
                 running=\(core.isRunning) skipLoop=\(core.skipEmulationLoop) \
                 menu=\(self.isShowingMenu) skin=\(self.currentSkin != nil) \
                 buffer=\(core.bufferSize) screenRect=\(core.screenRect) \
                 view.frame=\(gpuView?.frame ?? .zero) hidden=\(gpuView?.isHidden ?? true) alpha=\(gpuView?.alpha ?? 0) \
                 inWindow=\(gpuView?.window != nil) z=\(zIndex)/\(siblings.count)
                 """)
        }
    }
}
