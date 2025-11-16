import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVLogging
import PVCoreBridge
import PVUIBase
import ObjectiveC

extension PVEmulatorViewController {

    // MARK: - Setup

    /// Update GPU view position based on DeltaSkin screen information
    func updateGPUViewPositionForDeltaSkin() {
        guard gpuViewController.view != nil else { return }

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

        // Use notification frame if available (preferred - most accurate)
        if let frame = currentTargetFrame, isValidFrame(frame) {
            applyFrameToGPUView(frame)
            return
        }

        // For default skins, wait for notification frame
        if isDefaultSkin {
            currentTargetFrame = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                if let frame = self.currentTargetFrame, self.isValidFrame(frame) {
                    self.applyFrameToGPUView(frame)
                } else {
                    self.resetGPUViewPosition()
                }
            }
            return
        }

        // For non-default skins, calculate frame if no notification available
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
    private func calculateFrameFromSkin() -> CGRect? {
        guard let skin = currentSkin else { return nil }
        guard view.bounds.width > 0 && view.bounds.height > 0 else { return nil }

        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        let orientation: DeltaSkinOrientation = view.bounds.width > view.bounds.height ? .landscape : .portrait
        let traits = DeltaSkinTraits(device: device, displayType: .standard, orientation: orientation)

        guard let mappingSize = skin.mappingSize(for: traits) else { return nil }

        // Calculate layout (same as DeltaSkinView)
        let viewSize = view.bounds.size
        let scale = calculateScale(for: traits, viewSize: viewSize, mappingSize: mappingSize)
        let scaledSize = CGSize(width: mappingSize.width * scale, height: mappingSize.height * scale)
        let offset = calculateOffset(for: traits, viewSize: viewSize, scaledSize: scaledSize)

        // Get screen frame from skin
        if let screenFrame = getScreenFrame(from: skin, traits: traits, mappingSize: mappingSize) {
            // Convert normalized screen frame to view coordinates
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
    private func calculateScale(for traits: DeltaSkinTraits, viewSize: CGSize, mappingSize: CGSize) -> CGFloat {
        if traits.device == .iphone && traits.orientation == .portrait {
            let scale = viewSize.width / mappingSize.width
            let scaledHeight = mappingSize.height * scale
            return scaledHeight > viewSize.height ? min(scale, viewSize.height / mappingSize.height) : scale
        }
        return min(viewSize.width / mappingSize.width, viewSize.height / mappingSize.height)
    }

    /// Calculate offset for skin layout
    private func calculateOffset(for traits: DeltaSkinTraits, viewSize: CGSize, scaledSize: CGSize) -> CGPoint {
        let x = (viewSize.width - scaledSize.width) / 2
        let y = (traits.device == .iphone && traits.orientation == .portrait) ?
            (viewSize.height - scaledSize.height) : ((viewSize.height - scaledSize.height) / 2)
        return CGPoint(x: x, y: y)
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
