import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVLogging
import PVCoreBridge
import PVSettings
import PVUIBase
import ObjectiveC

extension PVEmulatorViewController: PVViewportLayoutDelegate {

    // MARK: - Setup

    /// Update GPU view position based on DeltaSkin screen information
    func updateGPUViewPositionForDeltaSkin() {
        guard gpuViewController.view != nil else { return }

        // Set self as delegate to receive viewport updates via protocol
        core.viewportLayoutDelegate = self

        // Keep notification observers for backward compatibility during migration
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFrameUpdated), name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeltaSkinLoaded"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSkinLoaded), name: NSNotification.Name("DeltaSkinLoaded"), object: nil)

        setupDualScreenObservers()

        if isDeltaSkinEnabled, currentSkin != nil {
            applyViewportFromCurrentSkin()
        } else {
            resetGPUViewPosition()
        }
    }

    // MARK: - PVViewportLayoutDelegate

    /// Receive viewport frame updates via protocol (replaces notification system)
    @objc public func viewportFrameDidUpdate(_ frame: CGRect) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.viewportFrameDidUpdate(frame)
            }
            return
        }

        // Validate and apply frame using existing validation logic
        guard validateAndStoreFrame(frame) else { return }
        applyFrameToGPUView(frame, reason: "delegate-frameDidUpdate")
    }

    /// Check if skin supports current device
    private func skinSupportsCurrentDevice(_ skin: DeltaSkinProtocol) -> Bool {
        #if os(tvOS)
        let device: DeltaSkinDevice = .tv
        #else
        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        let orientations: [SkinOrientation] = [.portrait, .landscape]

        // Check if skin supports at least one orientation for the current device
        for orientation in orientations {
            for display in displayTypes {
                let traits = DeltaSkinTraits(
                    device: device,
                    displayType: display,
                    orientation: orientation.deltaSkinOrientation
                )
                if skin.supports(traits) { return true }
            }
        }
        return false
    }

    /// Handle skin loaded notification
    @objc private func handleSkinLoaded(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.handleSkinLoaded(notification) }
            return
        }

        guard let skinId = notification.userInfo?["skinId"] as? String else { return }

        if currentSkin == nil || currentSkin?.identifier != skinId {
            let manager = DeltaSkinManager.shared
            if manager.skinsAreLoaded, let skin = manager.loadedSkins.first(where: { $0.identifier == skinId }) {
                // Verify skin supports current device before setting it
                if skinSupportsCurrentDevice(skin) {
                    currentSkin = skin
                    DLOG("🎮 SKIN: Set currentSkin from notification: \(skin.name)")
                    applyViewportFromCurrentSkin()
                    applyScreenFiltersFromCurrentSkin()
                } else {
                    DLOG("🎮 SKIN: Skin \(skin.name) from notification doesn't support current device, skipping")
                }
            }
        }
    }

    // MARK: - Frame Handling (Simplified)

    /// Handle frame update notification - single entry point for all frames
    @objc private func handleFrameUpdated(_ notification: Notification) {
        guard Thread.isMainThread else {
            // Use async (not sync) to avoid deadlocking the calling thread if the
            // main queue is busy — frame updates are not latency-critical.
            DispatchQueue.main.async { [weak self] in self?.handleFrameUpdated(notification) }
            return
        }

        guard let frameValue = notification.userInfo?["frame"] as? NSValue else {
            ELOG("🎮 SKIN: No frame in notification")
            return
        }

        let frame = frameValue.cgRectValue

        // Validate and store frame
        guard validateAndStoreFrame(frame) else { return }

        // Apply frame immediately
        applyFrameToGPUView(frame, reason: "notif-frame")
    }

    /// Validate frame and store if valid - returns true if frame should be applied
    private func validateAndStoreFrame(_ frame: CGRect) -> Bool {
        // Basic validation
        guard frame.width > 0 && frame.height > 0,
              frame.width < 10000 && frame.height < 10000,
              frame.width.isFinite && frame.height.isFinite else {
            ELOG("🎮 SKIN: Invalid frame: \(frame)")
            return false
        }

        // Reject tiny frames (button areas)
        guard frame.width >= 100 && frame.height >= 100 else {
            ELOG("🎮 SKIN: Frame too small (button area?): \(frame)")
            // Use initial frame if available
            if let initial = initialCorrectFrame {
                ILOG("🎮 SKIN: Using initial correct frame instead")
                applyFrameToGPUView(initial, reason: "validate-too-small-fallback")
            }
            return false
        }

        // Store initial correct frame (first valid frame)
        if initialCorrectFrame == nil {
            initialCorrectFrame = frame
            ILOG("🎮 SKIN: Stored initial correct frame: \(frame)")
        }

        // Every caller of this method is a broadcast from the SwiftUI skin renderer
        // (protocol delegate or the legacy notification), so the frame we're about to
        // store is authoritative — see `skinRendererProvidedViewportFrame`.
        skinRendererProvidedViewportFrame = true

        // Skip if unchanged - but always store after rotation to ensure frame is available
        // Check if we're in the middle of a rotation (currentTargetFrame was recently cleared)
        let isAfterRotation = currentTargetFrame == nil

        if let current = currentTargetFrame,
           !isAfterRotation,
           abs(current.origin.x - frame.origin.x) < 0.5 &&
           abs(current.origin.y - frame.origin.y) < 0.5 &&
           abs(current.width - frame.width) < 0.5 &&
           abs(current.height - frame.height) < 0.5 {
            return false
        }

        currentTargetFrame = frame
        return true
    }

    // MARK: - Viewport Application (Simplified)

    /// Returns true when the bridge has started shutdown and viewport updates should be ignored.
    private func isBridgeShuttingDownForViewport(_ viewport: EmulatorCoreViewportPositioning? = nil) -> Bool {
        let target = viewport ?? (core.bridge as? EmulatorCoreViewportPositioning)
        return target?.isShuttingDownForViewportUpdates?() ?? false
    }

    /// Apply viewport from current skin - single, simple entry point
    internal func applyViewportFromCurrentSkin() {
        guard Thread.isMainThread else {
            // Use async (not sync) to avoid deadlocking the calling thread if the
            // main queue is busy — viewport updates are not latency-critical.
            DispatchQueue.main.async { [weak self] in self?.applyViewportFromCurrentSkin() }
            return
        }

        guard !isBridgeShuttingDownForViewport() else { return }
        guard !isApplyingViewport else { return }
        guard view.bounds.width > 0 && view.bounds.height > 0 else { return }

        isApplyingViewport = true
        defer { isApplyingViewport = false }

        if core.supportsDualScreens {
            applyDualScreenViewport()
            return
        }

        // For default skins, use notification frame if already received
        // Only wait for fresh notification if we don't have a valid frame yet
        if isDefaultSkin {
            // If we already have a valid frame from notification, use it immediately
            if let frame = currentTargetFrame, isValidFrame(frame) {
                // Check if frame is already correctly applied to avoid unnecessary work
                if let gameScreenView = gpuViewController.view,
                   abs(gameScreenView.frame.origin.x - frame.origin.x) < 0.5 &&
                   abs(gameScreenView.frame.origin.y - frame.origin.y) < 0.5 &&
                   abs(gameScreenView.frame.width - frame.width) < 0.5 &&
                   abs(gameScreenView.frame.height - frame.height) < 0.5 {
                    // Frame already correctly applied, no need to re-apply
                    return
                }
                applyFrameToGPUView(frame, reason: "viewport-default-immediate")
                return
            }

            // No valid frame yet - wait for notification with fresh frame calculation
            // This handles cases like rotation where we need a fresh calculation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                guard !self.isBridgeShuttingDownForViewport() else { return }
                if let frame = self.currentTargetFrame, self.isValidFrame(frame) {
                    self.applyFrameToGPUView(frame, reason: "viewport-default-async0.15")
                } else {
                    // Only reset if we truly don't have a frame (e.g., during initial boot)
                    // Don't reset if frame was already applied successfully
                    if let gameScreenView = self.gpuViewController.view,
                       gameScreenView.frame == self.view.bounds {
                        // Only reset if currently at full screen (not already positioned)
                        self.resetGPUViewPosition()
                    }
                }
            }
            return
        }

        // For non-default skins, use notification frame if available (preferred - most accurate)
        if let frame = currentTargetFrame, isValidFrame(frame) {
            applyFrameToGPUView(frame, reason: "viewport-nondefault-cached")
            return
        }

        // Check if skin has defined screen areas (screens, screenGroups, or gameScreenFrame)
        // For these skins, wait for protocol delegate callback instead of using fallback calculation
        if skinDeclaresScreenArea {
            // Wait for protocol delegate callback - don't use fallback calculation
            // The protocol delegate (viewportFrameDidUpdate) will be called shortly after rotation
            // But also try immediate calculation as fallback for initial load
            if let immediateFrame = calculateFrameFromSkin(), isValidFrame(immediateFrame) {
                currentTargetFrame = immediateFrame
                skinRendererProvidedViewportFrame = false
                applyFrameToGPUView(immediateFrame, reason: "viewport-defined-immediate")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                guard !self.isBridgeShuttingDownForViewport() else { return }
                if let frame = self.currentTargetFrame, self.isValidFrame(frame) {
                    // A frame broadcast by the skin renderer is authoritative — it was
                    // derived from the very `SkinLayout` that positioned the skin image,
                    // so it is the only rect guaranteed to land in the skin's cutout.
                    // Re-deriving it here would replace it with this controller's
                    // independent approximation and push the render view off the cutout.
                    if self.skinRendererProvidedViewportFrame {
                        self.applyFrameToGPUView(frame, reason: "viewport-defined-async0.3-renderer")
                        return
                    }
                    // Verify frame is still correct, recalculate if needed
                    if let recalculatedFrame = self.calculateFrameFromSkin(), self.isValidFrame(recalculatedFrame) {
                        // Only update if significantly different (more than 10 pixels)
                        if abs(frame.origin.x - recalculatedFrame.origin.x) > 10 ||
                           abs(frame.origin.y - recalculatedFrame.origin.y) > 10 ||
                           abs(frame.width - recalculatedFrame.width) > 10 ||
                           abs(frame.height - recalculatedFrame.height) > 10 {
                            self.currentTargetFrame = recalculatedFrame
                            self.applyFrameToGPUView(recalculatedFrame, reason: "viewport-defined-async0.3-recalc")
                        }
                    } else {
                        self.applyFrameToGPUView(frame, reason: "viewport-defined-async0.3-existing")
                    }
                } else {
                    // If still no frame after waiting, use fallback
                    if let frame = self.calculateFrameFromSkin(), self.isValidFrame(frame) {
                        self.currentTargetFrame = frame
                        self.applyFrameToGPUView(frame, reason: "viewport-defined-async0.3-fallback")
                    } else {
                        self.resetGPUViewPosition()
                    }
                }
            }
            return
        }

        // For simple skins without defined screen areas, calculate frame immediately
        if let frame = calculateFrameFromSkin(), isValidFrame(frame) {
            currentTargetFrame = frame
            applyFrameToGPUView(frame, reason: "viewport-simple-immediate")
        } else {
            // If calculation fails, try again after a short delay (for initial load timing issues)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                guard !self.isBridgeShuttingDownForViewport() else { return }
                if let frame = self.calculateFrameFromSkin(), self.isValidFrame(frame) {
                    self.currentTargetFrame = frame
                    self.applyFrameToGPUView(frame, reason: "viewport-simple-async0.1")
                } else {
                    self.resetGPUViewPosition()
                }
            }
        }
    }

    /// Recompute the skin viewport when the view's bounds / safe-area insets have
    /// actually changed since the viewport was last computed.
    ///
    /// Fixes the "emulator render is stuck full-screen (ignoring the skin cutout) or
    /// wrong-sized until I rotate" bug: the viewport is otherwise computed once during
    /// racy fixed-delay async setup passes — from `view.bounds` / `view.safeAreaInsets`
    /// that may not be settled yet — and is only invalidated/recomputed by a rotation
    /// (`minimalRelayout`). This recomputes deterministically once the layout settles.
    ///
    /// Which recompute runs depends on who owns the layout for the active skin:
    /// - Skin declares a screen area → ask the SwiftUI renderer to recompute and
    ///   re-broadcast (`requestSkinRendererViewportRecalculation`). It is the only code
    ///   that knows where the skin image landed.
    /// - No declared screen area → `calculateFrameFromSkin()` (reads the *current*
    ///   bounds/safe-area) as before.
    ///
    /// Safe for the hot `viewDidLayoutSubviews` path:
    /// - Gated on an ACTUAL bounds/safe-area change, so repeated passes with identical
    ///   geometry early-return (applying the GPU *subview* frame does not change the
    ///   parent's bounds/safe-area, so this can't loop).
    /// - Skipped entirely while a rotation is in flight (`isHandlingRotation`) so the
    ///   rotation path keeps sole ownership of layout during the transition.
    /// - Records geometry only after a valid frame is produced, so it keeps retrying
    ///   on later passes if the skin isn't loaded yet.
    internal func recomputeSkinViewportIfLayoutChanged() {
        guard Thread.isMainThread else { return }
        guard isDeltaSkinEnabled, currentSkin != nil else { return }
        guard !isHandlingRotation else { return }
        guard !isApplyingViewport else { return }
        guard !isBridgeShuttingDownForViewport() else { return }
        guard !core.supportsDualScreens else { return } // dual-screen has its own path

        let bounds = view.bounds
        let safeArea = view.safeAreaInsets
        guard bounds.width > 0 && bounds.height > 0 else { return }

        // No geometry change since the last successful compute → nothing to do.
        if bounds == lastViewportLayoutBounds && safeArea == lastViewportLayoutSafeArea {
            return
        }

        // Skins that declare their own screen area are positioned by the SwiftUI renderer,
        // which is the only code that knows where the skin image was actually drawn. Ask it
        // to recompute against the settled geometry and re-broadcast, rather than applying
        // `calculateFrameFromSkin()` — that approximation resolves the skin representation
        // and the vertical anchor independently of the renderer, so making it the last
        // writer is what leaves the render view mis-sized/off the skin's cutout.
        if !isDefaultSkin, skinDeclaresScreenArea {
            lastViewportLayoutBounds = bounds
            lastViewportLayoutSafeArea = safeArea
            requestSkinRendererViewportRecalculation(reason: "layout-settle")
            return
        }

        // Compute the correct frame from the now-settled bounds/safe-area. If the skin
        // isn't ready yet the calculation returns nil/invalid — leave the existing
        // async/notification path to handle it and retry on a later layout pass.
        guard let freshFrame = calculateFrameFromSkin(), isValidFrame(freshFrame) else { return }

        // We have a valid frame for this geometry — record it so identical passes no-op.
        lastViewportLayoutBounds = bounds
        lastViewportLayoutSafeArea = safeArea

        // Only act if the applied frame is actually stale (full-screen spill or wrong
        // size). applyFrameToGPUView has its own 0.5px guard too, but short-circuit here.
        if let gpuView = gpuViewController.view,
           abs(gpuView.frame.origin.x - freshFrame.origin.x) < 1.0,
           abs(gpuView.frame.origin.y - freshFrame.origin.y) < 1.0,
           abs(gpuView.frame.width  - freshFrame.width)  < 1.0,
           abs(gpuView.frame.height - freshFrame.height) < 1.0 {
            return
        }

        currentTargetFrame = freshFrame
        lastAppliedViewportFrame = nil
        applyFrameToGPUView(freshFrame, reason: "recompute-layout-settle")
    }

    /// How long to wait for the skin renderer to answer a
    /// `deltaSkinForceRecalculate` request before falling back to a locally
    /// computed frame. Matches the post-rotation wait in `minimalRelayout()`,
    /// which uses the same notification → broadcast → delegate round-trip.
    private static let skinRendererRecalculationTimeout: TimeInterval = 0.35

    /// `true` when the active skin declares where the game screen goes (a `screens`
    /// array, a screen group, or a `gameScreenFrame`). Those skins are laid out by the
    /// SwiftUI renderer; skins without a declared area fall back to this controller's
    /// own calculation.
    ///
    /// Uses the same traits the renderer draws with, so both sides agree on *which*
    /// representation of the skin is being asked about.
    private var skinDeclaresScreenArea: Bool {
        guard let skin = currentSkin else { return false }
        let traits = skinRenderTraits()
        return skin.screens(for: traits) != nil ||
               skin.screenGroups(for: traits) != nil ||
               hasGameScreenFrame(skin, traits: traits)
    }

    /// Ask the SwiftUI skin renderer to recompute the game-screen rect against the
    /// current geometry and re-broadcast it through `viewportFrameDidUpdate`.
    ///
    /// A safety net re-applies the last known good frame (or, failing that, the local
    /// approximation) if no broadcast arrives — the renderer can be mid-load, or its
    /// hosting view may not have been laid out yet. `applyFrameToGPUView` no-ops when
    /// the frame is already applied, so the safety net is free in the common case.
    private func requestSkinRendererViewportRecalculation(reason: String) {
        NotificationCenter.default.post(name: .deltaSkinForceRecalculate, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.skinRendererRecalculationTimeout) { [weak self] in
            guard let self = self else { return }
            guard self.isDeltaSkinEnabled, self.currentSkin != nil else { return }
            guard !self.isBridgeShuttingDownForViewport() else { return }
            guard !self.isHandlingRotation else { return }

            if let frame = self.currentTargetFrame, self.isValidFrame(frame) {
                self.applyFrameToGPUView(frame, reason: "renderer-recalc-\(reason)")
                return
            }

            if let frame = self.calculateFrameFromSkin(), self.isValidFrame(frame) {
                self.currentTargetFrame = frame
                self.skinRendererProvidedViewportFrame = false
                self.applyFrameToGPUView(frame, reason: "renderer-recalc-fallback-\(reason)")
                return
            }

            // Nothing produced a frame — the skin probably hasn't finished loading. Drop the
            // recorded geometry so the next layout pass tries again instead of no-op'ing.
            self.lastViewportLayoutBounds = .null
        }
    }

    /// The traits the SwiftUI skin renderer is drawing the active skin with.
    ///
    /// Must stay in step with `EmulatorWithSkinView.createSkinTraits()`: a skin can ship
    /// different `mappingSize`/`screens` for its `standard` and `edgeToEdge`
    /// representations (and per-game overrides keyed off `gameIdentifier`), so resolving
    /// a *different* representation here yields a game-screen rect that belongs to a
    /// skin body that was never drawn — wrong position and wrong size.
    ///
    /// Orientation is derived from the settled view bounds rather than
    /// `UIDevice.current.orientation` so it can't report a transient/face-up value.
    private func skinRenderTraits() -> DeltaSkinTraits {
        #if os(tvOS)
        let device: DeltaSkinDevice = .tv
        #else
        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
        let orientation: DeltaSkinOrientation = view.bounds.width > view.bounds.height ? .landscape : .portrait
        // A non-zero bottom safe-area inset means a home-indicator device, which is what
        // the renderer keys `edgeToEdge` off. Prefer the window's inset (what the renderer
        // reads) and fall back to our own for detached/preview hierarchies.
        let bottomInset = view.window?.safeAreaInsets.bottom ?? view.safeAreaInsets.bottom
        let displayType: DeltaSkinDisplayType = bottomInset > 0 ? .edgeToEdge : .standard
        return DeltaSkinTraits(device: device,
                               displayType: displayType,
                               orientation: orientation,
                               gameIdentifier: game?.title)
    }

    /// Check if current skin is a default skin
    private var isDefaultSkin: Bool {
        guard let skin = currentSkin else { return true }
        return skin.identifier.hasPrefix("default-") ||
               skin.identifier == "default" ||
               skin.name.lowercased().contains("default")
    }

    /// Simple frame validation
    private func isValidFrame(_ frame: CGRect) -> Bool {
        return frame.width > 0 && frame.height > 0 &&
               frame.width < 10000 && frame.height < 10000 &&
               frame.width.isFinite && frame.height.isFinite &&
               frame.origin.x.isFinite && frame.origin.y.isFinite &&
               frame.width >= 100 && frame.height >= 100
    }

    // MARK: - Frame Calculation (Simplified)

    /// Calculate frame from skin - public for compatibility
    internal func currentSkinViewportFrame() -> CGRect? {
        return calculateFrameFromSkin()
    }

    /// Calculate frame from skin - single, clear calculation path
    /// Uses same calculation for bootup and rotation - accounts for safe areas
    private func calculateFrameFromSkin() -> CGRect? {
        guard let skin = currentSkin else { return nil }
        guard view.bounds.width > 0 && view.bounds.height > 0 else { return nil }

        // Resolve the SAME representation the renderer is drawing. The previous
        // `[.standard, .edgeToEdge]` probe could never pick `.edgeToEdge`:
        // `DeltaSkin.resolveOrientationReps` already falls back `.standard` → `.edgeToEdge`,
        // so `mappingSize(for: .standard)` is non-nil whenever the skin has *any*
        // representation and the loop always stopped on the first iteration. For a skin
        // shipping both representations that silently laid the game screen out against the
        // standard body while the renderer drew the edge-to-edge one.
        let traits = skinRenderTraits()
        guard let mappingSize = skin.mappingSize(for: traits) else {
            DLOG("🎮 SKIN: No mapping size found for device \(traits.device.rawValue), orientation \(traits.orientation.rawValue)")
            return nil
        }

        // Calculate layout accounting for safe areas
        let safeInsets = view.safeAreaInsets
        let viewSize = view.bounds.size
        let safeWidth = max(0, viewSize.width - safeInsets.left - safeInsets.right)
        let safeHeight = max(0, viewSize.height - safeInsets.top - safeInsets.bottom)
        let safeSize = CGSize(width: safeWidth, height: safeHeight)

        // Calculate scale using safe area dimensions - consistent for all orientations
        let scale = calculateScale(viewSize: safeSize, mappingSize: mappingSize)
        let scaledSize = CGSize(width: mappingSize.width * scale, height: mappingSize.height * scale)

        // Calculate offset accounting for safe areas
        let offset = calculateOffset(for: traits,
                                    viewSize: viewSize,
                                    safeInsets: safeInsets,
                                    scaledSize: scaledSize)

        // Get screen frame from skin
        let screenFrame = getScreenFrame(from: skin, traits: traits, mappingSize: mappingSize)

        // Diagnostic for on-device skin-layout triage: one line per calculation with all
        // the intermediates, so a Console.app capture shows exactly which rect this
        // fallback produced and from which representation. Uses ILOG (not DLOG) so it
        // survives in release logs — see the flycast debugging note in CLAUDE.md.
        let calcInputs = "orient=\(traits.orientation.rawValue) display=\(traits.displayType.rawValue) mapping=\(mappingSize) bounds=\(view.bounds.size) safeInsets=\(safeInsets)"
        let calcOutputs = "safeSize=\(safeSize) scale=\(scale) scaledSize=\(scaledSize) offset=\(offset) screenFrame(norm)=\(screenFrame.map { "\($0)" } ?? "nil")"
        ILOG("SKIN-CALC-DIAG: \(calcInputs) | \(calcOutputs)")

        if let screenFrame {
            // The screen rect is normalised (0-1) against `mappingSize`, i.e. it is a
            // position *inside the skin image*. It must therefore be anchored to where
            // the skin image was actually drawn, not to the centred fallback rect.
            let skinOrigin = skinImageOrigin(for: traits,
                                             viewSize: viewSize,
                                             safeInsets: safeInsets,
                                             scaledSize: scaledSize)
            return CGRect(
                x: skinOrigin.x + screenFrame.minX * scaledSize.width,
                y: skinOrigin.y + screenFrame.minY * scaledSize.height,
                width: screenFrame.width * scaledSize.width,
                height: screenFrame.height * scaledSize.height
            )
        }

        // Default: center in available space
        return CGRect(x: offset.x, y: offset.y, width: scaledSize.width, height: scaledSize.height)
    }

    /// Calculate scale for skin layout
    /// Uses same calculation for bootup and rotation - consistent for all orientations
    /// Scales to fit within available space while maintaining aspect ratio
    private func calculateScale(viewSize: CGSize, mappingSize: CGSize) -> CGFloat {
        // Always use the same calculation: scale to fit within available space
        // This ensures consistent sizing regardless of orientation or device type
        guard mappingSize.width > 0 && mappingSize.height > 0 else { return 1.0 }
        let scaleX = viewSize.width / mappingSize.width
        let scaleY = viewSize.height / mappingSize.height
        return min(scaleX, scaleY)
    }

    /// Calculate offset for skin layout
    /// Accounts for safe areas - uses same calculation for bootup and rotation
    /// Centers the skin in the safe area for all orientations
    private func calculateOffset(for traits: DeltaSkinTraits, viewSize: CGSize, safeInsets: UIEdgeInsets, scaledSize: CGSize) -> CGPoint {
        let safeWidth = max(0, viewSize.width - safeInsets.left - safeInsets.right)
        let safeHeight = max(0, viewSize.height - safeInsets.top - safeInsets.bottom)

        // Center horizontally accounting for safe areas
        let x = safeInsets.left + (safeWidth - scaledSize.width) / 2

        // Center vertically in safe area for all orientations
        // Screen frame position within skin will be handled by screenFrame.minY
        let y = safeInsets.top + (safeHeight - scaledSize.height) / 2

        return CGPoint(x: x, y: y)
    }

    /// The top-left corner, in view coordinates, of where the skin image is drawn.
    ///
    /// Mirrors `DeltaSkinView.calculateLayout(for:)` — the renderer centres the skin
    /// horizontally in the safe area but, on **iPhone portrait**, anchors it to the
    /// bottom of the screen (just above the home indicator) instead of centring it
    /// vertically. Anchoring a skin-relative screen rect to the centred rect instead
    /// puts the render view at a different height than the cutout it is supposed to
    /// fill, which is exactly the "screen sits off the skin's screen area, clipped by
    /// the skin body" symptom in portrait.
    private func skinImageOrigin(for traits: DeltaSkinTraits,
                                 viewSize: CGSize,
                                 safeInsets: UIEdgeInsets,
                                 scaledSize: CGSize) -> CGPoint {
        let safeWidth = max(0, viewSize.width - safeInsets.left - safeInsets.right)
        let safeHeight = max(0, viewSize.height - safeInsets.top - safeInsets.bottom)

        let x = safeInsets.left + (safeWidth - scaledSize.width) / 2

        let y: CGFloat
        if traits.device == .iphone && traits.orientation == .portrait {
            y = viewSize.height - scaledSize.height - safeInsets.bottom
        } else {
            y = safeInsets.top + (safeHeight - scaledSize.height) / 2
        }

        return CGPoint(x: x, y: y)
    }

    /// Check if skin has gameScreenFrame defined in JSON
    private func hasGameScreenFrame(_ skin: DeltaSkinProtocol?, traits: DeltaSkinTraits) -> Bool {
        guard let skin = skin else { return false }
        guard let representations = skin.jsonRepresentation["representations"] as? [String: Any],
              let deviceRep = representations[traits.device.rawValue] as? [String: Any],
              let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
              let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
              let frameDict = orientationRep["gameScreenFrame"] as? [String: Any] else {
            return false
        }
        return frameDict["x"] != nil && frameDict["y"] != nil &&
               frameDict["width"] != nil && frameDict["height"] != nil
    }

    /// Get normalized screen frame from skin (0-1 coordinates)
    private func getScreenFrame(from skin: any DeltaSkinProtocol, traits: DeltaSkinTraits, mappingSize: CGSize) -> CGRect? {
        // Try screens array - select the smallest screen (the actual game screen)
        // Larger screens are typically effect screens (blurred backgrounds), smaller screens are the game screen
        if let screens = skin.screens(for: traits), !screens.isEmpty {
            // Filter out screens that are too small (likely buttons or UI elements)
            let validScreens = screens.compactMap { screen -> (screen: DeltaSkinScreen, frame: CGRect, area: CGFloat)? in
                guard let frame = screen.outputFrame else { return nil }
                let area = frame.width * frame.height
                // Minimum reasonable screen size: at least 100x100 pixels or normalized equivalent
                let minSize: CGFloat = 100.0
                let isAbsolutePixels = frame.width > mappingSize.width || frame.height > mappingSize.height ||
                                       (frame.width > 1.0 && frame.height > 1.0 &&
                                        frame.width < mappingSize.width && frame.height < mappingSize.height)
                let actualMinSize = isAbsolutePixels ? minSize : (minSize / max(mappingSize.width, mappingSize.height))

                if frame.width >= actualMinSize && frame.height >= actualMinSize {
                    return (screen, frame, area)
                }
                return nil
            }

            if let smallestScreen = validScreens.min(by: { $0.area < $1.area }),
               let outputFrame = smallestScreen.screen.outputFrame {
                return normalizeFrame(outputFrame, mappingSize: mappingSize)
            }
        }

        // Try screen groups
        if let groups = skin.screenGroups(for: traits),
           let group = groups.first,
           let screen = group.screens.first,
           let outputFrame = screen.outputFrame {
            return normalizeFrame(outputFrame, mappingSize: mappingSize)
        }

        // Try gameScreenFrame dictionary
        if let representations = skin.jsonRepresentation["representations"] as? [String: Any],
           let deviceRep = representations[traits.device.rawValue] as? [String: Any],
           let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
           let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
           let frameDict = orientationRep["gameScreenFrame"] as? [String: Any],
           let x = frameDict["x"] as? CGFloat,
           let y = frameDict["y"] as? CGFloat,
           let width = frameDict["width"] as? CGFloat,
           let height = frameDict["height"] as? CGFloat {
            return normalizeFrame(CGRect(x: x, y: y, width: width, height: height), mappingSize: mappingSize)
        }

        return nil
    }

    /// Normalize frame to 0-1 coordinates using mappingSize.
    /// Returns the frame unchanged when no component exceeds 1.0 (i.e. it is already
    /// treated as being in normalized space). This heuristic only checks for values
    /// greater than 1.0; small or negative values alone do not trigger normalization.
    private func normalizeFrame(_ frame: CGRect, mappingSize: CGSize) -> CGRect {
        // Already normalised — no component exceeds 1.0
        guard frame.origin.x > 1.0 || frame.origin.y > 1.0 ||
              frame.size.width > 1.0 || frame.size.height > 1.0 else {
            return frame
        }
        guard mappingSize.width > 0 && mappingSize.height > 0 else { return frame }
        return CGRect(
            x: frame.minX / mappingSize.width,
            y: frame.minY / mappingSize.height,
            width: frame.width / mappingSize.width,
            height: frame.height / mappingSize.height
        )
    }

    // MARK: - Scaling Mode Within Skin Container

    /// Adjusts a skin-provided container rect based on the current scaling mode
    /// and game aspect ratio. When skins are active, the skin defines the screen
    /// area but the user's chosen scaling mode controls how the game content
    /// fits within that area.
    ///
    /// - Parameter container: The skin's screen rect (in view coordinates).
    /// - Returns: The adjusted frame for the GPU view within the container.
    internal func adjustFrameForScalingMode(_ container: CGRect) -> CGRect {
        // Only apply scaling mode adjustments when the user has explicitly
        // chosen a mode. Otherwise, preserve the skin's original behavior
        // (stretch-to-fill the screen area) to avoid surprising existing users.
        guard Defaults[.userExplicitlySetScalingMode] else { return container }

        let scalingMode = Defaults[.scalingMode]

        // Stretch: use the container as-is (game fills entire skin screen area)
        guard scalingMode != .stretch else { return container }

        // Compute game aspect ratio from the core
        let screenRect = core.screenRect
        let bufferSize = core.bufferSize
        let isScreenRectValid = screenRect.width > 10 && screenRect.height > 10
        let effectiveRect = isScreenRectValid
            ? screenRect
            : CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)

        guard !effectiveRect.isEmpty else { return container }

        let safeWidth = max(effectiveRect.width, 1)
        let safeHeight = max(effectiveRect.height, 1)
        var ratio = safeWidth / safeHeight

        // Prefer the core-reported display aspect when available
        let aspectSize = core.aspectSize
        if aspectSize.width > 0 && aspectSize.height > 0 {
            var aspectRatio = aspectSize.width / max(0.01, aspectSize.height)
            if aspectRatio < 0.5 || aspectRatio > 3.0 {
                let inverted = aspectSize.height / max(0.01, aspectSize.width)
                if inverted >= 0.5 && inverted <= 3.0 {
                    aspectRatio = inverted
                }
            }
            if aspectRatio >= 0.5 && aspectRatio <= 3.0 {
                ratio = aspectRatio
            }
        }

        let containerW = container.width
        let containerH = container.height
        var width: CGFloat = 0
        var height: CGFloat = 0

        switch scalingMode {
        case .stretch:
            // Already handled above, but keep for completeness
            return container

        case .aspectFit:
            // Largest game-aspect rect inscribed in container (centered)
            if containerW / containerH > ratio {
                height = containerH
                width = height * ratio
            } else {
                width = containerW
                height = width / ratio
            }

        case .aspectFill:
            // Smallest game-aspect rect covering container (centered, will be clipped)
            if containerW / containerH > ratio {
                width = containerW
                height = width / ratio
            } else {
                height = containerH
                width = height * ratio
            }

        case .integerScale:
            // `effectiveRect` (safeWidth/safeHeight) is the core framebuffer in
            // PIXELS; `container` is in view POINTS. Compare in the same space via
            // the screen scale, then express the result back in points. Without the
            // conversion, floor(180pt / 256px) = 0 → clamped to 1 → a 256pt frame
            // that overflows the skin cutout ("integer scale blows up too large").
            let screenScale = gpuViewController.view.window?.screen.scale ?? UIScreen.main.scale
            let intScale = max(1, floor(min(containerW * screenScale / safeWidth,
                                            containerH * screenScale / safeHeight)))
            width = safeWidth * intScale / screenScale
            height = safeHeight * intScale / screenScale

        case .nativeResolution:
            // 1:1 pixel mapping: the core's native PIXEL dims expressed in POINTS.
            let screenScale = gpuViewController.view.window?.screen.scale ?? UIScreen.main.scale
            width = safeWidth / screenScale
            height = safeHeight / screenScale
        }

        // Center within container
        let x = container.origin.x + (containerW - width) / 2
        let y = container.origin.y + (containerH - height) / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Called when the user changes the scaling mode while a DeltaSkin is active.
    /// Forces re-application of the skin's game screen frame with the new
    /// scaling mode, bypassing the frame-dedup logic that would otherwise
    /// short-circuit the update (the skin container hasn't changed, only the
    /// scaling within it has).
    internal func reapplyScalingModeForSkin() {
        guard isDeltaSkinEnabled else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.reapplyScalingModeForSkin() }
            return
        }

        // Use currentTargetFrame (the skin's container rect) if available
        guard let containerFrame = currentTargetFrame, isValidFrame(containerFrame) else {
            // Fall back to recalculating from skin
            applyViewportFromCurrentSkin()
            return
        }

        // Route ANY viewport-positioning core (thin/thick RetroArch incl. flycast,
        // and PPSSPP) through the RetroArch path FIRST — mirroring the boot path
        // (applyFrameToGPUView checks the viewport bridge first). Previously this was
        // gated to `coreLetterboxesInternally` (PPSSPP only), so on a scaling-mode
        // TOGGLE flycast fell through to the Metal branch and got a different frame
        // than at boot → portrait layout corrupted on toggle. applyFrameToRetroArch
        // still pre-applies the scaling mode only for PPSSPP (coreLetterboxesInternally);
        // real RetroArch cores like flycast keep the raw container rect (they scale
        // internally), exactly as on boot.
        if let viewport = core.bridge as? EmulatorCoreViewportPositioning,
           let gameScreenView = gpuViewController.view {
            applyFrameToRetroArch(containerFrame, gameScreenView: gameScreenView, viewport: viewport, reason: "reapply-scaling")
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
        } else if let metalVC = gpuViewController as? PVMetalViewController {
            // Handle Metal cores (most common)
            applyFrameToMetal(containerFrame, metalVC: metalVC, reason: "reapply-scaling")
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
        } else if !(core.bridge is EmulatorCoreViewportPositioning),
                  let gameScreenView = gpuViewController.view {
            // Handle GL cores
            applyFrameToGL(containerFrame, gameScreenView: gameScreenView, reason: "reapply-scaling")
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
        }
        // Real RetroArch cores handle scaling internally via the viewport bridge
    }

    // MARK: - Frame Application (Simplified)

    /// TEMP DIAGNOSTIC (skin-layout finickiness, May 31 2026): dump the full state at
    /// every viewport-apply site so a single Console.app capture pinpoints which path
    /// applies the sticking frame and what core geometry / safe-area it saw at that
    /// instant. The bugs are path-multiplicity + last-writer-wins stickiness, not the
    /// per-path math, so the discriminator is *which* path wins and with *what* inputs.
    /// Uses ILOG (not DLOG) so it survives in Console.app per the flycast debugging note.
    /// Remove once the launch / scaling-mode layout bugs are root-caused on-device.
    internal func logViewportApply(_ path: String, frame: CGRect, drawableSize: CGSize? = nil) {
        let ds = drawableSize.map { "\(Int($0.width))x\(Int($0.height))" } ?? "n/a"
        let geom = "core.screenRect=\(core.screenRect) bufferSize=\(core.bufferSize) aspectSize=\(core.aspectSize)"
        let layout = "bounds=\(view.bounds) safeArea=\(view.safeAreaInsets)"
        let scaling = "scalingMode=\(Defaults[.scalingMode]) explicitSet=\(Defaults[.userExplicitlySetScalingMode])"
        ILOG("SKIN-LAYOUT-DIAG[\(path)]: applied=\(frame) drawable=\(ds) | \(geom) | \(layout) | \(scaling)")
    }

    /// Apply frame to GPU view - single, clear application path
    internal func applyFrameToGPUView(_ frame: CGRect, reason: String = "?") {
        guard !isBridgeShuttingDownForViewport() else { return }
        guard let gameScreenView = gpuViewController.view else { return }
        guard isValidFrame(frame) else {
            ELOG("🎮 SKIN: Invalid frame: \(frame)")
            return
        }

        // Check if frame changed
        if abs(gameScreenView.frame.origin.x - frame.origin.x) < 0.5 &&
           abs(gameScreenView.frame.origin.y - frame.origin.y) < 0.5 &&
           abs(gameScreenView.frame.width - frame.width) < 0.5 &&
           abs(gameScreenView.frame.height - frame.height) < 0.5 {
            return
        }

        // Handle RetroArch cores
        if let viewport = core.bridge as? EmulatorCoreViewportPositioning {
            applyFrameToRetroArch(frame, gameScreenView: gameScreenView, viewport: viewport, reason: reason)
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
            return
        }

        // Handle Metal cores
        if let metalVC = gpuViewController as? PVMetalViewController {
            applyFrameToMetal(frame, metalVC: metalVC, reason: reason)
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
            return
        }

        // Handle GL cores
        applyFrameToGL(frame, gameScreenView: gameScreenView, reason: reason)
        #if !os(tvOS)
        refreshVirtualMouseLayout()
        #endif
    }

    /// PPSSPP conforms to `EmulatorCoreViewportPositioning` but, unlike thin/thick
    /// RetroArch, does NOT apply the app's `ScalingMode` itself — it aspect-fits its
    /// native PSP framebuffer into whatever view rect it is given. So PPSSPP needs the
    /// scaling mode pre-applied to its frame, whereas real RetroArch cores must keep
    /// the raw container rect (they scale internally; double-applying shrinks them).
    private var coreLetterboxesInternally: Bool {
        core.coreIdentifier?.lowercased().contains("ppsspp") == true
    }

    /// Apply frame to RetroArch core
    private func applyFrameToRetroArch(_ frame: CGRect, gameScreenView: UIView, viewport: EmulatorCoreViewportPositioning, reason: String = "?") {
        guard !isBridgeShuttingDownForViewport(viewport) else { return }
        let mtkView = gameScreenView.superview ?? gameScreenView

        // Ensure layout
        if mtkView.bounds.width <= 0 || mtkView.bounds.height <= 0 {
            mtkView.layoutIfNeeded()
        }

        // PPSSPP letterboxes internally, so pre-apply the scaling mode here. Real
        // RetroArch cores keep the raw container rect (they scale internally).
        let frameForCore = coreLetterboxesInternally ? adjustFrameForScalingMode(frame) : frame

        // Convert to MTKView coordinates
        let finalFrame = (mtkView != view) ? view.convert(frameForCore, to: mtkView) : frameForCore

        guard isValidFrame(finalFrame) else {
            ELOG("🎮 SKIN: Invalid frame after conversion: \(finalFrame)")
            return
        }

        viewport.setUseCustomRenderViewLayout(true)
        viewport.applyRenderViewFrameInTouchView(finalFrame)
        logViewportApply("RA:\(reason)", frame: finalFrame)
        ensureGPUViewVisibilityAndZOrder()
    }

    /// Apply frame to Metal core
    private func applyFrameToMetal(_ frame: CGRect, metalVC: PVMetalViewController, reason: String = "?") {
        ILOG("🎮 SKIN: Applying frame to Metal: \(frame)")

        // CRITICAL: Set custom positioning BEFORE setting frames
        // This ensures viewDidLayoutSubviews respects the custom frame
        (metalVC as PVGPUViewController).useCustomPositioning = true

        // Frames broadcast by the skin renderer are already in `self.view` coordinates:
        // the skin's GeometryReader spans the full container (the renderer adds safe-area
        // insets back explicitly rather than being laid out inside them), and the hosting
        // view / skin container / self.view are all coincident. This conversion is
        // therefore an identity today — it is kept only so the frame still lands correctly
        // if the skin container ever stops filling `self.view`. Do NOT read it as evidence
        // that the renderer works in some other space.
        let convertedFrame: CGRect
        if let skinContainer = skinContainerView, let hostingView = skinContainer.subviews.first {
            // The frame is in GeometryReader coordinates (which matches hosting view if it fills)
            // Convert through hosting view -> skin container -> self.view
            let frameInHostingView = frame  // Frame is already relative to hosting view's coordinate system
            let frameInContainer = hostingView.convert(frameInHostingView, to: skinContainer)
            convertedFrame = skinContainer.convert(frameInContainer, to: view)
            DLOG("🎮 SKIN: Converting frame - hostingView.frame=\(hostingView.frame), skinContainer.frame=\(skinContainer.frame), view.bounds=\(view.bounds)")
            DLOG("🎮 SKIN:   frame=\(frame) -> frameInContainer=\(frameInContainer) -> convertedFrame=\(convertedFrame)")
        } else {
            // No skin container or hosting view - frame is already in self.view coordinates
            convertedFrame = frame
            DLOG("🎮 SKIN: No skin container/hosting view, using frame as-is: \(frame)")
        }

        // Apply the user's chosen scaling mode within the skin's screen container.
        // The skin defines the game screen area, and the scaling mode controls
        // how the game content fits within that area.
        let scaledFrame = adjustFrameForScalingMode(convertedFrame)
        DLOG("🎮 SKIN: Scaling mode \(Defaults[.scalingMode]) adjusted frame: \(convertedFrame) -> \(scaledFrame)")

        (metalVC as PVGPUViewController).customFrame = scaledFrame

        metalVC.view.autoresizingMask = []
        metalVC.mtlView.autoresizingMask = []

        UIView.performWithoutAnimation {
            metalVC.view.frame = scaledFrame
            metalVC.mtlView.frame = metalVC.view.bounds
        }

        // ALWAYS use the device's native scale for DeltaSkin-hosted drawables.
        // The legacy conditional (use 1.0 unless .nativeResolution) was tied
        // to the non-DeltaSkin layout, where view size was already screen-
        // sized in points. Under DeltaSkin the view frame is fixed by the
        // skin's game area in POINTS — if we then size the drawable in points
        // too, the core's framebuffer renders at half the pixel density on
        // retina (visible as a small 1:1 thumbnail inside the skin window
        // for .aspectFit / .integerScale / .stretch / .aspectFill modes).
        // Sample selection / aspect math runs in the renderer against the
        // full-resolution drawable.
        let scale = metalVC.view.window?.screen.scale ?? UIScreen.main.scale
        let drawableSize = CGSize(width: scaledFrame.width * scale, height: scaledFrame.height * scale)

        metalVC.mtlView.drawableSize = drawableSize
        metalVC.mtlView.contentScaleFactor = scale
        metalVC.view.isHidden = false
        metalVC.mtlView.isHidden = false

        logViewportApply("Metal:\(reason)", frame: scaledFrame, drawableSize: drawableSize)

        ensureGPUViewVisibilityAndZOrder()
    }

    /// Apply frame to GL core
    private func applyFrameToGL(_ frame: CGRect, gameScreenView: UIView, reason: String = "?") {
        (gpuViewController as PVGPUViewController).useCustomPositioning = true

        // Convert frame from SwiftUI container coordinate system to self.view coordinate system
        let convertedFrame: CGRect
        if let skinContainer = skinContainerView, skinContainer != view {
            convertedFrame = skinContainer.convert(frame, to: view)
            DLOG("🎮 SKIN: Converted GL frame from skin container: \(frame) -> \(convertedFrame)")
        } else {
            convertedFrame = frame
        }

        // Apply scaling mode within the skin's screen container
        let scaledFrame = adjustFrameForScalingMode(convertedFrame)

        (gpuViewController as PVGPUViewController).customFrame = scaledFrame
        gameScreenView.autoresizingMask = []

        UIView.performWithoutAnimation {
            gameScreenView.frame = scaledFrame
        }

        gameScreenView.isHidden = false
        logViewportApply("GL:\(reason)", frame: scaledFrame)
        ensureGPUViewVisibilityAndZOrder()
    }

    // MARK: - Utilities

    /// Ensure GPU view is visible and below skin
    internal func ensureGPUViewVisibilityAndZOrder() {
        guard let gameScreenView = gpuViewController.view else { return }
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }) {
            view.insertSubview(gameScreenView, belowSubview: skinContainerView)
        }

        if let metalVC = gpuViewController as? PVMetalViewController, let mtlView = metalVC.mtlView {
            mtlView.isHidden = false
            mtlView.alpha = 1.0
        }
    }

    /// Reset GPU view to default position
    internal func resetGPUViewPosition() {
        guard let gameScreenView = gpuViewController.view else { return }
        guard view.bounds.width > 0 && view.bounds.height > 0 else { return }

        UIView.performWithoutAnimation {
            gameScreenView.frame = view.bounds
        }
        gameScreenView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gameScreenView.contentMode = .scaleAspectFit
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        if let metalVC = gpuViewController as? PVMetalViewController {
            UIView.performWithoutAnimation {
                metalVC.mtlView.frame = view.bounds
            }
            metalVC.mtlView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            metalVC.mtlView.contentMode = .scaleAspectFit
            (metalVC as PVGPUViewController).useCustomPositioning = false
        }

        ensureGPUViewVisibilityAndZOrder()
    }

    /// Store initial correct frame (first valid frame) - stable fallback
    private var initialCorrectFrame: CGRect? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.initialCorrectFrame) as? CGRect
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.initialCorrectFrame, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Reset to initial correct frame - similar to resetToCalculatedPosition
    @objc private func resetToInitialCorrectFrame() {
        guard let frame = initialCorrectFrame else { return }
        currentTargetFrame = frame
        applyFrameToGPUView(frame, reason: "reset-initial-correct")
    }
}

// MARK: - Associated Object Keys
private struct AssociatedKeys {
    static var initialCorrectFrame = "initialCorrectFrame"
}
