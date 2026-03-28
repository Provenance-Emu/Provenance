import SwiftUI
import PVLogging
import PVEmulatorCore
#if canImport(UIKit)
import UIKit
#endif

/// Calculates and broadcasts screen position for skins
struct DeltaSkinScreenPositionWrapper: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let filters: Set<TestPatternEffect>
    let size: CGSize
    let screenAspectRatio: CGFloat?
    let isInEmulator: Bool
    let core: PVEmulatorCore?
    let layout: DeltaSkinView.SkinLayout?

    @Environment(\.skinLayout) var environmentLayout

    /// Calculate screen frame from skin data
    private func calculateScreenFrame() -> CGRect? {
        ILOG("skins: calculateScreenFrame() called - device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue)")
        // Use passed layout parameter first, fallback to environment
        let effectiveLayout = layout ?? environmentLayout
        guard let layout = effectiveLayout,
              let mappingSize = skin.mappingSize(for: traits) else {
            ELOG("skins: ERROR - calculateScreenFrame() failed: layout or mappingSize is nil. layout param: \(self.layout != nil), environment: \(environmentLayout != nil)")
            return nil
        }
        ILOG("skins: calculateScreenFrame() - layout: width=\(layout.width), height=\(layout.height), xOffset=\(layout.xOffset), yOffset=\(layout.yOffset), mappingSize=\(mappingSize)")

        // For default skins, don't calculate here - let calculateDefaultViewport handle it
        // Default skins are identified by "default" identifier prefix or name containing "default"
        // Also check if it's a DefaultDeltaSkin instance
        let isDefaultSkin = skin.identifier.hasPrefix("default-") ||
                           skin.identifier == "default" ||
                           skin.name.lowercased() == "default" ||
                           String(describing: type(of: skin)).contains("DefaultDeltaSkin")
        if isDefaultSkin {
            DLOG("🎮 SKIN: DeltaSkinScreenPositionWrapper - skipping calculation for default skin (\(skin.identifier)), use calculateDefaultViewport instead")
            return nil
        }

        // Check if this is a simple skin (no screens or screenGroups)
        // Simple skins should use button-based calculation even if gameScreenFrame exists
        let screens = skin.screens(for: traits)
        let screenGroups = skin.screenGroups(for: traits)
        let isSimpleSkin = screens == nil && screenGroups == nil
        ILOG("skins: Skin type check - screens: \(screens?.count ?? 0), screenGroups: \(screenGroups?.count ?? 0), isSimpleSkin: \(isSimpleSkin)")

        // Get screen frame from skin (supports multiple formats)
        let screenFrame: CGRect?

        // Try screens array first
        if let screens = skin.screens(for: traits), !screens.isEmpty {
            // Log all available screens for debugging
            ILOG("skins: Found \(screens.count) screens, checking all:")
            for (index, screen) in screens.enumerated() {
                if let frame = screen.outputFrame {
                    let area = frame.width * frame.height
                    ILOG("skins:   Screen \(index) (\(screen.id)): \(frame), area: \(area)")
                } else {
                    ILOG("skins:   Screen \(index) (\(screen.id)): no outputFrame")
                }
            }

            // Find the screen with the smallest area (the actual game screen)
            // Larger screens are typically effect screens (blurred backgrounds), smaller screens are the game screen
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
                } else {
                    ILOG("skins:   Rejecting screen \(screen.id) - too small: \(frame)")
                    return nil
                }
            }

            guard let smallestScreen = validScreens.min(by: { $0.area < $1.area }),
                  let outputFrame = smallestScreen.screen.outputFrame else {
                ELOG("skins: ERROR - No valid screens found after filtering")
                return nil
            }

            ILOG("skins: Using screens array path - selected screen: \(smallestScreen.screen.id), outputFrame: \(outputFrame), area: \(smallestScreen.area), layout: \(layout.width)x\(layout.height)")
            DLOG("🎮 SKIN: Using screens array path")
            DLOG("🎮 SKIN:   outputFrame: \(outputFrame)")
            DLOG("🎮 SKIN:   layout.width: \(layout.width), layout.height: \(layout.height)")

            // outputFrame is stored as decoded from the skin JSON — it may be in pixel
            // coordinates relative to mappingSize (most skins) or in 0–1 normalised space
            // (modern skins where all components are ≤ 1.0).
            // We normalise here using mappingSize whenever any component exceeds 1.0.
            let needsFallbackNorm = outputFrame.origin.x > 1.0 || outputFrame.origin.y > 1.0 ||
                                    outputFrame.width > 1.0 || outputFrame.height > 1.0

            if needsFallbackNorm {
                DLOG("🎮 SKIN: Fallback normalisation applied to outputFrame: \(outputFrame), mappingSize: \(mappingSize)")

                // Normalize - ensure we don't divide by zero
                guard mappingSize.width > 0 && mappingSize.height > 0 else {
                    ELOG("🎮 SKIN: ERROR - Invalid mappingSize for normalisation: \(mappingSize)")
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
                    ELOG("🎮 SKIN: ERROR - Invalid normalized values after fallback: x=\(normalizedX), y=\(normalizedY), w=\(normalizedWidth), h=\(normalizedHeight)")
                    return nil
                }

                var fallbackFrame = CGRect(
                    x: normalizedX * layout.width,
                    y: normalizedY * layout.height,
                    width: normalizedWidth * layout.width,
                    height: normalizedHeight * layout.height
                )

                // Enforce native aspect ratio for pixel-coordinate skins too (e.g. GameGear).
                // Priority: emulator-core AR → per-screen JSON override → system JSON registry → 4:3.
                func resolvedNativeAspectRatio(for skinScreen: DeltaSkinScreen) -> CGFloat {
                    let skinScreenAR: CGFloat? = skinScreen.nativeResolution.flatMap { res in
                        guard res.height > 0, res.width > 0 else { return nil }
                        let ar = res.width / res.height
                        return ar.isFinite ? ar : nil
                    }
                    let candidateAR = screenAspectRatio ?? skinScreenAR ?? DeltaSkinNativeResolution.aspectRatio(for: skin.gameType)
                    let nativeAR = candidateAR.isFinite && candidateAR > 0 ? candidateAR : 4.0 / 3.0
                    return nativeAR
                }

                if smallestScreen.screen.maintainAspectRatio {
                    let nativeAR = resolvedNativeAspectRatio(for: smallestScreen.screen)
                    fallbackFrame = fallbackFrame.fitting(aspectRatio: nativeAR)
                    DLOG("🎮 SKIN: Applied native AR (\(nativeAR)) to fallback-normed frame → \(fallbackFrame)")
                }

                screenFrame = fallbackFrame

                DLOG("🎮 SKIN:   Calculated screenFrame (fallback norm): \(screenFrame)")
                DLOG("🎮 SKIN:   layout.xOffset: \(layout.xOffset), layout.yOffset: \(layout.yOffset)")
            } else {
                // outputFrame is normalised (0–1); scale directly by layout dimensions.
                DLOG("🎮 SKIN: Treating outputFrame as normalised: \(outputFrame)")
                var scaledFrame = CGRect(
                    x: outputFrame.minX * layout.width,
                    y: outputFrame.minY * layout.height,
                    width: outputFrame.width * layout.width,
                    height: outputFrame.height * layout.height
                )

                // Enforce native aspect ratio for systems that require it (e.g. GameGear 10:9).
                // Priority: emulator-core AR → per-screen JSON override → system JSON registry → 4:3.
                if smallestScreen.screen.maintainAspectRatio {
                    let skinScreenAR: CGFloat? = smallestScreen.screen.nativeResolution.flatMap { res in
                        guard res.height > 0, res.width > 0 else { return nil }
                        let ar = res.width / res.height
                        return ar.isFinite ? ar : nil
                    }
                    let candidateAR = screenAspectRatio ?? skinScreenAR ?? DeltaSkinNativeResolution.aspectRatio(for: skin.gameType)
                    let nativeAR = candidateAR.isFinite && candidateAR > 0 ? candidateAR : 4.0 / 3.0
                    scaledFrame = scaledFrame.fitting(aspectRatio: nativeAR)
                    DLOG("🎮 SKIN: Applied native AR (\(nativeAR)) enforcement → \(scaledFrame)")
                }

                screenFrame = scaledFrame
                DLOG("🎮 SKIN:   Calculated screenFrame (normalised): \(screenFrame)")
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

            // Normalise using mappingSize whenever any component exceeds 1.0.
            let needsFallbackNorm = outputFrame.origin.x > 1.0 || outputFrame.origin.y > 1.0 ||
                                    outputFrame.width > 1.0 || outputFrame.height > 1.0

            if needsFallbackNorm {
                DLOG("🎮 SKIN: Fallback normalisation applied to screenGroups outputFrame: \(outputFrame), mappingSize: \(mappingSize)")

                // Validate mappingSize and layout before dividing — zero mappingSize produces inf/NaN.
                guard mappingSize.width > 0 && mappingSize.height > 0 else {
                    ELOG("🎮 SKIN: ERROR - Invalid mappingSize for screenGroups normalisation: \(mappingSize)")
                    return nil
                }
                guard layout.width > 0 && layout.height > 0 else {
                    ELOG("🎮 SKIN: ERROR - Invalid layout dimensions for screenGroups: width=\(layout.width), height=\(layout.height)")
                    return nil
                }

                let normalizedX = outputFrame.minX / mappingSize.width
                let normalizedY = outputFrame.minY / mappingSize.height
                let normalizedWidth = outputFrame.width / mappingSize.width
                let normalizedHeight = outputFrame.height / mappingSize.height

                DLOG("🎮 SKIN:   Normalized: x=\(normalizedX), y=\(normalizedY), w=\(normalizedWidth), h=\(normalizedHeight)")

                // Validate normalised values — inf/NaN can occur if mappingSize had a zero component.
                guard normalizedX.isFinite && normalizedY.isFinite &&
                      normalizedWidth.isFinite && normalizedHeight.isFinite else {
                    ELOG("🎮 SKIN: ERROR - Invalid normalized values after screenGroups fallback: x=\(normalizedX), y=\(normalizedY), w=\(normalizedWidth), h=\(normalizedHeight)")
                    return nil
                }

                var groupFallbackFrame = CGRect(
                    x: normalizedX * layout.width,
                    y: normalizedY * layout.height,
                    width: normalizedWidth * layout.width,
                    height: normalizedHeight * layout.height
                )

                // Enforce native aspect ratio for pixel-coordinate screen groups too.
                // Priority: emulator-core AR → per-screen JSON override → system JSON registry → 4:3.
                if screen.maintainAspectRatio {
                    let skinScreenAR: CGFloat? = screen.nativeResolution.flatMap { res in
                        guard res.height > 0, res.width > 0 else { return nil }
                        let ar = res.width / res.height
                        return ar.isFinite ? ar : nil
                    }
                    let candidateAR = screenAspectRatio ?? skinScreenAR ?? DeltaSkinNativeResolution.aspectRatio(for: skin.gameType)
                    let nativeAR = candidateAR.isFinite && candidateAR > 0 ? candidateAR : 4.0 / 3.0
                    groupFallbackFrame = groupFallbackFrame.fitting(aspectRatio: nativeAR)
                    DLOG("🎮 SKIN: Applied native AR (\(nativeAR)) to screen group fallback → \(groupFallbackFrame)")
                }

                screenFrame = groupFallbackFrame

                DLOG("🎮 SKIN:   Calculated screenFrame (screen groups fallback): \(screenFrame)")
            } else {
                var scaledFrame = CGRect(
                    x: outputFrame.minX * layout.width,
                    y: outputFrame.minY * layout.height,
                    width: outputFrame.width * layout.width,
                    height: outputFrame.height * layout.height
                )

                // Enforce native aspect ratio when requested.
                // Priority: emulator-core AR → per-screen JSON override → system JSON registry → 4:3.
                if screen.maintainAspectRatio {
                    let skinScreenAR: CGFloat? = screen.nativeResolution.flatMap { res in
                        guard res.height > 0, res.width > 0 else { return nil }
                        let ar = res.width / res.height
                        return ar.isFinite ? ar : nil
                    }
                    let candidateAR = screenAspectRatio ?? skinScreenAR ?? DeltaSkinNativeResolution.aspectRatio(for: skin.gameType)
                    let nativeAR = candidateAR.isFinite && candidateAR > 0 ? candidateAR : 4.0 / 3.0
                    scaledFrame = scaledFrame.fitting(aspectRatio: nativeAR)
                    DLOG("🎮 SKIN: Applied native AR (\(nativeAR)) to screen group → \(scaledFrame)")
                }

                screenFrame = scaledFrame
            }
        }
        // Try gameScreenFrame dictionary — used by legacy skins (VB, GameGear, etc.) that define
        // the game screen position explicitly without a modern "screens" array.  Previously this
        // was skipped for simple skins, but that caused incorrect game screen placement for legacy
        // skins that only carry gameScreenFrame with no screens/screenGroups.
        else if let gameScreenFrame = getGameScreenFrame(traits: traits) {
            DLOG("🎮 SKIN: Found gameScreenFrame (isSimpleSkin=\(isSimpleSkin)): \(gameScreenFrame)")
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
        // Default: calculate from buttons - for simple skins, use area above topmost button
        // For landscape, use center area with reasonable size instead of tiny area above buttons
        else if let buttons = skin.buttons(for: traits),
                  let topButton = buttons.min(by: { $0.frame.minY < $1.frame.minY }) {
            DLOG("🎮 SKIN: Using button-based calculation (simple skin: \(isSimpleSkin))")
            let aspectRatio = screenAspectRatio ?? (4.0/3.0)
            let isLandscape = traits.orientation == .landscape

            // Convert top button's frame from mapping coordinates to screen coordinates
            // Button frames can be normalized (0-1) or absolute pixels relative to mappingSize
            let buttonFrame = topButton.frame
            let isNormalized = buttonFrame.width <= 1.0 && buttonFrame.height <= 1.0

            let normalizedButtonY: CGFloat
            if isNormalized {
                // Already normalized
                normalizedButtonY = buttonFrame.minY
            } else {
                // Absolute pixels - normalize by mappingSize
                normalizedButtonY = buttonFrame.minY / mappingSize.height
            }

            // Calculate button's top edge in layout coordinates (before adding layout offset)
            // This is relative to the layout's coordinate system
            let buttonTopInLayout = normalizedButtonY * layout.height

            // Get safe area top inset
            #if os(iOS)
            let safeAreaTop: CGFloat = {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    return window.safeAreaInsets.top
                }
                return 0
            }()
            #else
            let safeAreaTop: CGFloat = 0
            #endif

            // Calculate available height: from safe area top to button top (in view coordinates)
            // buttonTopInLayout is relative to layout, layout.yOffset positions the layout in the view
            let buttonTopInView = layout.yOffset + buttonTopInLayout
            let availableHeight = max(0, buttonTopInView - safeAreaTop)

            // For landscape, if available height is too small (buttons near top), use center area instead
            // Minimum reasonable screen height: at least 20% of view height, or 100 pixels
            let minScreenHeight = max(size.height * 0.2, 100.0)
            let useCenterArea = isLandscape && availableHeight < minScreenHeight

            let constrainedWidth: CGFloat
            let constrainedHeight: CGFloat
            let finalScreenX: CGFloat
            let finalScreenY: CGFloat

            if useCenterArea {
                // For landscape with buttons near top, use center area with reasonable size
                // Calculate based on width first (landscape is wider), then constrain by height
                let preferredWidth = size.width * 0.8
                let preferredHeight = preferredWidth / aspectRatio

                // Ensure it fits in height (70% of available height)
                let maxHeight = (size.height - safeAreaTop) * 0.7
                if preferredHeight > maxHeight {
                    constrainedHeight = maxHeight
                    constrainedWidth = maxHeight * aspectRatio
                } else {
                    constrainedWidth = preferredWidth
                    constrainedHeight = preferredHeight
                }

                // Center both horizontally and vertically
                finalScreenX = (size.width - constrainedWidth) / 2
                finalScreenY = safeAreaTop + (size.height - safeAreaTop) / 2 - constrainedHeight / 2
                DLOG("🎮 SKIN: Landscape with buttons near top - using center area, width: \(constrainedWidth), height: \(constrainedHeight)")
            } else {
                // Portrait or landscape with buttons lower - use area above buttons
                let screenHeight = min(availableHeight, size.height * 0.8)
                let screenWidth = screenHeight * aspectRatio

                // Ensure screen fits within available width
                constrainedWidth = min(screenWidth, size.width * 0.9)
                constrainedHeight = constrainedWidth / aspectRatio

                // Center horizontally, position above buttons
                finalScreenX = (size.width - constrainedWidth) / 2
                finalScreenY = safeAreaTop + max(0, (availableHeight - constrainedHeight) / 2)
            }

            // Calculate screenFrame relative to layout (will have layout offset added later)
            // Convert from view coordinates to layout coordinates
            screenFrame = CGRect(
                x: finalScreenX - layout.xOffset,
                y: finalScreenY - layout.yOffset,
                width: constrainedWidth,
                height: constrainedHeight
            )

            DLOG("🎮 SKIN: Calculated screen frame from top button - buttonTopInLayout: \(buttonTopInLayout), buttonTopInView: \(buttonTopInView), safeAreaTop: \(safeAreaTop), availableHeight: \(availableHeight), useCenterArea: \(useCenterArea), screenFrame (layout coords): \(screenFrame)")
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

        // The skin is positioned using .position(), which sets the CENTER point
        // For all cases, the center is at (layout.xOffset + width/2, layout.yOffset + height/2)
        // So the top-left corner is at (layout.xOffset, layout.yOffset)
        let finalFrame = CGRect(
            x: layout.xOffset + screenFrame.minX,
            y: layout.yOffset + screenFrame.minY,
            width: screenFrame.width,
            height: screenFrame.height
        )

        DLOG("🎮 SKIN: Frame calculation - layout.yOffset=\(layout.yOffset), screenFrame.minY=\(screenFrame.minY), finalFrame.y=\(finalFrame.minY)")

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
        ILOG("skins: Broadcasting final frame: \(finalFrame) - device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue)")
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

    /// Broadcast frame to emulator controller via protocol (replaces notification system)
    private func broadcastFrame(_ frame: CGRect) {
        guard isInEmulator else { return }

        // Never broadcast frames for default skins - they use calculateDefaultViewport instead
        let isDefaultSkin = skin.identifier.hasPrefix("default-") ||
                           skin.identifier == "default" ||
                           skin.name.lowercased() == "default" ||
                           String(describing: type(of: skin)).contains("DefaultDeltaSkin")
        if isDefaultSkin {
            DLOG("🎮 SKIN: DeltaSkinScreenPositionWrapper - skipping broadcast for default skin (\(skin.identifier)), use calculateDefaultViewport instead")
            return
        }

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
        ILOG("skins: Broadcasting frame via protocol: \(frame) - device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue)")
        DLOG("🎮 SKIN: Broadcasting frame via protocol: \(frame)")

        // Use protocol-based system instead of notifications
        core?.viewportLayoutDelegate?.viewportFrameDidUpdate(frame)
    }

    @State private var lastSize: CGSize = .zero
    @State private var lastLayout: DeltaSkinView.SkinLayout?
    @State private var lastBroadcastFrame: CGRect?

    var body: some View {
        Color.clear
            .onAppear {
                let effectiveLayout = layout ?? environmentLayout
                ILOG("🎮 SKIN: DeltaSkinScreenPositionWrapper.onAppear - size=\(size), layout param=\(String(describing: layout)), environment=\(String(describing: environmentLayout)), effective=\(String(describing: effectiveLayout))")
                lastSize = size
                lastLayout = effectiveLayout
                // Calculate immediately on appear - use same code path as initial startup
                calculateScreenFrameImmediate()
            }
            .onChange(of: size) { newSize in
                // Only recalculate if size actually changed significantly (more than 1 point)
                guard abs(newSize.width - lastSize.width) > 1.0 || abs(newSize.height - lastSize.height) > 1.0 else { return }

                // Clear last broadcast frame when size changes (orientation change)
                // This ensures the frame is broadcast even if it has the same value
                lastBroadcastFrame = nil
                lastSize = newSize

                // Use same immediate calculation path as startup - no debouncing
                // This ensures consistent frame calculation after rotation
                calculateScreenFrameImmediate()
            }
            .onChange(of: layout) { newLayout in
                // Only recalculate if layout actually changed (using Equatable check)
                guard newLayout != lastLayout else { return }

                // Clear last broadcast frame when layout changes (orientation change)
                // This ensures the frame is broadcast even if it has the same value
                lastBroadcastFrame = nil
                lastLayout = newLayout

                // Use same immediate calculation path as startup
                // Only calculate if layout is valid (same check as onAppear)
                let effectiveLayout = newLayout ?? environmentLayout
                if (effectiveLayout?.width ?? 0) > 0 && (effectiveLayout?.height ?? 0) > 0 && size.width > 0 && size.height > 0 {
                    calculateScreenFrameImmediate()
                }
            }
            .onChange(of: environmentLayout) { newLayout in
                // Also watch environment layout changes
                guard newLayout != lastLayout else { return }
                lastBroadcastFrame = nil
                lastLayout = newLayout
                let effectiveLayout = layout ?? newLayout
                if (effectiveLayout?.width ?? 0) > 0 && (effectiveLayout?.height ?? 0) > 0 && size.width > 0 && size.height > 0 {
                    calculateScreenFrameImmediate()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeltaSkinForceRecalculate"))) { _ in
                // Force recalculation when requested - use same immediate path
                DLOG("🎮 SKIN: Forcing frame recalculation after rotation")
                // Clear last broadcast frame to ensure frame is broadcast even if value is same
                lastBroadcastFrame = nil
                calculateScreenFrameImmediate()
            }
    }

    /// Calculate screen frame using the same immediate logic as initial startup
    /// This ensures consistent behavior after rotation - same code path, no debouncing
    private func calculateScreenFrameImmediate() {
        // Use the same calculation logic as onAppear - immediate, no debouncing
        // This is the single, consistent calculation path for all skins
        _ = calculateScreenFrame()
    }
}
