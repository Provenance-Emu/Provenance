import SwiftUI
import PVLogging

/// Calculates and broadcasts screen position for skins
struct DeltaSkinScreenPositionWrapper: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let filters: Set<TestPatternEffect>
    let size: CGSize
    let screenAspectRatio: CGFloat?
    let isInEmulator: Bool

    @Environment(\.skinLayout) var layout

    /// Calculate screen frame from skin data
    private func calculateScreenFrame() -> CGRect? {
        guard let layout = layout,
              let mappingSize = skin.mappingSize(for: traits) else {
            return nil
        }

        // Get screen frame from skin (supports multiple formats)
        let screenFrame: CGRect?

        // Try screens array first
        if let screens = skin.screens(for: traits),
           let screen = screens.first,
           let outputFrame = screen.outputFrame {
            DLOG("🎮 SKIN: Using screens array path")
            DLOG("🎮 SKIN:   outputFrame: \(outputFrame)")
            DLOG("🎮 SKIN:   layout.width: \(layout.width), layout.height: \(layout.height)")

            // Validate outputFrame - check if it's normalized (0-1) or absolute pixels (> 1.0)
            // Use threshold (> 1.0) to detect - values > 1.0 are likely absolute pixels
            // But be careful - some normalized values might be > 1.0 if they represent more than 100% of space
            // So use a more conservative check: if values are > mappingSize, they're definitely absolute
            let isAbsolutePixels = outputFrame.width > mappingSize.width || outputFrame.height > mappingSize.height ||
                                   (outputFrame.width > 1.0 && outputFrame.height > 1.0 &&
                                    outputFrame.width < mappingSize.width && outputFrame.height < mappingSize.height)

            if isAbsolutePixels || (outputFrame.width > 10.0 || outputFrame.height > 10.0) {
                DLOG("🎮 SKIN: Detected absolute pixels in outputFrame: \(outputFrame), mappingSize: \(mappingSize)")

                // Normalize - ensure we don't divide by zero
                guard mappingSize.width > 0 && mappingSize.height > 0 else {
                    ELOG("🎮 SKIN: ERROR - Invalid mappingSize for normalization: \(mappingSize)")
                    return nil
                }

                let normalizedX = outputFrame.minX / mappingSize.width
                let normalizedY = outputFrame.minY / mappingSize.height
                let normalizedWidth = outputFrame.width / mappingSize.width
                let normalizedHeight = outputFrame.height / mappingSize.height

                DLOG("🎮 SKIN:   Normalized: x=\(normalizedX), y=\(normalizedY), w=\(normalizedWidth), h=\(normalizedHeight)")
                DLOG("🎮 SKIN:   layout.width: \(layout.width), layout.height: \(layout.height)")

                // Ensure layout dimensions are valid
                guard layout.width > 0 && layout.height > 0 else {
                    ELOG("🎮 SKIN: ERROR - Invalid layout dimensions: width=\(layout.width), height=\(layout.height)")
                    return nil
                }

                // Check for invalid normalized values (NaN or infinity)
                guard normalizedX.isFinite && normalizedY.isFinite &&
                      normalizedWidth.isFinite && normalizedHeight.isFinite else {
                    ELOG("🎮 SKIN: ERROR - Invalid normalized values: x=\(normalizedX), y=\(normalizedY), w=\(normalizedWidth), h=\(normalizedHeight)")
                    return nil
                }

                screenFrame = CGRect(
                    x: normalizedX * layout.width,
                    y: normalizedY * layout.height,
                    width: normalizedWidth * layout.width,
                    height: normalizedHeight * layout.height
                )

                DLOG("🎮 SKIN:   Calculated screenFrame (screens array): \(screenFrame)")
                DLOG("🎮 SKIN:   layout.xOffset: \(layout.xOffset), layout.yOffset: \(layout.yOffset)")
            } else {
                // outputFrame is normalized (0-1), scale by layout dimensions
                DLOG("🎮 SKIN: Treating outputFrame as normalized: \(outputFrame)")
                screenFrame = CGRect(
                    x: outputFrame.minX * layout.width,
                    y: outputFrame.minY * layout.height,
                    width: outputFrame.width * layout.width,
                    height: outputFrame.height * layout.height
                )
                DLOG("🎮 SKIN:   Calculated screenFrame (normalized): \(screenFrame)")
            }
        }
        // Try screen groups
        else if let groups = skin.screenGroups(for: traits),
                 let group = groups.first,
                 let screen = group.screens.first,
                 let outputFrame = screen.outputFrame {
            DLOG("🎮 SKIN: Using screen groups path")
            DLOG("🎮 SKIN:   outputFrame: \(outputFrame)")
            DLOG("🎮 SKIN:   layout.width: \(layout.width), layout.height: \(layout.height)")

            // Check if outputFrame is absolute pixels or normalized
            let isAbsolutePixels = outputFrame.width > mappingSize.width || outputFrame.height > mappingSize.height ||
                                   (outputFrame.width > 1.0 && outputFrame.height > 1.0 &&
                                    outputFrame.width < mappingSize.width && outputFrame.height < mappingSize.height)

            if isAbsolutePixels || (outputFrame.width > 10.0 || outputFrame.height > 10.0) {
                DLOG("🎮 SKIN: Detected absolute pixels in outputFrame (screenGroups): \(outputFrame), mappingSize: \(mappingSize)")

                // Normalize first if needed
                let normalizedX = outputFrame.minX / mappingSize.width
                let normalizedY = outputFrame.minY / mappingSize.height
                let normalizedWidth = outputFrame.width / mappingSize.width
                let normalizedHeight = outputFrame.height / mappingSize.height

                DLOG("🎮 SKIN:   Normalized: x=\(normalizedX), y=\(normalizedY), w=\(normalizedWidth), h=\(normalizedHeight)")

                screenFrame = CGRect(
                    x: normalizedX * layout.width,
                    y: normalizedY * layout.height,
                    width: normalizedWidth * layout.width,
                    height: normalizedHeight * layout.height
                )

                DLOG("🎮 SKIN:   Calculated screenFrame (screen groups): \(screenFrame)")
            } else {
                screenFrame = CGRect(
                    x: outputFrame.minX * layout.width,
                    y: outputFrame.minY * layout.height,
                    width: outputFrame.width * layout.width,
                    height: outputFrame.height * layout.height
                )
            }
        }
        // Try gameScreenFrame dictionary
        else if let gameScreenFrame = getGameScreenFrame(traits: traits) {
            DLOG("🎮 SKIN: Found gameScreenFrame: \(gameScreenFrame)")
            DLOG("🎮 SKIN:   mappingSize: \(mappingSize)")
            DLOG("🎮 SKIN:   layout.width: \(layout.width), layout.height: \(layout.height)")
            DLOG("🎮 SKIN:   layout.scale: \(layout.scale)")

            // Check if normalized (0-1) or absolute pixels
            // Normalized coordinates are typically <= 1.0
            let isNormalized = gameScreenFrame.width <= 1.0 && gameScreenFrame.height <= 1.0

            if isNormalized {
                DLOG("🎮 SKIN: Treating gameScreenFrame as normalized (0-1)")
                // Normalized: scale by layout dimensions
                screenFrame = CGRect(
                    x: gameScreenFrame.minX * layout.width,
                    y: gameScreenFrame.minY * layout.height,
                    width: gameScreenFrame.width * layout.width,
                    height: gameScreenFrame.height * layout.height
                )
            } else {
                DLOG("🎮 SKIN: Treating gameScreenFrame as absolute pixels - normalizing by mappingSize first")
                DLOG("🎮 SKIN:   Raw gameScreenFrame: \(gameScreenFrame)")
                DLOG("🎮 SKIN:   mappingSize: \(mappingSize)")

                // Absolute pixels: normalize by mappingSize, then scale by layout dimensions
                // This handles cases where gameScreenFrame is in original image coordinates
                let normalizedX = gameScreenFrame.minX / mappingSize.width
                let normalizedY = gameScreenFrame.minY / mappingSize.height
                let normalizedWidth = gameScreenFrame.width / mappingSize.width
                let normalizedHeight = gameScreenFrame.height / mappingSize.height

                DLOG("🎮 SKIN:   Normalized: x=\(normalizedX), y=\(normalizedY), w=\(normalizedWidth), h=\(normalizedHeight)")

                screenFrame = CGRect(
                    x: normalizedX * layout.width,
                    y: normalizedY * layout.height,
                    width: normalizedWidth * layout.width,
                    height: normalizedHeight * layout.height
                )

                DLOG("🎮 SKIN:   Calculated screenFrame: \(screenFrame)")
            }
        }
        // Default: calculate from buttons - use reasonable screen size based on available space
        else if let buttons = skin.buttons(for: traits),
                  let topButton = buttons.min(by: { $0.frame.minY < $1.frame.minY }) {
            let aspectRatio = screenAspectRatio ?? (4.0/3.0)

            // Calculate screen size based on available space, not entire skin width
            // Use the space above the top button as the maximum height
            let maxScreenHeight = max(layout.yOffset, size.height * 0.6)
            let screenHeight = min(maxScreenHeight, size.height * 0.8)
            let screenWidth = screenHeight * aspectRatio

            // Ensure screen fits within available width
            let constrainedWidth = min(screenWidth, size.width * 0.9)
            let constrainedHeight = constrainedWidth / aspectRatio

            screenFrame = CGRect(
                x: (size.width - constrainedWidth) / 2,
                y: max(0, (layout.yOffset - constrainedHeight) / 2),
                width: constrainedWidth,
                height: constrainedHeight
            )
        } else {
            return nil
        }

        // Convert to absolute coordinates by adding layout offset
        guard let screenFrame = screenFrame else { return nil }

        // Validate intermediate screenFrame before applying offsets
        // Only check basic validity - don't reject based on size as that might be too strict
        guard screenFrame.width > 0 && screenFrame.height > 0,
              screenFrame.width.isFinite && screenFrame.height.isFinite,
              screenFrame.origin.x.isFinite && screenFrame.origin.y.isFinite else {
            ELOG("🎮 SKIN: Invalid intermediate screenFrame (basic check failed): \(screenFrame)")
            return nil
        }

        let finalFrame = CGRect(
            x: layout.xOffset + screenFrame.minX,
            y: layout.yOffset + screenFrame.minY,
            width: screenFrame.width,
            height: screenFrame.height
        )

        // Basic validation - only check for positive, finite values
        guard finalFrame.width > 0 && finalFrame.height > 0,
              finalFrame.width.isFinite && finalFrame.height.isFinite,
              finalFrame.origin.x.isFinite && finalFrame.origin.y.isFinite else {
            ELOG("🎮 SKIN: Invalid final frame (basic check failed): \(finalFrame)")
            ELOG("🎮 SKIN:   screenFrame: \(screenFrame)")
            ELOG("🎮 SKIN:   layout.xOffset: \(layout.xOffset), layout.yOffset: \(layout.yOffset)")
            return nil
        }

        // Always broadcast if basic validation passes - let the receiver handle size validation
        DLOG("🎮 SKIN: Broadcasting final frame: \(finalFrame)")
        broadcastFrame(finalFrame)
        return finalFrame
    }

    /// Get gameScreenFrame from JSON dictionary
    private func getGameScreenFrame(traits: DeltaSkinTraits) -> CGRect? {
        guard let representations = skin.jsonRepresentation["representations"] as? [String: Any],
              let deviceRep = representations[traits.device.rawValue] as? [String: Any],
              let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
              let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
              let frameDict = orientationRep["gameScreenFrame"] as? [String: Any],
              let x = frameDict["x"] as? CGFloat,
              let y = frameDict["y"] as? CGFloat,
              let width = frameDict["width"] as? CGFloat,
              let height = frameDict["height"] as? CGFloat else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Validate frame is reasonable (deprecated - using inline checks instead)
    private func isValidFrame(_ frame: CGRect) -> Bool {
        // Basic validation: positive, finite values
        guard frame.width > 0 && frame.height > 0,
              frame.width.isFinite && frame.height.isFinite,
              frame.origin.x.isFinite && frame.origin.y.isFinite else {
            return false
        }

        // Frame should be reasonable relative to view size (allow up to 3x for retina/scale and margins)
        let maxReasonableSize = max(size.width, size.height) * 3.0
        guard frame.width <= maxReasonableSize && frame.height <= maxReasonableSize else {
            return false
        }

        // Absolute maximum threshold to catch obviously wrong values
        guard frame.width < 10000 && frame.height < 10000 else {
            return false
        }

        return true
    }

    /// Broadcast frame to emulator controller
    private func broadcastFrame(_ frame: CGRect) {
        guard isInEmulator else { return }

        // Prevent duplicate broadcasts - only broadcast if frame actually changed
        if let lastFrame = lastBroadcastFrame,
           abs(lastFrame.origin.x - frame.origin.x) < 0.5 &&
           abs(lastFrame.origin.y - frame.origin.y) < 0.5 &&
           abs(lastFrame.width - frame.width) < 0.5 &&
           abs(lastFrame.height - frame.height) < 0.5 {
            DLOG("🎮 SKIN: Frame unchanged, skipping broadcast: \(frame)")
            return
        }

        lastBroadcastFrame = frame
        DLOG("🎮 SKIN: Broadcasting frame: \(frame)")

        NotificationCenter.default.post(
            name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"),
            object: nil,
            userInfo: ["frame": NSValue(cgRect: frame)]
        )
    }

    @State private var lastSize: CGSize = .zero
    @State private var lastLayout: DeltaSkinView.SkinLayout?
    @State private var calculationTask: Task<Void, Never>?
    @State private var lastBroadcastFrame: CGRect?

    var body: some View {
        Color.clear
            .onAppear {
                lastSize = size
                lastLayout = layout
                // Calculate immediately on appear - no debounce needed
                _ = calculateScreenFrame()
            }
            .onChange(of: size) { newSize in
                // Only recalculate if size actually changed significantly (more than 1 point)
                guard abs(newSize.width - lastSize.width) > 1.0 || abs(newSize.height - lastSize.height) > 1.0 else { return }
                lastSize = newSize

                // Cancel any pending calculations
                calculationTask?.cancel()

                // For size changes, debounce slightly to avoid intermediate rotation states
                calculationTask = Task {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms debounce (reduced from 150ms)
                    guard !Task.isCancelled else { return }
                    _ = await MainActor.run {
                        calculateScreenFrame()
                    }
                }
            }
            .onChange(of: layout) { newLayout in
                // Only recalculate if layout actually changed (using Equatable check)
                guard newLayout != lastLayout else { return }
                lastLayout = newLayout

                // Cancel any pending calculations
                calculationTask?.cancel()

                // For layout changes, calculate immediately if layout is valid
                // Layout changes happen after size stabilizes, so we can calculate right away
                if (layout?.width ?? 0) > 0 && (layout?.height ?? 0) > 0 && size.width > 0 && size.height > 0 {
                    calculateScreenFrame()
                } else {
                    // If layout is invalid, wait a bit for it to stabilize
                    calculationTask = Task {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms debounce
                        guard !Task.isCancelled else { return }
                        _ = await MainActor.run {
                            calculateScreenFrame()
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeltaSkinForceRecalculate"))) { _ in
                // Force recalculation when requested (e.g., after rotation completes)
                calculationTask?.cancel()
                calculationTask = Task {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay for rotation to complete
                    guard !Task.isCancelled else { return }
                    _ = await MainActor.run {
                        DLOG("🎮 SKIN: Forcing frame recalculation after rotation")
                        calculateScreenFrame()
                    }
                }
            }
    }
}
