// PVEmulatorViewController+MetalDualScreen.swift
// PVUI
//
// Bridges the DeltaSkin layout system to the Metal dual-screen sub-rectangle
// renderer in PVMetalViewController.
//
// When a dual-screen game (e.g. Nintendo DS) is running with an active skin:
//   1. The skin describes where each screen should appear via DeltaSkinScreen.
//   2. This extension computes DualScreenRenderInfo values from those descriptions
//      and installs them on PVMetalViewController.
//   3. PVMetalViewController then splits the combined framebuffer (e.g. 256×384
//      for DS) into two independently-positioned viewports in a single pass.
//
// Called from applyDualScreenViewport() in PVEmulatorViewController+DualScreen.

import UIKit
import PVEmulatorCore
import PVLogging
import PVPrimitives

// MARK: - Metal Dual-Screen Layout

extension PVEmulatorViewController {

    // MARK: Public API

    /// Returns `true` when all conditions for Metal sub-rectangle dual-screen
    /// rendering are met:
    ///   • the GPU view controller is a `PVMetalViewController`
    ///   • the emulator core declares dual-screen support
    ///   • a DeltaSkin with screen-group data is active
    ///   • we are NOT running on tvOS (skins are disabled there)
    var canUseMetalDualScreenRendering: Bool {
        #if os(tvOS)
        return false
        #else
        guard gpuViewController is PVMetalViewController else { return false }
        // Only use the DS split-framebuffer path for Nintendo DS systems.
        // Other dual-screen cores (e.g. 3DS/emuThree) use their own layout logic.
        guard SystemIdentifier(rawValue: core.systemIdentifier ?? "") == .DS else { return false }
        guard isDeltaSkinEnabled, currentSkin != nil else { return false }
        return true
        #endif
    }

    /// Computes the Metal dual-screen layout from the current skin and installs it
    /// on the `PVMetalViewController`.  Also expands the Metal view to fill the
    /// parent view so Metal can position each screen freely.
    ///
    /// Call this instead of `applyFrameToGPUView` when `canUseMetalDualScreenRendering`
    /// is `true`.
    ///
    /// - Returns: `true` if the layout was successfully applied.
    @discardableResult
    func applyMetalDualScreenLayout() -> Bool {
        guard let metalVC = gpuViewController as? PVMetalViewController else { return false }
        guard isDeltaSkinEnabled, let skin = currentSkin else { return false }

        #if !os(tvOS)
        let skinDevice: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #else
        let skinDevice: DeltaSkinDevice = .tv
        #endif
        let orientation: DeltaSkinOrientation = (currentOrientation == .landscape) ? .landscape : .portrait
        let traits = DeltaSkinTraits(device: skinDevice,
                                     displayType: .standard,
                                     orientation: orientation,
                                     gameIdentifier: game?.title)

        // We need a skin with at least two screens in a screen group.
        guard let screenGroups = skin.screenGroups(for: traits),
              let group = screenGroups.first,
              group.screens.count >= 2 else {
            DLOG("dual-screen metal: skin has no screen groups with 2+ screens, falling back")
            metalVC.dualScreenLayout = nil
            return false
        }

        // Input-texture dimensions — used to normalise the skin's inputFrame.
        let bufferSize = core.bufferSize
        let texW = bufferSize.width > 0 ? bufferSize.width : 256
        let texH = bufferSize.height > 0 ? bufferSize.height : 384

        // View layout parameters (mirrors currentDualScreenViewportFrame()).
        let viewSize = view.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return false }

        guard let mappingSize = skin.mappingSize(for: traits),
              mappingSize.width > 0, mappingSize.height > 0 else { return false }

        // Scale factor: fit the skin's mapping size into the view.
        // Mirrors the calculation in currentDualScreenViewportFrame().
        let isPortraitPhone = skinDevice == .iphone && orientation == .portrait
        let scale: CGFloat
        if isPortraitPhone {
            let ws = viewSize.width  / mappingSize.width
            let hs = viewSize.height / mappingSize.height
            scale = ws * mappingSize.height <= viewSize.height ? ws : min(ws, hs)
        } else {
            scale = min(viewSize.width  / mappingSize.width,
                        viewSize.height / mappingSize.height)
        }

        let scaledW = mappingSize.width  * scale
        let scaledH = mappingSize.height * scale
        let xOff = (viewSize.width  - scaledW) / 2
        let yOff: CGFloat = isPortraitPhone ? viewSize.height - scaledH
                                            : (viewSize.height - scaledH) / 2

        // Sort screens top-to-bottom (then left-to-right) so landscape side-by-side
        // layouts (same minY for both screens) get a stable deterministic order.
        let sorted = group.screens.sorted { a, b in
            let ay = a.outputFrame?.minY ?? 0
            let by = b.outputFrame?.minY ?? 0
            if ay != by { return ay < by }
            return (a.outputFrame?.minX ?? 0) < (b.outputFrame?.minX ?? 0)
        }

        var renderInfos: [DualScreenRenderInfo] = []

        for (index, screen) in sorted.enumerated() {
            guard let outputFrame = screen.outputFrame else { continue }

            // --- Source UV ---
            // Use skin-specified inputFrame if available; otherwise default to
            // equal halves of the combined framebuffer (DS convention).
            let srcRect: CGRect
            if let inFrame = screen.inputFrame, inFrame.width > 0, inFrame.height > 0 {
                srcRect = CGRect(x: inFrame.minX / texW,
                                 y: inFrame.minY / texH,
                                 width: inFrame.width  / texW,
                                 height: inFrame.height / texH)
            } else {
                // Default: split the framebuffer based on DS native screen dimensions.
                // DS native: 256 px wide, 192 px per screen, 384 px combined height.
                // Some emulators (e.g. DeSmuME2015) report a large padded bufferSize
                // (2048×2048) where the valid DS content sits only in the top-left
                // 256×384 region.  Normalising by texW/texH ensures the UVs land on
                // the correct texels rather than always splitting the full 0–1 range.
                let dsNativeW: CGFloat = 256  // DS screen width in native pixels
                let dsNativeH: CGFloat = 192  // DS per-screen height in native pixels
                srcRect = CGRect(x: 0,
                                 y: CGFloat(index) * (dsNativeH / texH),
                                 width:  dsNativeW / texW,
                                 height: dsNativeH / texH)
            }

            // --- Destination (view-space points) ---
            // Mirror the calculation in currentDualScreenViewportFrame() exactly.
            let inLayout = CGRect(x: outputFrame.minX * scaledW,
                                  y: outputFrame.minY * scaledH,
                                  width:  outputFrame.width  * scaledW,
                                  height: outputFrame.height * scaledH)
            let destRect = CGRect(x: xOff + inLayout.midX - inLayout.width  / 2,
                                  y: yOff + inLayout.midY - inLayout.height / 2,
                                  width:  inLayout.width,
                                  height: inLayout.height)

            renderInfos.append(DualScreenRenderInfo(normalizedSourceRect: srcRect,
                                                    viewDestRect: destRect))
        }

        guard renderInfos.count >= 2 else {
            DLOG("dual-screen metal: could not compute 2+ render infos, falling back")
            metalVC.dualScreenLayout = nil
            return false
        }

        ILOG("dual-screen metal: installing layout with \(renderInfos.count) screens")
        metalVC.dualScreenLayout = renderInfos
        isMetalDualScreenActive = true

        // Expand the Metal view to fill the parent so both screen quads are visible.
        expandMetalViewToFillParent(metalVC)
        return true
    }

    /// Removes the Metal dual-screen layout (reverts to standard fullscreen blit).
    func clearMetalDualScreenLayout() {
        (gpuViewController as? PVMetalViewController)?.dualScreenLayout = nil
        isMetalDualScreenActive = false
    }

    // MARK: Helpers

    /// Expands the Metal view controller's view to fill `self.view` so the dual-screen
    /// quads can be positioned freely anywhere within the screen.
    private func expandMetalViewToFillParent(_ metalVC: PVMetalViewController) {
        let fullFrame = view.bounds

        (metalVC as PVGPUViewController).useCustomPositioning = true
        (metalVC as PVGPUViewController).customFrame = fullFrame

        metalVC.view.autoresizingMask = []
        metalVC.mtlView.autoresizingMask = []

        UIView.performWithoutAnimation {
            metalVC.view.frame  = fullFrame
            metalVC.mtlView.frame = metalVC.view.bounds
        }

        let drawScale = metalVC.renderSettings.nativeScaleEnabled
            ? (metalVC.view.window?.screen.scale ?? UIScreen.main.scale)
            : 1.0
        metalVC.mtlView.drawableSize     = CGSize(width:  fullFrame.width  * drawScale,
                                                  height: fullFrame.height * drawScale)
        metalVC.mtlView.contentScaleFactor = drawScale
        metalVC.view.isHidden    = false
        metalVC.mtlView.isHidden = false

        ensureGPUViewVisibilityAndZOrder()

        DLOG("dual-screen metal: expanded Metal view to full frame \(fullFrame)")
    }
}
