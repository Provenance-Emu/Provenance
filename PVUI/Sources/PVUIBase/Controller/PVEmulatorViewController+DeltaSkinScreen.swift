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
        applyFrameToGPUView(frame)
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
                applyFrameToGPUView(frame)
                return
            }

            // No valid frame yet - wait for notification with fresh frame calculation
            // This handles cases like rotation where we need a fresh calculation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                guard !self.isBridgeShuttingDownForViewport() else { return }
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
        let traits = DeltaSkinTraits(device: device, displayType: .standard, orientation: orientation, gameIdentifier: game?.title)

        // Check if skin has defined screen areas (screens, screenGroups, or gameScreenFrame)
        // For these skins, wait for protocol delegate callback instead of using fallback calculation
        let hasDefinedScreenArea = currentSkin?.screens(for: traits) != nil ||
                                  currentSkin?.screenGroups(for: traits) != nil ||
                                  hasGameScreenFrame(currentSkin, traits: traits)

        if hasDefinedScreenArea {
            // Wait for protocol delegate callback - don't use fallback calculation
            // The protocol delegate (viewportFrameDidUpdate) will be called shortly after rotation
            // But also try immediate calculation as fallback for initial load
            if let immediateFrame = calculateFrameFromSkin(), isValidFrame(immediateFrame) {
                currentTargetFrame = immediateFrame
                applyFrameToGPUView(immediateFrame)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                guard !self.isBridgeShuttingDownForViewport() else { return }
                if let frame = self.currentTargetFrame, self.isValidFrame(frame) {
                    // Verify frame is still correct, recalculate if needed
                    if let recalculatedFrame = self.calculateFrameFromSkin(), self.isValidFrame(recalculatedFrame) {
                        // Only update if significantly different (more than 10 pixels)
                        if abs(frame.origin.x - recalculatedFrame.origin.x) > 10 ||
                           abs(frame.origin.y - recalculatedFrame.origin.y) > 10 ||
                           abs(frame.width - recalculatedFrame.width) > 10 ||
                           abs(frame.height - recalculatedFrame.height) > 10 {
                            self.currentTargetFrame = recalculatedFrame
                            self.applyFrameToGPUView(recalculatedFrame)
                        }
                    } else {
                        self.applyFrameToGPUView(frame)
                    }
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

        // For simple skins without defined screen areas, calculate frame immediately
        if let frame = calculateFrameFromSkin(), isValidFrame(frame) {
            currentTargetFrame = frame
            applyFrameToGPUView(frame)
        } else {
            // If calculation fails, try again after a short delay (for initial load timing issues)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                guard !self.isBridgeShuttingDownForViewport() else { return }
                if let frame = self.calculateFrameFromSkin(), self.isValidFrame(frame) {
                    self.currentTargetFrame = frame
                    self.applyFrameToGPUView(frame)
                } else {
                    self.resetGPUViewPosition()
                }
            }
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

        // Try multiple display types to find a supported configuration
        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        var mappingSize: CGSize?
        var traits: DeltaSkinTraits?

        for displayType in displayTypes {
            let testTraits = DeltaSkinTraits(device: device, displayType: displayType, orientation: orientation)
            if let size = skin.mappingSize(for: testTraits) {
                mappingSize = size
                traits = testTraits
                break
            }
        }

        guard let mappingSize = mappingSize, let traits = traits else {
            DLOG("🎮 SKIN: No mapping size found for device \(device.rawValue), orientation \(orientation.rawValue)")
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
            // Snap to largest integer multiple that fits in the container
            let scaleX = floor(containerW / effectiveRect.width)
            let scaleY = floor(containerH / effectiveRect.height)
            let intScale = max(1, min(scaleX, scaleY))
            width = effectiveRect.width * intScale
            height = effectiveRect.height * intScale

        case .nativeResolution:
            // 1:1 pixel mapping -- use core's native output dimensions
            width = effectiveRect.width
            height = effectiveRect.height
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

        // PPSSPP is a viewport core hosted INSIDE a PVMetalViewController but it does
        // NOT scale internally. It must be checked BEFORE the Metal branch — otherwise
        // `applyFrameToMetal` wins and applies a no-op frame to PPSSPP's own overlaid
        // view, leaving the scaling change to only appear after a device rotation. This
        // mirrors `applyFrameToGPUView`, which also checks the viewport bridge first.
        if coreLetterboxesInternally,
           let viewport = core.bridge as? EmulatorCoreViewportPositioning,
           let gameScreenView = gpuViewController.view {
            applyFrameToRetroArch(containerFrame, gameScreenView: gameScreenView, viewport: viewport)
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
        } else if let metalVC = gpuViewController as? PVMetalViewController {
            // Handle Metal cores (most common)
            applyFrameToMetal(containerFrame, metalVC: metalVC)
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
        } else if !(core.bridge is EmulatorCoreViewportPositioning),
                  let gameScreenView = gpuViewController.view {
            // Handle GL cores
            applyFrameToGL(containerFrame, gameScreenView: gameScreenView)
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
        }
        // Real RetroArch cores handle scaling internally via the viewport bridge
    }

    // MARK: - Frame Application (Simplified)

    /// Apply frame to GPU view - single, clear application path
    internal func applyFrameToGPUView(_ frame: CGRect) {
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
            applyFrameToRetroArch(frame, gameScreenView: gameScreenView, viewport: viewport)
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
            return
        }

        // Handle Metal cores
        if let metalVC = gpuViewController as? PVMetalViewController {
            applyFrameToMetal(frame, metalVC: metalVC)
            #if !os(tvOS)
            refreshVirtualMouseLayout()
            #endif
            return
        }

        // Handle GL cores
        applyFrameToGL(frame, gameScreenView: gameScreenView)
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
    private func applyFrameToRetroArch(_ frame: CGRect, gameScreenView: UIView, viewport: EmulatorCoreViewportPositioning) {
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
        ensureGPUViewVisibilityAndZOrder()
    }

    /// Apply frame to Metal core
    private func applyFrameToMetal(_ frame: CGRect, metalVC: PVMetalViewController) {
        ILOG("🎮 SKIN: Applying frame to Metal: \(frame)")

        // CRITICAL: Set custom positioning BEFORE setting frames
        // This ensures viewDidLayoutSubviews respects the custom frame
        (metalVC as PVGPUViewController).useCustomPositioning = true

        // Convert frame from SwiftUI coordinate system to self.view coordinate system
        // The frame is calculated relative to the SwiftUI GeometryReader, which is inside the hosting view
        // The hosting view fills the skin container, which fills self.view
        // So we need to convert: GeometryReader -> hosting view -> skin container -> self.view
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

        ILOG("🎮 SKIN: Metal frame applied - useCustomPositioning: \(metalVC.useCustomPositioning), customFrame: \(metalVC.customFrame)")

        ensureGPUViewVisibilityAndZOrder()
    }

    /// Apply frame to GL core
    private func applyFrameToGL(_ frame: CGRect, gameScreenView: UIView) {
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
