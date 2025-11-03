import SwiftUI
import PVLogging

/// Wrapper view that calculates and broadcasts screen positions, regardless of whether color bars are visible
struct DeltaSkinScreenPositionWrapper: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let filters: Set<TestPatternEffect>
    let size: CGSize
    let screenAspectRatio: CGFloat?
    let isInEmulator: Bool

    @Environment(\.skinLayout) var layout

    private var effectiveAspectRatio: CGFloat {
        screenAspectRatio ?? (4.0/3.0)  // Default to 4:3 if none specified
    }

    private func hasScreenPosition(for traits: DeltaSkinTraits) -> Bool {
        // Check both formats
        if let screens = skin.screens(for: traits), !screens.isEmpty {
            return true
        }

        // Check if representation has gameScreenFrame
        if let representations = skin.jsonRepresentation["representations"] as? [String: Any],
           let deviceRep = representations[traits.device.rawValue] as? [String: Any],
           let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
           let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
           orientationRep["gameScreenFrame"] != nil {
            return true
        }

        return false
    }

    /// Get gameScreenFrame from raw dictionary for simple image-based skins
    private func getGameScreenFrameFromRawDictionary(traits: DeltaSkinTraits) -> CGRect? {
        guard let representations = skin.jsonRepresentation["representations"] as? [String: Any],
              let deviceRep = representations[traits.device.rawValue] as? [String: Any],
              let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
              let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
              let gameScreenFrameDict = orientationRep["gameScreenFrame"] as? [String: Any],
              let x = gameScreenFrameDict["x"] as? CGFloat,
              let y = gameScreenFrameDict["y"] as? CGFloat,
              let width = gameScreenFrameDict["width"] as? CGFloat,
              let height = gameScreenFrameDict["height"] as? CGFloat else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func calculateScreenFrame() -> CGRect? {
        guard let layout = layout else { return nil }
        guard let mappingSize = skin.mappingSize(for: traits) else { return nil }

        // Use layout scale directly - this ensures perfect consistency with DeltaSkinView
        let scale = layout.scale

        // Check for screen groups first (for dual-screen systems like 3DS)
        // Only use dual-screen logic if there are actually 2+ screens
        if let screenGroups = skin.screenGroups(for: traits),
           let mainGroup = screenGroups.first {
            if mainGroup.screens.count >= 2 {
                // Handle dual-screen systems
                return calculateAndBroadcastDualScreens(screenGroup: mainGroup, layout: layout)
            } else if mainGroup.screens.count == 1,
                      let singleScreen = mainGroup.screens.first {
                // Handle single screen in a group using layout values
                if let outputFrame = singleScreen.outputFrame {
                    // Scale outputFrame using layout dimensions (matching DeltaSkinView.screenView)
                    let scaledInLayout = CGRect(
                        x: outputFrame.minX * layout.width,
                        y: outputFrame.minY * layout.height,
                        width: outputFrame.width * layout.width,
                        height: outputFrame.height * layout.height
                    )

                    // Position relative to skin container (matching DeltaSkinView positioning)
                    // The skin container is positioned, and screen position is relative to it
                    // scaledInLayout.midX/midY are relative to container, so absolute origin is:
                    let finalFrame = CGRect(
                        x: layout.xOffset + scaledInLayout.minX,
                        y: layout.yOffset + scaledInLayout.minY,
                        width: scaledInLayout.width,
                        height: scaledInLayout.height
                    )

                    let offset = CGPoint(x: layout.xOffset, y: layout.yOffset)
                    broadcastFramePosition(finalFrame, outputFrame: outputFrame, mappingSize: mappingSize, scale: scale, offset: offset, screenId: singleScreen.id)
                    return finalFrame
                }
            }
        }

        if hasScreenPosition(for: traits) {
            // Use explicit screen position from skin
            if let screens = skin.screens(for: traits), let screen = screens.first {
                if let outputFrame = screen.outputFrame {
                    // Scale outputFrame using layout dimensions (matching DeltaSkinView.screenView)
                    let scaledInLayout = CGRect(
                        x: outputFrame.minX * layout.width,
                        y: outputFrame.minY * layout.height,
                        width: outputFrame.width * layout.width,
                        height: outputFrame.height * layout.height
                    )

                    // Position relative to skin container (matching DeltaSkinView positioning)
                    // The skin container is positioned, and screen position is relative to it
                    // scaledInLayout.midX/midY are relative to container, so absolute origin is:
                    let finalFrame = CGRect(
                        x: layout.xOffset + scaledInLayout.minX,
                        y: layout.yOffset + scaledInLayout.minY,
                        width: scaledInLayout.width,
                        height: scaledInLayout.height
                    )

                    let offset = CGPoint(x: layout.xOffset, y: layout.yOffset)
                    broadcastFramePosition(finalFrame, outputFrame: outputFrame, mappingSize: mappingSize, scale: scale, offset: offset, screenId: screen.id)
                    return finalFrame
                }
            } else if let gameScreenFrame = getGameScreenFrameFromRawDictionary(traits: traits) {
                // Handle gameScreenFrame for simple image-based skins
                // gameScreenFrame coordinates are in mappingSize space (e.g., 414x736)
                // Layout is calculated from effective image size (e.g., 1921x4157 for simple skins)
                // So layout.width represents scaled image width, not scaled mapping width
                // To convert gameScreenFrame to view coordinates:
                // 1. Convert mappingSize coords to image coords: multiply by (imageSize / mappingSize)
                // 2. Convert image coords to view coords: multiply by layout.scale
                // Combined: multiply by (imageSize / mappingSize) * scale = layout.width / mappingSize.width
                // This formula works because layout.width = imageSize.width * layout.scale
                let mappingToLayoutScaleX = layout.width / mappingSize.width
                let mappingToLayoutScaleY = layout.height / mappingSize.height
                
                // Scale gameScreenFrame from mappingSize space to layout (view) space
                let scaledInLayout = CGRect(
                    x: gameScreenFrame.minX * mappingToLayoutScaleX,
                    y: gameScreenFrame.minY * mappingToLayoutScaleY,
                    width: gameScreenFrame.width * mappingToLayoutScaleX,
                    height: gameScreenFrame.height * mappingToLayoutScaleY
                )

                // Position relative to skin container (layout already accounts for positioning)
                let finalFrame = CGRect(
                    x: layout.xOffset + scaledInLayout.minX,
                    y: layout.yOffset + scaledInLayout.minY,
                    width: scaledInLayout.width,
                    height: scaledInLayout.height
                )

                let offset = CGPoint(x: layout.xOffset, y: layout.yOffset)
                broadcastFramePosition(finalFrame, outputFrame: gameScreenFrame, mappingSize: mappingSize, scale: scale, offset: offset)
                return finalFrame
            } else {
                // Default single screen
                let outputFrame = DeltaSkinDefaults.defaultScreenFrame(
                    for: skin.gameType,
                    in: mappingSize,
                    buttons: skin.buttons(for: traits),
                    isPreview: false
                )

                let finalFrame = scaledFrame(
                    outputFrame,
                    mappingSize: mappingSize,
                    scale: scale,
                    offset: CGPoint(x: layout.xOffset, y: layout.yOffset)
                )

                broadcastFramePosition(finalFrame, outputFrame: outputFrame, mappingSize: mappingSize, scale: scale, offset: CGPoint(x: layout.xOffset, y: layout.yOffset))
                return finalFrame
            }
        } else {
            // Calculate position based on available space
            guard let buttons = skin.buttons(for: traits) else { return nil }

            // Use full width of skin for screen width
            let screenWidth = layout.width

            // Calculate height based on aspect ratio
            let screenHeight = screenWidth / effectiveAspectRatio

            // Center in available space above skin
            let availableSpace = layout.yOffset

            let x = (size.width - screenWidth) / 2
            let y = (availableSpace - screenHeight) / 2

            let finalFrame = CGRect(
                x: x,
                y: y,
                width: screenWidth,
                height: screenHeight
            )

            broadcastFramePosition(finalFrame)
            return finalFrame
        }

        return nil
    }

    /// Calculate and broadcast frames for dual-screen systems (3DS, DS)
    private func calculateAndBroadcastDualScreens(screenGroup: DeltaSkinScreenGroup, layout: DeltaSkinView.SkinLayout) -> CGRect? {
        guard let mappingSize = skin.mappingSize(for: traits) else { return nil }

        // Use layout values directly for consistency
        let scale = layout.scale

        // Sort screens by Y position (top screen first)
        let sortedScreens = screenGroup.screens.sorted { screen1, screen2 in
            guard let frame1 = screen1.outputFrame, let frame2 = screen2.outputFrame else {
                return false
            }
            return frame1.minY < frame2.minY
        }

        var combinedRect: CGRect?

        // Broadcast each screen separately
        for screen in sortedScreens {
            guard let outputFrame = screen.outputFrame else { continue }

            // Scale outputFrame using layout dimensions (matching DeltaSkinView.screenView)
            let scaledInLayout = CGRect(
                x: outputFrame.minX * layout.width,
                y: outputFrame.minY * layout.height,
                width: outputFrame.width * layout.width,
                height: outputFrame.height * layout.height
            )

            // Position relative to skin container (matching single-screen logic)
            let finalFrame = CGRect(
                x: layout.xOffset + scaledInLayout.minX,
                y: layout.yOffset + scaledInLayout.minY,
                width: scaledInLayout.width,
                height: scaledInLayout.height
            )

            // Broadcast each screen frame
            broadcastFramePosition(
                finalFrame,
                outputFrame: outputFrame,
                mappingSize: mappingSize,
                scale: scale,
                offset: CGPoint(x: layout.xOffset, y: layout.yOffset),
                screenId: screen.id
            )

            // Combine frames for return value
            if let existing = combinedRect {
                combinedRect = existing.union(finalFrame)
            } else {
                combinedRect = finalFrame
            }
        }

        return combinedRect
    }

    private func scaledFrame(_ frame: CGRect, mappingSize: CGSize, scale: CGFloat, offset: CGPoint) -> CGRect {
        return CGRect(
            x: (frame.origin.x * scale) + offset.x,
            y: (frame.origin.y * scale) + offset.y,
            width: frame.size.width * scale,
            height: frame.size.height * scale
        )
    }

    private func broadcastFramePosition(_ frame: CGRect, outputFrame: CGRect? = nil, mappingSize: CGSize? = nil, scale: CGFloat? = nil, offset: CGPoint? = nil, screenId: String? = nil) {
        // Only broadcast if we're in the emulator
        if isInEmulator {
            var frameInfo: [String: Any] = [
                "frame": NSValue(cgRect: frame)
            ]

            if let outputFrame = outputFrame {
                frameInfo["outputFrame"] = NSValue(cgRect: outputFrame)
            }

            if let mappingSize = mappingSize {
                frameInfo["mappingSize"] = NSValue(cgSize: mappingSize)
            }

            if let scale = scale {
                frameInfo["scale"] = scale
            }

            if let offset = offset {
                frameInfo["offset"] = NSValue(cgPoint: offset)
            }

            if let screenId = screenId {
                frameInfo["screenId"] = screenId
            }

            // Log the frame being broadcast
            DLOG("Broadcasting screen position frame: \(frame)")

            // Broadcast the frame via NotificationCenter
            NotificationCenter.default.post(
                name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"),
                object: nil,
                userInfo: frameInfo
            )
        }
    }

    @State private var lastBroadcastedSize: CGSize = .zero
    @State private var lastBroadcastedLayout: DeltaSkinView.SkinLayout?
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Only show the color bars if we're not in the emulator
            if !isInEmulator {
                DeltaSkinScreenLayer(
                    skin: skin,
                    traits: traits,
                    filters: filters,
                    size: size,
                    screenAspectRatio: screenAspectRatio
                )
            } else {
                // In emulator mode, we still need to calculate and broadcast the position
                // but we don't actually render anything visible
                Color.clear
                    .onAppear {
                        // Calculate and broadcast the frame on appear
                        lastBroadcastedSize = size
                        lastBroadcastedLayout = layout
                        _ = calculateScreenFrame()
                    }
                    .onChange(of: size) { newSize in
                        // Debounce rapid size changes to prevent flickering
                        guard newSize != lastBroadcastedSize else { return }

                        debounceTask?.cancel()
                        debounceTask = Task {
                            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms debounce
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                lastBroadcastedSize = newSize
                                _ = calculateScreenFrame()
                            }
                        }
                    }
                    .onChange(of: layout) { newLayout in
                        // For layout changes (especially when image loads), update immediately
                        // This ensures viewport is correct on startup
                        guard newLayout != lastBroadcastedLayout else { return }

                        debounceTask?.cancel()
                        // Use shorter debounce for layout changes to ensure timely updates
                        debounceTask = Task {
                            try? await Task.sleep(nanoseconds: 16_666_666) // ~16ms debounce (one frame)
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                lastBroadcastedLayout = newLayout
                                _ = calculateScreenFrame()
                            }
                        }
                    }
            }
        }
    }
}
