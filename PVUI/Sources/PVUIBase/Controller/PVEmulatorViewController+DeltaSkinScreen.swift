import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVLogging
import PVCoreBridge
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
        applyFrameToGPUView(frame)
    }

    /// Handle skin loaded notification
    @objc private func handleSkinLoaded(_ notification: Notification) {
        guard let skinId = notification.userInfo?["skinId"] as? String else { return }

        if currentSkin == nil || currentSkin?.identifier != skinId {
            let manager = DeltaSkinManager.shared
            if manager.skinsAreLoaded, let skin = manager.loadedSkins.first(where: { $0.identifier == skinId }) {
                currentSkin = skin
                DLOG("🎮 SKIN: Set currentSkin from notification: \(skin.name)")
                applyViewportFromCurrentSkin()
            }
        }
    }

    // MARK: - Frame Handling (Simplified)

    /// Handle frame update notification - single entry point for all frames
    @objc private func handleFrameUpdated(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { [weak self] in self?.handleFrameUpdated(notification) }
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
        applyFrameToGPUView(frame)
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
                applyFrameToGPUView(initial)
            }
            return false
        }

        // Store initial correct frame (first valid frame)
        if initialCorrectFrame == nil {
            initialCorrectFrame = frame
            ILOG("🎮 SKIN: Stored initial correct frame: \(frame)")
        }

        // Skip if unchanged
        if let current = currentTargetFrame,
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

    /// Apply viewport from current skin - single, simple entry point
    internal func applyViewportFromCurrentSkin() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { [weak self] in self?.applyViewportFromCurrentSkin() }
            return
        }

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
                applyFrameToGPUView(frame)
                return
            }

            // No valid frame yet - wait for notification with fresh frame calculation
            // This handles cases like rotation where we need a fresh calculation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                if let frame = self.currentTargetFrame, self.isValidFrame(frame) {
                    self.applyFrameToGPUView(frame)
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
            applyFrameToGPUView(frame)
            return
        }

        // Calculate traits for checking screen area definitions
        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        let orientation: DeltaSkinOrientation = view.bounds.width > view.bounds.height ? .landscape : .portrait
        let traits = DeltaSkinTraits(device: device, displayType: .standard, orientation: orientation)

        // Check if skin has defined screen areas (screens, screenGroups, or gameScreenFrame)
        // For these skins, wait for protocol delegate callback instead of using fallback calculation
        let hasDefinedScreenArea = currentSkin?.screens(for: traits) != nil ||
                                  currentSkin?.screenGroups(for: traits) != nil ||
                                  hasGameScreenFrame(currentSkin, traits: traits)

        if hasDefinedScreenArea {
            // Wait for protocol delegate callback - don't use fallback calculation
            // The protocol delegate (viewportFrameDidUpdate) will be called shortly after rotation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                if let frame = self.currentTargetFrame, self.isValidFrame(frame) {
                    self.applyFrameToGPUView(frame)
                } else {
                    // If still no frame after waiting, use fallback
                    if let frame = self.calculateFrameFromSkin(), self.isValidFrame(frame) {
                        self.currentTargetFrame = frame
                        self.applyFrameToGPUView(frame)
                    } else {
                        self.resetGPUViewPosition()
                    }
                }
            }
            return
        }

        // For simple skins without defined screen areas, calculate frame if no protocol delegate callback available
        if let frame = calculateFrameFromSkin(), isValidFrame(frame) {
            currentTargetFrame = frame
            applyFrameToGPUView(frame)
        } else {
            resetGPUViewPosition()
        }
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

        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        let orientation: DeltaSkinOrientation = view.bounds.width > view.bounds.height ? .landscape : .portrait
        let traits = DeltaSkinTraits(device: device, displayType: .standard, orientation: orientation)

        guard let mappingSize = skin.mappingSize(for: traits) else { return nil }

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
        if let screenFrame = getScreenFrame(from: skin, traits: traits, mappingSize: mappingSize) {
            // Convert normalized screen frame to view coordinates
            // screenFrame is normalized (0-1) relative to mappingSize
            // Position is relative to where the scaled skin is positioned (offset)
            return CGRect(
                x: offset.x + screenFrame.minX * scaledSize.width,
                y: offset.y + screenFrame.minY * scaledSize.height,
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
        // Try screens array
        if let screens = skin.screens(for: traits),
           let screen = screens.first,
           let outputFrame = screen.outputFrame {
            return normalizeFrame(outputFrame, mappingSize: mappingSize)
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

    /// Normalize frame to 0-1 coordinates
    private func normalizeFrame(_ frame: CGRect, mappingSize: CGSize) -> CGRect {
        // If already normalized (values <= 1.0), return as-is
        if frame.width <= 1.0 && frame.height <= 1.0 {
            return frame
        }

        // If clearly absolute pixels (large values), normalize
        if frame.width > 10.0 || frame.height > 10.0 {
            guard mappingSize.width > 0 && mappingSize.height > 0 else { return frame }
            return CGRect(
                x: frame.minX / mappingSize.width,
                y: frame.minY / mappingSize.height,
                width: frame.width / mappingSize.width,
                height: frame.height / mappingSize.height
            )
        }

        return frame
    }

    // MARK: - Frame Application (Simplified)

    /// Apply frame to GPU view - single, clear application path
    internal func applyFrameToGPUView(_ frame: CGRect) {
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
            applyFrameToRetroArch(frame, gameScreenView: gameScreenView, viewport: viewport)
            return
        }

        // Handle Metal cores
        if let metalVC = gpuViewController as? PVMetalViewController {
            applyFrameToMetal(frame, metalVC: metalVC)
            return
        }

        // Handle GL cores
        applyFrameToGL(frame, gameScreenView: gameScreenView)
    }

    /// Apply frame to RetroArch core
    private func applyFrameToRetroArch(_ frame: CGRect, gameScreenView: UIView, viewport: EmulatorCoreViewportPositioning) {
        let mtkView = gameScreenView.superview ?? gameScreenView

        // Ensure layout
        if mtkView.bounds.width <= 0 || mtkView.bounds.height <= 0 {
            mtkView.layoutIfNeeded()
        }

        // Convert to MTKView coordinates
        let finalFrame = (mtkView != view) ? view.convert(frame, to: mtkView) : frame

        guard isValidFrame(finalFrame) else {
            ELOG("🎮 SKIN: Invalid frame after conversion: \(finalFrame)")
            return
        }

        viewport.setUseCustomRenderViewLayout(true)
        viewport.applyRenderViewFrameInTouchView(finalFrame)
        ensureGPUViewVisibilityAndZOrder()
    }

    /// Apply frame to Metal core
    private func applyFrameToMetal(_ frame: CGRect, metalVC: PVMetalViewController) {
        ILOG("🎮 SKIN: Applying frame to Metal: \(frame)")

        // CRITICAL: Set custom positioning BEFORE setting frames
        // This ensures viewDidLayoutSubviews respects the custom frame
        (metalVC as PVGPUViewController).useCustomPositioning = true
        (metalVC as PVGPUViewController).customFrame = frame

        metalVC.view.autoresizingMask = []
        metalVC.mtlView.autoresizingMask = []

        UIView.performWithoutAnimation {
            metalVC.view.frame = frame
            metalVC.mtlView.frame = metalVC.view.bounds
        }

        let scale = metalVC.renderSettings.nativeScaleEnabled ?
            (metalVC.view.window?.screen.scale ?? UIScreen.main.scale) : 1.0
        let drawableSize = CGSize(width: frame.width * scale, height: frame.height * scale)

        metalVC.mtlView.drawableSize = drawableSize
        metalVC.mtlView.contentScaleFactor = scale
        metalVC.view.isHidden = false
        metalVC.mtlView.isHidden = false

        ILOG("🎮 SKIN: Metal frame applied - useCustomPositioning: \(metalVC.useCustomPositioning), customFrame: \(metalVC.customFrame)")

        ensureGPUViewVisibilityAndZOrder()
    }

    /// Apply frame to GL core
    private func applyFrameToGL(_ frame: CGRect, gameScreenView: UIView) {
        (gpuViewController as PVGPUViewController).useCustomPositioning = true
        (gpuViewController as PVGPUViewController).customFrame = frame
        gameScreenView.autoresizingMask = []

        UIView.performWithoutAnimation {
            gameScreenView.frame = frame
        }

        gameScreenView.isHidden = false
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
        applyFrameToGPUView(frame)
    }
}

// MARK: - Associated Object Keys
private struct AssociatedKeys {
    static var initialCorrectFrame = "initialCorrectFrame"
}
