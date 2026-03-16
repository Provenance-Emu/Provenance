
//
//  EmulatorWithSkinView+DefaultSkin.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/28/25.
//

import SwiftUI
import Foundation
import PVEmulatorCore
import PVSystems
import PVRealm
import RealmSwift
import PVLibrary
import PVPlists
import PVThemes
import PVLogging
import PVUIBase
import PVSettings

// MARK: - Retrowave Styling Components

/// Retrowave background with grid and sun
struct RetrowaveBackground: View {
    var body: some View {
        ZStack {
            // Deep blue/purple background
            Color(red: 0.05, green: 0.0, blue: 0.15, opacity: 0.9)
                .edgesIgnoringSafeArea(.all)

            // Grid with perspective effect
            RetrowaveGrid()
                .opacity(0.35)

            // Sun glow effect
            RetrowaveSun()
                .opacity(0.25)
        }
    }
}

/// Retrowave grid with perspective effect
struct RetrowaveGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let horizonY = height * 0.6
                let centerX = width / 2

                // Horizontal grid lines
                for i in 0..<20 {
                    let y = horizonY + CGFloat(i) * CGFloat(i) * 2.0
                    if y < height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }

                // Vertical grid lines with perspective
                for i in 0..<20 {
                    let spacing = width / 20
                    let x = centerX + spacing * CGFloat(i)
                    if x < width {
                        path.move(to: CGPoint(x: x, y: horizonY))
                        path.addLine(to: CGPoint(x: width, y: height))
                    }

                    let x2 = centerX - spacing * CGFloat(i)
                    if x2 > 0 {
                        path.move(to: CGPoint(x: x2, y: horizonY))
                        path.addLine(to: CGPoint(x: 0, y: height))
                    }
                }
            }
            .stroke(Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.3), lineWidth: 1)
        }
    }
}

/// Retrowave sun effect
struct RetrowaveSun: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let horizonY = height * 0.6

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.7),
                            Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: width * 0.4
                    )
                )
                .frame(width: width * 0.8, height: width * 0.8)
                .position(x: width / 2, y: horizonY)
                .blur(radius: 20)
        }
    }
}

/// Neon text style for buttons
struct NeonText: View {
    let text: String
    let color: Color
    let fontSize: CGFloat

    init(_ text: String, color: Color = Color(red: 0.99, green: 0.11, blue: 0.55), fontSize: CGFloat = 14) {
        self.text = text
        self.color = color
        self.fontSize = fontSize
    }

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: color, radius: 2, x: 0, y: 0)
            .shadow(color: color, radius: 4, x: 0, y: 0)
    }
}

// MARK: - Default Controller
extension EmulatorWithSkinView {

    /// Create a default skin for a system
    /// - Parameter systemId: The system identifier
    /// - Returns: A default skin for the system
    public static func defaultSkin(for systemId: SystemIdentifier) -> DeltaSkinProtocol {
        return DefaultDeltaSkin(systemId: systemId)
    }

    /// Default controller skin as a fallback
    internal func defaultControllerSkin() -> some View {
        // Use a local state variable for the joystick toggle since we can't mutate self
        return DefaultControllerSkinView(
            useJoystick: useJoystick,
            inputHandler: inputHandler,
            systemId: systemId,
            coreInstance: coreInstance
        )
    }
}

// Separate view to handle the default controller skin with its own state
struct DefaultControllerSkinView: View {
    // Initial value from parent
    @State private var useJoystickInternal: Bool
    let inputHandler: DeltaSkinInputHandler
    let systemId: SystemIdentifier?
    let coreInstance: PVEmulatorCore
    @State private var lastBroadcastedViewport: CGRect?
    @State private var currentSafeInsets: EdgeInsets = EdgeInsets()

    // Access theme manager for colors
    @ObservedObject private var themeManager = ThemeManager.shared

    // State for control layout data
    @State private var controlLayout: [ControlLayoutEntry]? = nil

    // State for num pad flip view
    @State private var showNumPad = false

    // D-pad state - must be StateObject to persist across renders
    @StateObject private var dpadState = DPadState()

    // Cache the validated aspect ratio - cleared when needed to ensure fresh calculation
    @State private var cachedAspectRatio: CGFloat?
    @State private var lastAspectSize: CGSize = .zero

    // Bridge to protocol system (replaces notification system)
    @State private var viewportBridge: ViewportLayoutProviderBridge?

    init(useJoystick: Bool, inputHandler: DeltaSkinInputHandler, systemId: SystemIdentifier?, coreInstance: PVEmulatorCore) {
        self._useJoystickInternal = State(initialValue: useJoystick)
        self.inputHandler = inputHandler
        self.systemId = systemId
        self.coreInstance = coreInstance
    }

    var body: some View {
        // Load control layout data when view appears
        GeometryReader { geometry in
            // Guard against invalid geometry that could cause the view to disappear
            let validSize = geometry.size.width > 0 && geometry.size.height > 0
            let isLandscape = validSize && geometry.size.width > geometry.size.height

            ZStack {
                // Ensure view always renders even with invalid geometry
                if validSize {
                    // Only show background in portrait mode with a gradual fade
                    // Background should only appear in the controller area (bottom ~35%)
                    if !isLandscape {
                        // Portrait mode - show background only in bottom controller area
                        VStack(spacing: 0) {
                            // Spacer for screen area (top ~65%) - no background here
                            Spacer()
                                .frame(maxHeight: geometry.size.height * 0.65)

                            // Controller area background with gradual fade
                            ZStack {
                                // Retrowave background
                                RetrowaveBackground()
                                // Apply a gradient mask for smooth fade from transparent to visible
                                // Start fade at the top of controller area (screen edge)
                                    .mask(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: .clear, location: 0.0),   // Fully transparent at top (screen edge)
                                                .init(color: .clear, location: 0.2),   // Still transparent at 20%
                                                .init(color: .white, location: 0.5)    // Fully visible at 50% of controller area
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            .frame(maxHeight: geometry.size.height * 0.35)
                            .clipped()
                        }
                    }

                    if isLandscape {
                        // Landscape layout - controls positioned at edges with safe area awareness
                        dynamicLandscapeControllerSkin
                            .onAppear {
                                loadControlLayoutData()
                                // Ensure input handler has the core set
                                inputHandler.setEmulatorCore(coreInstance)
                            }
                            .edgesIgnoringSafeArea([]) // Respect safe areas for notch
                    } else {
                        // Portrait layout - controls constrained to bottom area
                        // Screen area is typically top ~65%, controller area is bottom ~35%
                        VStack(spacing: 0) {
                            // Spacer to push controller to bottom area (top ~65% is screen area)
                            Spacer()
                                .frame(maxHeight: geometry.size.height * 0.65)

                            // Controller area - constrained to bottom portion
                            dynamicControllerSkin
                                .frame(maxHeight: geometry.size.height * 0.35)
                                .clipped()
                                .onAppear {
                                    loadControlLayoutData()
                                    // Ensure input handler has the core set
                                    inputHandler.setEmulatorCore(coreInstance)
                                }
                        }
                    }
                } else {
                    // Fallback: Show a minimal view when geometry is invalid to prevent disappearing
                    // This ensures the view hierarchy stays intact
                    Color.clear
                        .frame(width: 1, height: 1)
                }

                // Virtual input quick-toggle buttons (keyboard / mouse) — top-leading corner.
                // Only visible when the active core supports keyboard or mouse input.
                // Not available on tvOS (virtual keyboard/mouse overlays are iOS-only).
                #if !os(tvOS)
                if validSize {
                    VStack {
                        HStack {
                            VirtualInputToggleOverlayView()
                                .padding(.top, geometry.safeAreaInsets.top + 8)
                                .padding(.leading, geometry.safeAreaInsets.leading + 8)
                            Spacer()
                        }
                        Spacer()
                    }
                    .allowsHitTesting(true)
                }
                #endif
            }
            .id("DefaultControllerSkinView-\(validSize ? "valid" : "invalid")") // Stable ID to prevent unnecessary recreation
            .onAppear {
                // Ensure input handler has the core set when view appears
                inputHandler.setEmulatorCore(coreInstance)
                // Store safe area insets only if geometry is valid
                if validSize {
                    currentSafeInsets = geometry.safeAreaInsets

                    // Set up protocol bridge for viewport layout
                    setupViewportBridge()

                    // Emit default viewport on appear
                    emitDefaultViewportIfNeeded(
                        size: geometry.size,
                        safeInsets: geometry.safeAreaInsets,
                        isLandscape: isLandscape
                    )
                }
            }
            .onDisappear {
                // Clean up bridge when view disappears
                viewportBridge = nil
                coreInstance.viewportLayoutProvider = nil
            }
            .background(
                Group {
                    if validSize {
                        ViewportUpdater(
                            size: geometry.size,
                            safeInsets: geometry.safeAreaInsets,
                            onUpdate: { size, insets, isLandscape in
                                // Always update safe insets
                                currentSafeInsets = insets
                                // Always emit viewport - ViewportUpdater handles deduplication
                                emitDefaultViewportIfNeeded(
                                    size: size,
                                    safeInsets: insets,
                                    isLandscape: isLandscape
                                )
                            }
                        )
                        .frame(width: 1, height: 1)
                        .allowsHitTesting(false)
                    } else {
                        Color.clear
                            .frame(width: 1, height: 1)
                    }
                }
            )
        }
    }

    // Landscape-specific layout with controls positioned correctly
    private var landscapeControllerLayout: some View {
        GeometryReader { geometry in
            ZStack {
                // Top row with shoulder buttons, menu and turbo buttons
                VStack {
                    HStack {
                        // Left shoulder buttons (L2 on outer/left edge)
                        HStack(spacing: 15) {
                            shoulderButton(label: "L2", color: .gray)
                            shoulderButton(label: "L", color: .gray)
                            shoulderButton(label: "L3", color: .gray)
                        }
                        .padding(.leading, 20)

                        Spacer()

                        // Menu and Turbo buttons in center
                        HStack(spacing: 20) {
                            utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                            utilityButton(label: "TURBO", color: .orange, systemImage: "forward.fill")
                        }

                        Spacer()

                        // Right shoulder buttons (R2 on outer/right edge)
                        HStack(spacing: 15) {
                            shoulderButton(label: "R3", color: .gray)
                            shoulderButton(label: "R", color: .gray)
                            shoulderButton(label: "R2", color: .gray)
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 20)

                    Spacer()

                    // Start/Select buttons at the center bottom
                    HStack {
                        Spacer()
                        HStack(spacing: 30) {
                            pillButton(label: "SELECT", color: .black)
                            pillButton(label: "START", color: .black)
                        }
                        .padding(.bottom, 20)
                        Spacer()
                    }
                }
            }

            // D-pad on the left side
            VStack {
                Spacer()
                if useJoystickInternal {
                    joystickView()
                } else {
                    dPadView()
                }
                Spacer()
            }
            .frame(width: 150)
            .padding(.leading, 80)
            .position(x: 150, y: geometry.size.height / 2)

            // Action buttons on the right side
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    let cachedFps = fpsButtonConfig
                    HStack(spacing: 30) {
                        if let fps = cachedFps {
                            VStack(spacing: 25) {
                                circleButton(label: fps.tl.0, color: fps.tl.2, inputId: fps.tl.1)
                                circleButton(label: fps.bl.0, color: fps.bl.2, inputId: fps.bl.1)
                            }
                            VStack(spacing: 25) {
                                circleButton(label: fps.tr.0, color: fps.tr.2, inputId: fps.tr.1)
                                circleButton(label: fps.br.0, color: fps.br.2, inputId: fps.br.1)
                            }
                        } else {
                            VStack(spacing: 25) {
                                circleButton(label: "Y", color: .yellow)
                                circleButton(label: "X", color: .blue)
                            }
                            VStack(spacing: 25) {
                                circleButton(label: "B", color: .red)
                                circleButton(label: "A", color: .green)
                            }
                        }
                    }
                    if let fps = cachedFps, let center = fps.center {
                        circleButton(label: center.0, color: center.2, inputId: center.1)
                    }
                }
                Spacer()
            }
            .frame(width: 150)
            .position(x: geometry.size.width - 150, y: geometry.size.height / 2)
        }
    }

    // Get the screen size based on the core's aspect size
    private func getScreenSize() -> CGSize {
        // Use the core's aspectSize property
        return coreInstance.aspectSize
    }

    /// Set up the viewport layout bridge to use protocol instead of notifications
    private func setupViewportBridge() {
        guard viewportBridge == nil else { return }

        viewportBridge = ViewportLayoutProviderBridge(
            core: coreInstance,
            calculateFrame: { size, insets, isLandscape in
                // Convert UIEdgeInsets to EdgeInsets
                let edgeInsets = EdgeInsets(
                    top: insets.top,
                    leading: insets.left,
                    bottom: insets.bottom,
                    trailing: insets.right
                )
                return self.calculateDefaultViewport(size: size, safeInsets: edgeInsets, isLandscape: isLandscape)
            },
            requestRecalculation: {
                // Recalculation will be triggered by ViewportUpdater
            }
        )
    }

    /// Broadcast a deterministic viewport for the default skin
    /// Single, consistent calculation path - always calculates and broadcasts immediately
    /// Uses same code path for bootup and rotation - no special handling
    /// Now uses protocol instead of notifications
    private func emitDefaultViewportIfNeeded(size: CGSize, safeInsets: EdgeInsets, isLandscape: Bool) {
        // Always calculate frame using current size, safeInsets, and orientation
        // This is the single source of truth for default skin frame calculation
        // No caching or special rotation handling - same as bootup
        let frame = calculateDefaultViewport(size: size, safeInsets: safeInsets, isLandscape: isLandscape)
        guard frame.width > 0,
              frame.height > 0,
              frame.width.isFinite,
              frame.height.isFinite,
              frame.origin.x.isFinite,
              frame.origin.y.isFinite else {
            ILOG("🎮 SKIN: Invalid frame calculated, skipping broadcast")
            return
        }

        // Always broadcast - don't skip based on previous frame
        // This ensures fresh frame on every calculation (bootup and rotation)
        lastBroadcastedViewport = frame

        // Use protocol bridge if available (preferred), fallback to notification for compatibility
        if let bridge = viewportBridge {
            bridge.notifyFrameUpdated(frame)
            ILOG("🎮 SKIN: Default skin broadcasting frame via protocol: \(frame)")
        } else {
            // Fallback to notification for backward compatibility
            NotificationCenter.default.post(
                name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"),
                object: nil,
                userInfo: ["frame": NSValue(cgRect: frame)]
            )
            ILOG("🎮 SKIN: Default skin broadcasting frame via notification: \(frame)")
        }
    }

    /// Calculate and validate aspect ratio from core
    /// Always calculates fresh - aspect ratio is a property of the game/core, not device orientation
    private func getValidatedAspectRatio() -> CGFloat {
        let aspectSize = coreInstance.aspectSize

        // Check if aspectSize has changed significantly (more than 10% difference)
        // Only reuse cache if aspectSize hasn't changed
        let sizeChanged = cachedAspectRatio == nil ||
                         (lastAspectSize.width > 0 && lastAspectSize.height > 0 &&
                          (abs(aspectSize.width - lastAspectSize.width) > lastAspectSize.width * 0.1 ||
                           abs(aspectSize.height - lastAspectSize.height) > lastAspectSize.height * 0.1))

        // If we have a cached ratio and size hasn't changed, reuse it
        if let cached = cachedAspectRatio, !sizeChanged {
            return cached
        }

        // Recalculate aspect ratio
        var aspectWidth = aspectSize.width > 0 ? aspectSize.width : 4.0
        var aspectHeight = aspectSize.height > 0 ? aspectSize.height : 3.0

        ILOG("🎮 SKIN: Calculating aspect ratio - aspectSize: width=\(aspectWidth), height=\(aspectHeight)")

        /// Calculate aspect ratio - ensure it's reasonable (most games are 4:3 or 16:9)
        var aspectRatio = aspectWidth / max(0.01, aspectHeight)

        /// Check if aspectSize looks like screen dimensions instead of game aspect ratio
        /// Screen dimensions are typically much larger (e.g., 440x956), while aspect ratios are small numbers (e.g., 4:3)
        let looksLikeScreenSize = aspectWidth > 100 || aspectHeight > 100

        /// Most games have aspect ratios between 1.0 (square) and 2.0 (ultrawide)
        /// If aspect ratio is outside reasonable bounds OR looks like screen dimensions, fix it
        if looksLikeScreenSize || aspectRatio < 0.5 || aspectRatio > 2.0 {
            if looksLikeScreenSize {
                ILOG("🎮 SKIN: aspectSize looks like screen dimensions (\(aspectWidth)x\(aspectHeight)), using default 4:3 aspect ratio")
                /// If aspectSize is returning screen dimensions, we can't derive the game's aspect ratio from it
                /// Default to 4:3 for most retro games (N64, SNES, etc.)
                aspectRatio = 4.0 / 3.0
            } else {
                /// Try inverted: swap width and height
                let invertedRatio = aspectHeight / max(0.01, aspectWidth)
                if invertedRatio >= 0.5 && invertedRatio <= 2.0 {
                    aspectRatio = invertedRatio
                    ILOG("🎮 SKIN: Aspect ratio was inverted, using corrected ratio: \(aspectRatio) (was \(aspectWidth)/\(aspectHeight) = \(aspectWidth / max(0.01, aspectHeight)))")
                } else {
                    /// Fallback to 4:3 if both are unreasonable
                    aspectRatio = 4.0 / 3.0
                    ILOG("🎮 SKIN: Aspect ratio out of bounds, using default 4:3 (was \(aspectWidth)/\(aspectHeight) = \(aspectWidth / max(0.01, aspectHeight)))")
                }
            }
        }

        // Cache the validated aspect ratio and the aspectSize used to calculate it
        cachedAspectRatio = aspectRatio
        lastAspectSize = aspectSize

        ILOG("🎮 SKIN: Cached aspect ratio: \(aspectRatio) (from aspectSize: \(aspectSize))")

        return aspectRatio
    }

    /// Calculate viewport used when no explicit skin is available
    /// Same calculation for bootup and rotation - no special handling
    private func calculateDefaultViewport(size: CGSize, safeInsets: EdgeInsets, isLandscape: Bool) -> CGRect {
        // Get aspect ratio (cached if aspectSize hasn't changed, otherwise recalculated)
        let aspectRatio = getValidatedAspectRatio()

        // Check if native scale is enabled
        let nativeScaleEnabled = Defaults[.nativeScaleEnabled]

        let horizontalSafe = safeInsets.leading + safeInsets.trailing
        let verticalSafe = safeInsets.top + safeInsets.bottom
        let safeWidth = max(0, size.width - horizontalSafe)
        let safeHeight = max(0, size.height - verticalSafe)

        guard safeWidth > 0, safeHeight > 0 else {
            ILOG("🎮 SKIN: Default viewport calculation failed - invalid safe area: size=\(size), safeInsets=\(safeInsets)")
            return .zero
        }

        let frame: CGRect
        if isLandscape {
            if nativeScaleEnabled {
                /// Native scale: Reserve space for controls on each edge, fit within available space
                let sideReserve = max(180, min(240, safeWidth * 0.25))
                let availableWidth = max(0, safeWidth - (sideReserve * 2))
                var width = availableWidth
                var height = width / aspectRatio

                /// If height exceeds available space, fit to height instead
                if height > safeHeight {
                    height = safeHeight
                    width = height * aspectRatio
                }

                /// Center horizontally and vertically
                let originX = safeInsets.leading + (safeWidth - width) / 2
                let originY = safeInsets.top + (safeHeight - height) / 2
                frame = CGRect(x: originX, y: originY, width: width, height: height)
                ILOG("🎮 SKIN: Default viewport (landscape, native scale): size=\(size), aspectRatio=\(aspectRatio), safeWidth=\(safeWidth), safeHeight=\(safeHeight), availableWidth=\(availableWidth), frame=\(frame)")
            } else {
                /// Fullscreen scale: Use more of the available screen space, minimal control reserve
                let sideReserve = max(120, min(160, safeWidth * 0.15))
                let availableWidth = max(0, safeWidth - (sideReserve * 2))

                /// Scale to fill available width/height more aggressively
                var width = availableWidth
                var height = width / aspectRatio

                /// If height exceeds available space, fit to height and scale width accordingly
                if height > safeHeight {
                    height = safeHeight
                    width = height * aspectRatio
                } else {
                    /// If we have extra height, scale up to use more of it
                    let maxHeight = safeHeight
                    if height < maxHeight {
                        height = maxHeight
                        width = height * aspectRatio
                        /// Ensure width doesn't exceed available space
                        if width > availableWidth {
                            width = availableWidth
                            height = width / aspectRatio
                        }
                    }
                }

                /// Center horizontally and vertically
                let originX = safeInsets.leading + (safeWidth - width) / 2
                let originY = safeInsets.top + (safeHeight - height) / 2
                frame = CGRect(x: originX, y: originY, width: width, height: height)
                ILOG("🎮 SKIN: Default viewport (landscape, fullscreen scale): size=\(size), aspectRatio=\(aspectRatio), safeWidth=\(safeWidth), safeHeight=\(safeHeight), availableWidth=\(availableWidth), frame=\(frame)")
            }
        } else {
            /// Keep the screen in the upper portion, leaving room for controls
            /// Reserve 35% for controller area, with some margin
            let controllerHeight = safeHeight * 0.35
            /// Ensure minimum top safe area to avoid notch (at least 44pt for status bar/notch area)
            let minTopSafeArea: CGFloat = 44
            let effectiveTopSafeArea = max(safeInsets.top, minTopSafeArea)
            let topMargin: CGFloat = 12
            let bottomMargin: CGFloat = 8
            let availableHeight = max(0, safeHeight - controllerHeight - topMargin - bottomMargin)
            let horizontalMargin: CGFloat = nativeScaleEnabled ? 12 : 8
            let maxWidth = safeWidth - (horizontalMargin * 2)

            if nativeScaleEnabled {
                /// Native scale: Fit game to available space while maintaining aspect ratio
                /// Try fitting to width first
                var width = maxWidth
                var height = width / aspectRatio

                /// If height exceeds available space, fit to height instead
                if height > availableHeight {
                    height = availableHeight
                    width = height * aspectRatio
                }

                /// Calculate the game screen area bounds
                /// Use effectiveTopSafeArea to ensure we don't go under the notch
                let gameAreaTop = effectiveTopSafeArea + topMargin
                let gameAreaBottom = safeInsets.top + safeHeight - controllerHeight - bottomMargin
                let gameAreaHeight = gameAreaBottom - gameAreaTop

                /// Ensure frame fits within game area
                if height > gameAreaHeight {
                    height = gameAreaHeight
                    width = height * aspectRatio
                }

                /// Center horizontally and vertically in the game screen area
                let originX = safeInsets.leading + (safeWidth - width) / 2
                let originY = gameAreaTop + (gameAreaHeight - height) / 2

                frame = CGRect(x: originX, y: originY, width: width, height: height)
                ILOG("🎮 SKIN: Default viewport (portrait, native scale): size=\(size), aspectRatio=\(aspectRatio), safeInsets.top=\(safeInsets.top), effectiveTopSafeArea=\(effectiveTopSafeArea), controllerHeight=\(controllerHeight), gameAreaTop=\(gameAreaTop), gameAreaBottom=\(gameAreaBottom), gameAreaHeight=\(gameAreaHeight), frame=\(frame)")
            } else {
                /// Fullscreen scale: Scale to fill more of the available screen space
                /// Use more of the available width and height
                var width = maxWidth
                var height = width / aspectRatio

                /// If height exceeds available space, fit to height
                if height > availableHeight {
                    height = availableHeight
                    width = height * aspectRatio
                } else {
                    /// Scale up to use more of the available height
                    if height < availableHeight {
                        height = availableHeight
                        width = height * aspectRatio
                        /// Ensure width doesn't exceed available space
                        if width > maxWidth {
                            width = maxWidth
                            height = width / aspectRatio
                        }
                    }
                }

                /// Calculate the game screen area bounds
                let gameAreaTop = effectiveTopSafeArea + topMargin
                let gameAreaBottom = safeInsets.top + safeHeight - controllerHeight - bottomMargin
                let gameAreaHeight = gameAreaBottom - gameAreaTop

                /// Ensure frame fits within game area
                if height > gameAreaHeight {
                    height = gameAreaHeight
                    width = height * aspectRatio
                }

                /// Center horizontally and vertically in the game screen area
                let originX = safeInsets.leading + (safeWidth - width) / 2
                let originY = gameAreaTop + (gameAreaHeight - height) / 2

                frame = CGRect(x: originX, y: originY, width: width, height: height)
                ILOG("🎮 SKIN: Default viewport (portrait, fullscreen scale): size=\(size), aspectRatio=\(aspectRatio), safeInsets.top=\(safeInsets.top), effectiveTopSafeArea=\(effectiveTopSafeArea), controllerHeight=\(controllerHeight), gameAreaTop=\(gameAreaTop), gameAreaBottom=\(gameAreaBottom), gameAreaHeight=\(gameAreaHeight), frame=\(frame)")
            }
        }

        return frame
    }

    /// Compare frames with a tolerance to avoid unnecessary broadcasts
    private func framesAreApproximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 0.5 &&
        abs(lhs.origin.y - rhs.origin.y) < 0.5 &&
        abs(lhs.size.width - rhs.size.width) < 0.5 &&
        abs(lhs.size.height - rhs.size.height) < 0.5
    }

    // Load control layout data from the system
    @MainActor
    private func loadControlLayoutData() {
        guard let systemId = systemId else { return }

        // Access Realm to get the system
        let realm = RomDatabase.sharedInstance.realm
        if let system = realm.object(ofType: PVSystem.self, forPrimaryKey: systemId.rawValue) {
            self.controlLayout = system.controllerLayout
        }
    }

    // Dynamic controller skin based on system's control layout
    private var dynamicControllerSkin: AnyView {
        // If we have control layout data, use it to build a dynamic skin
        if let controlLayout = controlLayout {
            AnyView(buildDynamicSkin(from: controlLayout))
        } else {
            // Fallback to the generic skin if no control layout data is available
            AnyView(buildGenericSkin())
        }
    }

    // Dynamic landscape controller skin
    private var dynamicLandscapeControllerSkin: AnyView {
        // If we have control layout data, use it to build a dynamic skin for landscape
        if let controlLayout = controlLayout {
            AnyView(buildDynamicLandscapeSkin(from: controlLayout))
        } else {
            // Fallback to the generic landscape skin if no control layout data is available
            AnyView(landscapeControllerLayout)
        }
    }

    // Generic skin when no control layout data is available
    @ViewBuilder
    private func buildGenericSkin() -> some View {
        VStack(spacing: 15) {
            // Top row - L/R buttons and menu/turbo
            HStack(spacing: 15) {
                // L buttons (L2 on outer/left edge)
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        shoulderButton(label: "L2", color: .gray)
                        shoulderButton(label: "L", color: .gray)
                    }
                    shoulderButton(label: "L3", color: .gray)
                }

                Spacer()

                // Menu and Turbo buttons - horizontally aligned
                HStack(spacing: 15) {
                    utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                    utilityButton(label: "TURBO", color: .orange, systemImage: "forward.fill")
                }

                Spacer()

                // R buttons (R2 on outer/right edge)
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        shoulderButton(label: "R", color: .gray)
                        shoulderButton(label: "R2", color: .gray)
                    }
                    shoulderButton(label: "R3", color: .gray)
                }
            }
            .padding(.horizontal)

            Spacer().frame(height: 20) // Add space to raise D-pad position

            HStack(spacing: 20) { // Reduced spacing to prevent off-screen issues
                // Left side - D-Pad or Joystick
                VStack(spacing: 8) {
                    // Show either D-pad or joystick based on toggle
                    if useJoystickInternal {
                        joystickView()
                    } else {
                        dPadView()
                    }

                    // D-pad/Joystick toggle - moved below dpad/joystick, icon only
                    Button(action: {
                        useJoystickInternal.toggle()
                    }) {
                        Image(systemName: useJoystickInternal ? "circle.grid.cross" : "dpad")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .buttonStyle(GameButtonStyle(pressAction: {}, releaseAction: {}))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right side - Action buttons (constrained to prevent off-screen)
                VStack(spacing: 10) {
                    let cachedFps = fpsButtonConfig
                    HStack(spacing: 20) {
                        if let fps = cachedFps {
                            VStack(spacing: 20) {
                                circleButton(label: fps.tl.0, color: fps.tl.2, inputId: fps.tl.1)
                                circleButton(label: fps.bl.0, color: fps.bl.2, inputId: fps.bl.1)
                            }
                            VStack(spacing: 20) {
                                circleButton(label: fps.tr.0, color: fps.tr.2, inputId: fps.tr.1)
                                circleButton(label: fps.br.0, color: fps.br.2, inputId: fps.br.1)
                            }
                        } else {
                            VStack(spacing: 20) {
                                circleButton(label: "Y", color: .yellow)
                                circleButton(label: "X", color: .blue)
                            }
                            VStack(spacing: 20) {
                                circleButton(label: "B", color: .red)
                                circleButton(label: "A", color: .green)
                            }
                        }
                    }
                    if let fps = cachedFps, let center = fps.center {
                        circleButton(label: center.0, color: center.2, inputId: center.1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Spacer().frame(height: 15) // Reduced space before Start/Select buttons to move them up

            // Start/Select buttons centered at the bottom
            HStack {
                Spacer() // Center the buttons
                HStack(spacing: 30) { // Increased spacing between buttons
                    pillButton(label: "SELECT", color: .black)
                    pillButton(label: "START", color: .black)
                }
                Spacer() // Center the buttons
            }
        }
        .padding()
    }

    /// Stylized D-Pad view with retrowave aesthetic
    /// Custom octagon shape with rounded corners
    private struct RoundedOctagon: Shape {
        var cornerRadius: CGFloat

        func path(in rect: CGRect) -> Path {
            let width = rect.width
            let height = rect.height
            let radius = min(width, height) / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)

            // Calculate the eight points of the octagon
            var points: [CGPoint] = []
            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                points.append(CGPoint(x: x, y: y))
            }

            // Create a path with rounded corners
            var path = Path()
            for (index, point) in points.enumerated() {
                let nextIndex = (index + 1) % points.count
                let nextPoint = points[nextIndex]

                if index == 0 {
                    path.move(to: point)
                }

                path.addLine(to: nextPoint)
            }

            return path
        }
    }

    // Track active D-pad directions and touch position
    private class DPadState: ObservableObject {
        @Published var up = false
        @Published var down = false
        @Published var left = false
        @Published var right = false
        @Published var touchPosition: CGPoint = .zero
        @Published var isTouching = false

        func reset() {
            up = false
            down = false
            left = false
            right = false
            isTouching = false
        }
    }

    private func dPadView() -> some View {
        return ZStack {
            // D-pad background with neon glow using octagon shape
            RoundedOctagon(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
                .frame(width: 180, height: 180)
                .overlay(
                    RoundedOctagon(cornerRadius: 15)
                        .stroke(themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.8), lineWidth: 2)
                        .blur(radius: 4)
                )
                .overlay(
                    RoundedOctagon(cornerRadius: 15)
                        .stroke(Color.white, lineWidth: 1)
                )

            // D-pad cross indicator (plus shape)
            ZStack {
                // Horizontal line
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 120, height: 2)

                // Vertical line
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: 120)
            }

            // Directional indicators that highlight when active
            ZStack {
                // Up indicator
                Text("▲")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(dpadState.up ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55)) : .white)
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55), radius: dpadState.up ? 6 : 2)
                    .position(x: 90, y: 45)

                // Down indicator
                Text("▼")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(dpadState.down ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55)) : .white)
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55), radius: dpadState.down ? 6 : 2)
                    .position(x: 90, y: 135)

                // Left indicator
                Text("◀")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(dpadState.left ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55)) : .white)
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55), radius: dpadState.left ? 6 : 2)
                    .position(x: 45, y: 90)

                // Right indicator
                Text("▶")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(dpadState.right ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55)) : .white)
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55), radius: dpadState.right ? 6 : 2)
                    .position(x: 135, y: 90)

                // Up-Left diagonal indicator
                Text("⬉")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor((dpadState.up && dpadState.left) ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55)) : .white)
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55), radius: (dpadState.up && dpadState.left) ? 6 : 2)
                    .position(x: 45, y: 45)

                // Up-Right diagonal indicator
                Text("⬈")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor((dpadState.up && dpadState.right) ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55)) : .white)
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55), radius: (dpadState.up && dpadState.right) ? 6 : 2)
                    .position(x: 135, y: 45)

                // Down-Left diagonal indicator
                Text("⬋")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor((dpadState.down && dpadState.left) ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55)) : .white)
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55), radius: (dpadState.down && dpadState.left) ? 6 : 2)
                    .position(x: 45, y: 135)

                // Down-Right diagonal indicator
                Text("⬊")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor((dpadState.down && dpadState.right) ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55)) : .white)
                    .shadow(color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55), radius: (dpadState.down && dpadState.right) ? 6 : 2)
                    .position(x: 135, y: 135)
            }

            // Touch indicator overlay - positioned above the gesture area but below the gesture recognizer
            if dpadState.isTouching {
                DeltaSkinTouchIndicator(at: dpadState.touchPosition)
                    .allowsHitTesting(false) // Prevent the indicator from interfering with touches
            }
            #if !os(tvOS)
            // Gesture area
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Calculate position relative to center
                            let center = CGPoint(x: 90, y: 90)
                            let location = value.location
                            let dx = location.x - center.x
                            let dy = location.y - center.y

                            // Update touch position for the indicator
                            dpadState.touchPosition = location
                            dpadState.isTouching = true

                            // Determine which directions should be active
                            let newUp = dy < -20
                            let newDown = dy > 20
                            let newLeft = dx < -20
                            let newRight = dx > 20

                            // Handle direction changes
                            if newUp != dpadState.up {
                                dpadState.up = newUp
                                if newUp {
                                    inputHandler.buttonPressed("up")
                                } else {
                                    inputHandler.buttonReleased("up")
                                }
                            }

                            if newDown != dpadState.down {
                                dpadState.down = newDown
                                if newDown {
                                    inputHandler.buttonPressed("down")
                                } else {
                                    inputHandler.buttonReleased("down")
                                }
                            }

                            if newLeft != dpadState.left {
                                dpadState.left = newLeft
                                if newLeft {
                                    inputHandler.buttonPressed("left")
                                } else {
                                    inputHandler.buttonReleased("left")
                                }
                            }

                            if newRight != dpadState.right {
                                dpadState.right = newRight
                                if newRight {
                                    inputHandler.buttonPressed("right")
                                } else {
                                    inputHandler.buttonReleased("right")
                                }
                            }
                        }
                        .onEnded { _ in
                            // Release all directions when touch ends
                            if dpadState.up {
                                inputHandler.buttonReleased("up")
                            }
                            if dpadState.down {
                                inputHandler.buttonReleased("down")
                            }
                            if dpadState.left {
                                inputHandler.buttonReleased("left")
                            }
                            if dpadState.right {
                                inputHandler.buttonReleased("right")
                            }
                            dpadState.reset()
                        }
                )
            #endif // !tvOS
        }
        .frame(width: 150, height: 150)
    }

    // State class for joystick
    private class JoystickState: ObservableObject {
        @Published var position: CGSize = .zero
        @Published var touchPosition: CGPoint = .zero
        @Published var isTouching = false
        @Published var isActive = false
    }

    private struct DeltaJoystickView: View {
        @StateObject private var joystickState = JoystickState()
        let inputHandler: DeltaSkinInputHandler

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Joystick background
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .overlay(
                            Circle()
                                .stroke(ThemeManager.shared.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.0, green: 0.8, blue: 0.9, opacity: 0.8), lineWidth: 2)
                                .blur(radius: 4)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )

                    // Joystick handle (top cap)
                    Circle()
                        .fill(joystickState.isActive ? (ThemeManager.shared.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.0, green: 0.8, blue: 0.9)) : Color.gray)
                        .frame(width: geometry.size.width * 0.4, height: geometry.size.width * 0.4)
                        .offset(x: joystickState.position.width, y: joystickState.position.height)
                        .shadow(color: ThemeManager.shared.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.0, green: 0.8, blue: 0.9), radius: joystickState.isActive ? 10 : 0)

                    // Touch indicator overlay
                    if joystickState.isTouching {
                        DeltaSkinTouchIndicator(at: joystickState.touchPosition)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Circle())
                #if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let center = CGPoint(x: geometry.size.width/2, y: geometry.size.width/2)
                            let location = value.location

                            joystickState.touchPosition = location
                            joystickState.isTouching = true
                            joystickState.isActive = true

                            let deltaX = location.x - center.x
                            let deltaY = location.y - center.y
                            let distance = sqrt(deltaX*deltaX + deltaY*deltaY)
                            let maxDistance = geometry.size.width/2 * 0.6
                            let limitedDistance = min(distance, maxDistance)
                            let angle = atan2(deltaY, deltaX)
                            let limitedX = limitedDistance * cos(angle)
                            let limitedY = limitedDistance * sin(angle)
                            joystickState.position = CGSize(width: limitedX, height: limitedY)

                            let normalizedX = Float(min(max(deltaX / maxDistance, -1.0), 1.0))
                            let normalizedY = Float(min(max(-deltaY / maxDistance, -1.0), 1.0))
                            inputHandler.analogStickMoved("leftAnalog", x: normalizedX, y: normalizedY)
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                joystickState.position = .zero
                                joystickState.isActive = false
                                joystickState.isTouching = false
                            }
                            inputHandler.analogStickMoved("leftAnalog", x: 0, y: 0)
                        }
                )
                #endif
            }
        }
    }

    /// Returns FPS-specific button labels/IDs for Doom/Wolf3D/Quake, or nil for other systems.
    /// Layout: (topLeft, bottomLeft, topRight, bottomRight) matching the diamond pattern,
    /// with an optional center button displayed between the two columns.
    private var fpsButtonConfig: (tl: (String, String, Color), bl: (String, String, Color),
                                  tr: (String, String, Color), br: (String, String, Color),
                                  center: (String, String, Color)?)? {
        DLOG("fpsButtonConfig: systemId = \(String(describing: systemId))")
        guard let systemId else { return nil }
        switch systemId {
        case .DOOM:
            return (tl: ("MAP", "map", .yellow), bl: ("RUN", "run", .blue),
                    tr: ("USE", "use", .red), br: ("FIRE", "fire", .green),
                    center: ("STRAFE", "strafe", .orange))
        case .Wolf3D:
            return (tl: ("STRAFE", "strafe", .yellow), bl: ("RUN", "run", .blue),
                    tr: ("USE", "use", .red), br: ("FIRE", "fire", .green),
                    center: nil)
        case .Quake, .Quake2:
            return (tl: ("JUMP", "jump", .yellow), bl: ("RUN", "run", .blue),
                    tr: ("USE", "use", .red), br: ("FIRE", "fire", .green),
                    center: nil)
        default:
            return nil
        }
    }

    /// Joystick view with touch tracking
    private func joystickView() -> some View {
        DeltaJoystickView(inputHandler: inputHandler)
            .frame(width: 150, height: 150)
    }

    /// Circle button view with retrowave styling
    /// - Parameters:
    ///   - label: Display text shown on the button
    ///   - color: Button color
    ///   - inputId: Optional override for the input ID sent to the handler (defaults to label.lowercased())
    private func circleButton(label: String, color: Color, inputId: String? = nil) -> some View {
        // Use theme's tint color if no specific color is provided
        let buttonColor = color == .gray ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? color) : color
        let effectiveInputId = inputId ?? label.lowercased()

        return Button(action: {}) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.clear)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(buttonColor, lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )

                // Button label with neon effect
                NeonText(label, color: buttonColor, fontSize: 20)
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            inputHandler.buttonPressed(effectiveInputId)
        }, releaseAction: {
            inputHandler.buttonReleased(effectiveInputId)
        }))
    }

    /// Pill-shaped button view with retrowave styling
    private func pillButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            ZStack {
                // Outer glow
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 80, height: 35)
                    .overlay(
                        Capsule()
                            .stroke(themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55, opacity: 0.8), lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white, lineWidth: 1)
                    )

                // Button label with neon effect
                NeonText(label, color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.99, green: 0.11, blue: 0.55), fontSize: 14)
            }
            .frame(width: 80, height: 35)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            inputHandler.buttonPressed(label.lowercased())
        }, releaseAction: {
            inputHandler.buttonReleased(label.lowercased())
        }))
    }

    /// Shoulder button view with retrowave styling
    private func shoulderButton(label: String, color: Color) -> some View {
        Button(action: {}) {
            ZStack {
                // Outer glow
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .frame(width: 45, height: 35)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.0, green: 0.8, blue: 0.9, opacity: 0.8), lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 1)
                    )

                // Button label with neon effect
                NeonText(label, color: themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color(red: 0.0, green: 0.8, blue: 0.9), fontSize: 14)
            }
            .frame(width: 45, height: 35)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            inputHandler.buttonPressed(label.lowercased())
        }, releaseAction: {
            inputHandler.buttonReleased(label.lowercased())
        }))
    }

    /// Utility button with icon and retrowave styling
    private func utilityButton(label: String, color: Color, systemImage: String) -> some View {
        Button(action: {
            let id = label.lowercased()
            if id == "menu" {
                inputHandler.buttonPressed("menu")
            } else if id == "turbo" {
                inputHandler.buttonPressed("togglefastforward")
            }
        }) {
            ZStack {
                // Outer glow
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .frame(width: 60, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color, lineWidth: 2)
                            .blur(radius: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white, lineWidth: 1)
                    )

                // Button content with neon effect
                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .shadow(color: color, radius: 2)
                        .shadow(color: color, radius: 4)

                    NeonText(label, color: color, fontSize: 12)
                }
            }
            .frame(width: 60, height: 50)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            // For utility buttons, forward generic press events except TURBO and MENU (handled via toggle/action)
            let id = label.lowercased()
            if id != "turbo" && id != "menu" {
                inputHandler.buttonPressed(id)
            }
        }, releaseAction: {
            let id = label.lowercased()
            if id != "turbo" && id != "menu" {
                inputHandler.buttonReleased(id)
            }
        }))
    }

    // Build a dynamic landscape skin based on the system's control layout data
    @ViewBuilder
    private func buildDynamicLandscapeSkin(from layout: [ControlLayoutEntry]) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Top row with shoulder buttons, menu and turbo buttons
                VStack {
                    // Add minimal spacing at the top
                    Spacer().frame(height: 5)

                    HStack {
                        // Left shoulder buttons (L2 on outer/left edge)
                        HStack(spacing: 15) {
                            if hasControl(type: "PVLeftShoulderButton", title: "L2", in: layout) {
                                shoulderButton(label: "L2", color: .gray)
                            }
                            if hasControl(type: "PVLeftShoulderButton", title: "L1", in: layout) ||
                                hasControl(type: "PVLeftShoulderButton", title: "L", in: layout) {
                                shoulderButton(label: hasControl(type: "PVLeftShoulderButton", title: "L1", in: layout) ? "L1" : "L", color: .gray)
                            }
                            if hasControl(type: "PVLeftAnalogButton", title: "L3", in: layout) {
                                shoulderButton(label: "L3", color: .gray)
                            }
                        }
                        .padding(.leading, 20)

                        Spacer()

                        // Menu and Turbo buttons in center
                        HStack(spacing: 20) {
                            utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                            utilityButton(label: "TURBO", color: .orange, systemImage: "forward.fill")
                        }

                        Spacer()

                        // Right shoulder buttons (R2 on outer/right edge)
                        HStack(spacing: 15) {
                            if hasControl(type: "PVRightAnalogButton", title: "R3", in: layout) {
                                shoulderButton(label: "R3", color: .gray)
                            }
                            if hasControl(type: "PVRightShoulderButton", title: "R1", in: layout) ||
                                hasControl(type: "PVRightShoulderButton", title: "R", in: layout) {
                                shoulderButton(label: hasControl(type: "PVRightShoulderButton", title: "R1", in: layout) ? "R1" : "R", color: .gray)
                            }
                            if hasControl(type: "PVRightShoulderButton", title: "R2", in: layout) {
                                shoulderButton(label: "R2", color: .gray)
                            }
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 20)

                    Spacer()

                    // Start/Select buttons at the center bottom
                    HStack {
                        Spacer()

                        HStack(spacing: 30) {
                            if hasControl(type: "PVSelectButton", in: layout) {
                                pillButton(label: "SELECT", color: .black)
                            }
                            if hasControl(type: "PVStartButton", in: layout) {
                                pillButton(label: "START", color: .black)
                            }
                        }
                        .padding(.bottom, 20)

                        Spacer()
                    }
                }

                // D-pad positioned at left edge
                VStack {
                    Spacer()
                    HStack {
                        VStack(spacing: 8) {
                            if useJoystickInternal && hasControl(type: "PVJoyPad", in: layout) {
                                joystickView()
                            } else if hasControl(type: "PVDPad", in: layout) {
                                dPadView()
                            }

                            // Toggle button below dpad/joystick - icon only
                            if hasControl(type: "PVDPad", in: layout) && hasControl(type: "PVJoyPad", in: layout) {
                                Button(action: {
                                    useJoystickInternal.toggle()
                                }) {
                                    Image(systemName: useJoystickInternal ? "circle.grid.cross" : "dpad")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.blue.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(GameButtonStyle(pressAction: {}, releaseAction: {}))
                            }
                        }
                        Spacer()
                    }
                    .padding(.leading, 80)
                    Spacer()
                }
                .frame(width: geometry.size.width, alignment: .leading)

                // Action buttons positioned at right edge using absolute positioning
                VStack {
                    Spacer()
                    // Find all button groups in the layout
                    let buttonGroups = layout.filter { $0.PVControlType == "PVButtonGroup" }

                    if !buttonGroups.isEmpty {
                        // Separate number pad groups from standard button groups
                        let (numPadGroups, standardGroups) = separateButtonGroups(buttonGroups)

                        // Show standard button groups always
                        if !standardGroups.isEmpty {
                            VStack(spacing: 15) {
                                ForEach(0..<standardGroups.count, id: \.self) { index in
                                    if let groupedButtons = standardGroups[index].PVGroupedButtons {
                                        let groupSize = parseCGSize(from: standardGroups[index].PVControlSize)
                                        createButtonGroup(from: groupedButtons, groupSize: groupSize)
                                    }
                                }
                            }
                        }

                        // Flip card container for standard buttons and number pad
                        if !numPadGroups.isEmpty {
                            // Flip card view with smooth animation
                            ZStack {
                                // Standard buttons (back face when flipped)
                                if !standardGroups.isEmpty {
                                    VStack(spacing: 15) {
                                        ForEach(0..<standardGroups.count, id: \.self) { index in
                                            if let groupedButtons = standardGroups[index].PVGroupedButtons {
                                                let groupSize = parseCGSize(from: standardGroups[index].PVControlSize)
                                                createButtonGroup(from: groupedButtons, groupSize: groupSize)
                                                    .id("buttonGroup_landscape_\(index)")
                                            }
                                        }
                                    }
                                    .opacity(showNumPad ? 0 : 1)
                                    .scaleEffect(showNumPad ? 0.8 : 1.0)
                                    .rotation3DEffect(
                                        .degrees(showNumPad ? 90 : 0),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.3
                                    )
                                }

                                // Number pad (front face when flipped)
                                VStack(spacing: 8) {
                                    ForEach(Array(numPadGroups.enumerated()), id: \.offset) { index, entry in
                                        if let groupedButtons = entry.PVGroupedButtons {
                                            createNumPadGrid(from: groupedButtons)
                                                .id("numPadGroup_landscape_\(index)")
                                        }
                                    }
                                }
                                .opacity(showNumPad ? 1 : 0)
                                .scaleEffect(showNumPad ? 1.0 : 0.8)
                                .rotation3DEffect(
                                    .degrees(showNumPad ? 0 : -90),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.3
                                )

                                // Flip toggle button overlay - positioned at top right
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                showNumPad.toggle()
                                            }
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.blue.opacity(0.9))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white, lineWidth: 2)
                                                    )
                                                    .shadow(color: Color.blue.opacity(0.5), radius: 4)

                                                Image(systemName: showNumPad ? "arrow.uturn.backward" : "number.circle.fill")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .buttonStyle(GameButtonStyle(pressAction: {}, releaseAction: {}))
                                        .padding(.trailing, 4)
                                        .padding(.top, 4)
                                    }
                                    Spacer()
                                }
                            }
                            .frame(minHeight: 200)
                        }
                    } else {
                        // Fallback to generic ABXY layout with reduced spacing
                        HStack(spacing: 20) {
                            VStack(spacing: 20) {
                                circleButton(label: "Y", color: .yellow)
                                circleButton(label: "X", color: .blue)
                            }

                            VStack(spacing: 20) {
                                circleButton(label: "B", color: .red)
                                circleButton(label: "A", color: .green)
                            }
                        }
                    }
                    Spacer()
                }
                .frame(width: 250) // Reduced width to prevent clipping
                .position(x: geometry.size.width - 150, y: geometry.size.height / 2)
            }
        }
    }

    // Build a dynamic skin based on the system's control layout data
    @ViewBuilder
    private func buildDynamicSkin(from layout: [ControlLayoutEntry]) -> some View {
        // Compact layout for portrait mode - constrained to bottom area
        VStack(spacing: 8) {
            // Top row - utility buttons and system-specific shoulder buttons
            HStack(spacing: 10) {
                // L buttons (L2 on outer/left edge)
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        // Check if L2 buttons are in the layout (outer edge first)
                        if hasControl(type: "PVLeftShoulderButton", title: "L2", in: layout) {
                            shoulderButton(label: "L2", color: .gray)
                        }
                        // Check if L1/L buttons are in the layout
                        if hasControl(type: "PVLeftShoulderButton", title: "L1", in: layout) ||
                            hasControl(type: "PVLeftShoulderButton", title: "L", in: layout) {
                            shoulderButton(label: "L", color: .gray)
                        }
                    }
                    // Check if L3 buttons are in the layout
                    if hasControl(type: "PVLeftAnalogButton", title: "L3", in: layout) {
                        shoulderButton(label: "L3", color: .gray)
                    }
                }

                Spacer()

                // Menu and Turbo buttons - horizontally aligned
                HStack(spacing: 15) {
                    utilityButton(label: "MENU", color: .purple, systemImage: "line.3.horizontal")
                    utilityButton(label: "TURBO", color: .orange, systemImage: "forward.fill")
                }

                Spacer()

                // R buttons (R2 on outer/right edge)
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        // Check if R1/R buttons are in the layout
                        if hasControl(type: "PVRightShoulderButton", title: "R1", in: layout) ||
                            hasControl(type: "PVRightShoulderButton", title: "R", in: layout) {
                            shoulderButton(label: "R", color: .gray)
                        }
                        // Check if R2 buttons are in the layout (outer edge last)
                        if hasControl(type: "PVRightShoulderButton", title: "R2", in: layout) {
                            shoulderButton(label: "R2", color: .gray)
                        }
                    }
                    // Check if R3 buttons are in the layout
                    if hasControl(type: "PVRightAnalogButton", title: "R3", in: layout) {
                        shoulderButton(label: "R3", color: .gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, -2)  // Moved up 6px from 4px

            // Main control area - D-pad and action buttons
            HStack(spacing: 15) {
                // Left side - D-Pad or Joystick
                VStack(spacing: 8) {
                    // Show either D-pad or joystick based on toggle and system support
                    if useJoystickInternal && hasControl(type: "PVJoyPad", in: layout) {
                        joystickView()
                    } else if hasControl(type: "PVDPad", in: layout) {
                        dPadView()
                    }

                    // Only show D-pad/joystick toggle if the system has both - moved below, icon only
                    if hasControl(type: "PVDPad", in: layout) && hasControl(type: "PVJoyPad", in: layout) {
                        Button(action: {
                            useJoystickInternal.toggle()
                        }) {
                            Image(systemName: useJoystickInternal ? "circle.grid.cross" : "dpad")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.blue.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .buttonStyle(GameButtonStyle(pressAction: {}, releaseAction: {}))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right side - Action buttons with flip animation for number pad
                VStack(spacing: 10) {
                    // Find all button groups in the layout
                    let buttonGroups = layout.filter { $0.PVControlType == "PVButtonGroup" }

                    if !buttonGroups.isEmpty {
                        // Separate number pad groups from standard button groups
                        let (numPadGroups, standardGroups) = separateButtonGroups(buttonGroups)

                        // Flip card container for standard buttons and number pad
                        if !numPadGroups.isEmpty {
                            // Flip card view with smooth animation
                            ZStack {
                                // Standard buttons (back face when flipped)
                                if !standardGroups.isEmpty {
                                    VStack(spacing: 15) {
                                        ForEach(0..<standardGroups.count, id: \.self) { index in
                                            if let groupedButtons = standardGroups[index].PVGroupedButtons {
                                                let groupSize = parseCGSize(from: standardGroups[index].PVControlSize)
                                                createButtonGroup(from: groupedButtons, groupSize: groupSize)
                                                    .id("buttonGroup_\(index)")
                                                    .frame(maxHeight: .infinity)
                                            }
                                        }
                                    }
                                    .opacity(showNumPad ? 0 : 1)
                                    .scaleEffect(showNumPad ? 0.8 : 1.0)
                                    .rotation3DEffect(
                                        .degrees(showNumPad ? 90 : 0),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.3
                                    )
                                }

                                // Number pad (front face when flipped)
                                VStack(spacing: 8) {
                                    ForEach(Array(numPadGroups.enumerated()), id: \.offset) { index, entry in
                                        if let groupedButtons = entry.PVGroupedButtons {
                                            createNumPadGrid(from: groupedButtons)
                                                .id("numPadGroup_\(index)")
                                        }
                                    }
                                }
                                .opacity(showNumPad ? 1 : 0)
                                .scaleEffect(showNumPad ? 1.0 : 0.8)
                                .rotation3DEffect(
                                    .degrees(showNumPad ? 0 : -90),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.3
                                )

                                // Flip toggle button overlay - positioned at top right
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                showNumPad.toggle()
                                            }
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.blue.opacity(0.9))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white, lineWidth: 2)
                                                    )
                                                    .shadow(color: Color.blue.opacity(0.5), radius: 4)

                                                Image(systemName: showNumPad ? "arrow.uturn.backward" : "number.circle.fill")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .buttonStyle(GameButtonStyle(pressAction: {}, releaseAction: {}))
                                        .padding(.trailing, 4)
                                        .padding(.top, -8)  // Moved up 12px from 4px
                                    }
                                    Spacer()
                                }
                            }
                            .frame(minHeight: 200)
                        } else if !standardGroups.isEmpty {
                            // No number pad, just show standard buttons
                            VStack(spacing: 15) {
                                ForEach(0..<standardGroups.count, id: \.self) { index in
                                    if let groupedButtons = standardGroups[index].PVGroupedButtons {
                                        let groupSize = parseCGSize(from: standardGroups[index].PVControlSize)
                                        createButtonGroup(from: groupedButtons, groupSize: groupSize)
                                            .id("buttonGroup_\(index)")
                                            .frame(maxHeight: .infinity)
                                    }
                                }
                            }
                        }
                    } else {
                        // Fallback to generic ABXY layout with reduced spacing
                        HStack(spacing: 20) {
                            VStack(spacing: 20) {
                                circleButton(label: "Y", color: .yellow)
                                circleButton(label: "X", color: .blue)
                            }

                            VStack(spacing: 20) {
                                circleButton(label: "B", color: .red)
                                circleButton(label: "A", color: .green)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Start/Select buttons centered at the bottom
            HStack {
                Spacer()
                HStack(spacing: 20) {
                    if hasControl(type: "PVSelectButton", in: layout) {
                        pillButton(label: "SELECT", color: .black)
                    }
                    if hasControl(type: "PVStartButton", in: layout) {
                        pillButton(label: "START", color: .black)
                    }
                }
                Spacer()
            }
            .padding(.bottom, 14)  // Added 6px spacing (was 8px, now 14px)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Parse CGRect from string format like "{{162,4},{60,60}}"
    private func parseCGRect(from string: String) -> CGRect? {
        return NSCoder.cgRect(for: string)
    }

    /// Parse CGSize from string format like "{264, 380}"
    private func parseCGSize(from string: String) -> CGSize? {
        return NSCoder.cgSize(for: string)
    }

    /// Check if buttons have valid frame data for absolute positioning
    private func hasValidFrames(_ buttons: [ControlGroupButton]) -> Bool {
        return buttons.allSatisfy { button in
            let frame = parseCGRect(from: button.PVControlFrame)
            return frame != nil && frame != .zero
        }
    }

    /// Calculate the bounding box including button sizes to ensure all buttons fit
    private func calculateBoundingBoxWithPadding(for buttons: [ControlGroupButton], groupSize: CGSize, padding: CGFloat = 10) -> CGRect {
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0

        for button in buttons {
            guard let frame = parseCGRect(from: button.PVControlFrame) else { continue }
            let buttonSize = min(frame.width, frame.height)
            let halfSize = buttonSize / 2

            minX = min(minX, frame.midX - halfSize)
            minY = min(minY, frame.midY - halfSize)
            maxX = max(maxX, frame.midX + halfSize)
            maxY = max(maxY, frame.midY + halfSize)
        }

        // Add padding
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + (padding * 2),
            height: (maxY - minY) + (padding * 2)
        )
    }

    // Create a button group based on the system's button layout
    @ViewBuilder
    private func createButtonGroup(from buttons: [ControlGroupButton], groupSize: CGSize? = nil) -> some View {
        // Check if buttons have valid frame data for absolute positioning
        if hasValidFrames(buttons), let groupSize = groupSize {
            // Use absolute positioning based on PVControlFrame data
            GeometryReader { geometry in
                let boundingBox = calculateBoundingBoxWithPadding(for: buttons, groupSize: groupSize, padding: 5)

                ZStack {
                    ForEach(Array(buttons.enumerated()), id: \.offset) { index, button in
                        if let frame = parseCGRect(from: button.PVControlFrame) {
                            // Calculate scale based on available space and bounding box
                            // Account for button sizes to ensure they fit within bounds
                            let scaleX = geometry.size.width / boundingBox.width
                            let scaleY = geometry.size.height / boundingBox.height
                            let scale = min(scaleX, scaleY) // Maintain aspect ratio

                            // Scale button size proportionally
                            let buttonSize = min(frame.width, frame.height) * scale

                            // Calculate position relative to bounding box, then scale
                            let relativeX = frame.midX - boundingBox.minX
                            let relativeY = frame.midY - boundingBox.minY

                            // Position button ensuring it stays within bounds
                            let positionX = relativeX * scale
                            let positionY = relativeY * scale

                            createButton(from: button, size: buttonSize)
                                .position(x: positionX, y: positionY)
                                .id("button_group_frame_\(index)_\(button.PVControlTitle)")
                        }
                    }
                }
                .clipped() // Ensure buttons don't extend beyond bounds
            }
            .aspectRatio(groupSize.width / groupSize.height, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1) // Allow it to shrink if needed
        } else {
            // Fallback to grid layout when frames aren't available
        // Determine the best layout based on button count
        if buttons.count == 4 {
            // Standard 2x2 grid for 4 buttons
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    createButton(from: buttons[0])
                        .id("button_group_0_\(buttons[0].PVControlTitle ?? "unknown")")
                    createButton(from: buttons[1])
                        .id("button_group_0_\(buttons[1].PVControlTitle ?? "unknown")")
                }
                HStack(spacing: 10) {
                    createButton(from: buttons[2])
                        .id("button_group_0_\(buttons[2].PVControlTitle ?? "unknown")")
                    createButton(from: buttons[3])
                        .id("button_group_0_\(buttons[3].PVControlTitle ?? "unknown")")
                }
            }
        } else if buttons.count == 3 {
            // Triangle arrangement for 3 buttons (like Jaguar ABC)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    createButton(from: buttons[0])
                        .id("button_group_1_\(buttons[0].PVControlTitle ?? "unknown")")
                }
                HStack(spacing: 10) {
                    createButton(from: buttons[1])
                        .id("button_group_1_\(buttons[1].PVControlTitle ?? "unknown")")
                    createButton(from: buttons[2])
                        .id("button_group_1_\(buttons[2].PVControlTitle ?? "unknown")")
                }
            }
        } else if buttons.count >= 9 && buttons.count <= 12 {
            // Number pad layout (3x4 grid for 9-12 buttons)
            VStack(spacing: 10) {
                // First row
                HStack(spacing: 10) {
                    ForEach(0..<min(3, buttons.count), id: \.self) { index in
                        createButton(from: buttons[index])
                    }
                }
                // Second row
                if buttons.count > 3 {
                    HStack(spacing: 10) {
                        ForEach(3..<min(6, buttons.count), id: \.self) { index in
                            createButton(from: buttons[index])
                        }
                    }
                }
                // Third row
                if buttons.count > 6 {
                    HStack(spacing: 10) {
                        ForEach(6..<min(9, buttons.count), id: \.self) { index in
                            createButton(from: buttons[index])
                        }
                    }
                }
                // Fourth row
                if buttons.count > 9 {
                    HStack(spacing: 10) {
                        ForEach(9..<min(12, buttons.count), id: \.self) { index in
                            createButton(from: buttons[index])
                        }
                    }
                }
            }
        } else {
            // Fallback for other button counts
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 10) {
                ForEach(0..<buttons.count, id: \.self) { index in
                    createButton(from: buttons[index])
                    }
                }
            }
        }
    }

    // Create a compact number pad grid layout
    private func createNumPadGrid(from buttons: [ControlGroupButton]) -> some View {
        // Create a compact 3x4 grid for number pad buttons
        // Use smaller buttons to fit in the available space
        let buttonSize: CGFloat = 50  // Smaller buttons for compact layout
        let spacing: CGFloat = 6

        return VStack(spacing: spacing) {
            // Row 1: 1, 2, 3
            if buttons.count > 0 {
                HStack(spacing: spacing) {
                    ForEach(0..<min(3, buttons.count), id: \.self) { index in
                        createCompactButton(from: buttons[index], size: buttonSize)
                    }
                }
            }

            // Row 2: 4, 5, 6
            if buttons.count > 3 {
                HStack(spacing: spacing) {
                    ForEach(3..<min(6, buttons.count), id: \.self) { index in
                        createCompactButton(from: buttons[index], size: buttonSize)
                    }
                }
            }

            // Row 3: 7, 8, 9
            if buttons.count > 6 {
                HStack(spacing: spacing) {
                    ForEach(6..<min(9, buttons.count), id: \.self) { index in
                        createCompactButton(from: buttons[index], size: buttonSize)
                    }
                }
            }

            // Row 4: 0, *, #, or remaining buttons
            if buttons.count > 9 {
                HStack(spacing: spacing) {
                    ForEach(9..<min(12, buttons.count), id: \.self) { index in
                        createCompactButton(from: buttons[index], size: buttonSize)
                    }
                }
            }
        }
    }

    // Create a compact button for number pad (smaller size)
    private func createCompactButton(from button: ControlGroupButton, size: CGFloat) -> some View {
        let displayLabel = button.PVControlTitle ?? "Button"
        let actionIdentifier = button.PVControlTitle ?? displayLabel
        let color = colorFromString(button.PVControlTint) ?? .gray

        return Button(action: {}) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.clear)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 1.5)
                            .blur(radius: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 0.5)
                    )

                // Button label with neon effect
                NeonText(displayLabel, color: color, fontSize: 14)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            inputHandler.buttonPressed(actionIdentifier)
        }, releaseAction: {
            inputHandler.buttonReleased(actionIdentifier)
        }))
    }

    // Create a button from a ControlGroupButton
    @ViewBuilder
    private func createButton(from button: ControlGroupButton, size: CGFloat? = nil) -> some View {
        let displayLabel = button.PVControlTitle ?? "Button"

        // Map special PlayStation symbols to their proper identifiers
        let actionIdentifier = button.PVControlTitle ?? displayLabel

        let color = colorFromString(button.PVControlTint) ?? .gray
        let buttonSize = size ?? 60
        let fontSize = size != nil ? max(12, buttonSize * 0.33) : 20

        return Button(action: {}) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.clear)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: max(1, buttonSize / 30))
                            .blur(radius: max(2, buttonSize / 15))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: max(0.5, buttonSize / 60))
                    )

                // Button label with neon effect
                NeonText(displayLabel, color: color, fontSize: fontSize)
            }
            .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(GameButtonStyle(pressAction: {
            inputHandler.buttonPressed(actionIdentifier)
        }, releaseAction: {
            inputHandler.buttonReleased(actionIdentifier)
        }))
        .id("button_\(actionIdentifier)")
    }

    // Custom button style that handles press and release events
    struct GameButtonStyle: ButtonStyle {
        let pressAction: () -> Void
        let releaseAction: () -> Void

        @State private var isShowingOverlay = false
        @State private var touchPosition: CGPoint = CGPoint(x: 30, y: 30)
        @State private var wasPressed = false

        func makeBody(configuration: Configuration) -> some View {
            ZStack {
                // The button itself
                configuration.label
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
                    .overlay(
                        // Touch overlay that appears when pressed - positioned as an overlay to avoid layout issues
                        Group {
                            if configuration.isPressed || isShowingOverlay {
                                DeltaSkinTouchIndicator(at: touchPosition)
                                    .allowsHitTesting(false) // Prevent the indicator from interfering with touches
                            }
                        }
                    )
            }
            .onChange(of: configuration.isPressed) { isPressed in
                // Only trigger actions on state changes to avoid duplicate calls
                if isPressed && !wasPressed {
                    wasPressed = true
                    withAnimation(.easeIn(duration: 0.1)) {
                        isShowingOverlay = true
                    }
                    // Call press action immediately
                    pressAction()
                } else if !isPressed && wasPressed {
                    wasPressed = false
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowingOverlay = false
                    }
                    // Call release action immediately
                    releaseAction()
                }
            }
        }
    }

    // Convert a color string to a Color
    private func colorFromString(_ colorString: String?) -> Color? {
        guard let hexString = colorString else { return nil }

        // Remove the # prefix if present
        var hex = hexString
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }

        // Parse the hex color
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }

    // Check if a specific control type exists in the layout
    private func hasControl(type: String, in layout: [ControlLayoutEntry]) -> Bool {
        return layout.contains(where: { $0.PVControlType == type })
    }

    // Check if a specific control type with a specific title exists in the layout
    private func hasControl(type: String, title: String, in layout: [ControlLayoutEntry]) -> Bool {
        return layout.contains(where: { $0.PVControlType == type && $0.PVControlTitle == title })
    }

    /// Separate button groups into number pad groups (0-9, *, #) and standard button groups (A, B, C, X, Y, Z, etc.)
    private func separateButtonGroups(_ buttonGroups: [ControlLayoutEntry]) -> (numPadGroups: [ControlLayoutEntry], standardGroups: [ControlLayoutEntry]) {
        var numPadGroups: [ControlLayoutEntry] = []
        var standardGroups: [ControlLayoutEntry] = []

        for group in buttonGroups {
            guard let buttons = group.PVGroupedButtons else {
                standardGroups.append(group)
                continue
            }

            /// Check if this group contains primarily number pad buttons (0-9, *, #)
            let numPadButtonTitles = Set(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "#"])
            let buttonTitles = Set(buttons.compactMap { $0.PVControlTitle })

            /// Count how many buttons are number pad buttons vs standard buttons
            let numPadCount = buttonTitles.filter { numPadButtonTitles.contains($0) }.count
            let standardCount = buttonTitles.count - numPadCount

            /// If the majority of buttons are number pad buttons, treat this as a number pad group
            if numPadCount > standardCount && numPadCount >= 9 {
                numPadGroups.append(group)
            } else {
                standardGroups.append(group)
            }
        }

        return (numPadGroups, standardGroups)
    }
}

/// Helper view to track geometry changes and update viewport
/// Uses same immediate calculation path as initial startup - no special rotation handling
private struct ViewportUpdater: View {
    let size: CGSize
    let safeInsets: EdgeInsets
    let onUpdate: (CGSize, EdgeInsets, Bool) -> Void

    @State private var lastSize: CGSize = .zero
    @State private var lastSafeInsets: EdgeInsets = EdgeInsets()
    @State private var lastIsLandscape: Bool?

    var body: some View {
        // Use a minimal frame to ensure the view doesn't affect layout
        // but still exists to receive updates
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .onAppear {
                // Guard against invalid size
                guard size.width > 0 && size.height > 0 else { return }

                // Initial calculation - immediate, no delays
                let isLandscape = size.width > size.height
                lastSize = size
                lastSafeInsets = safeInsets
                lastIsLandscape = isLandscape
                onUpdate(size, safeInsets, isLandscape)
            }
            .onChange(of: size) { newSize in
                // Guard against invalid size
                guard newSize.width > 0 && newSize.height > 0 else { return }

                // Use same immediate calculation path as onAppear
                // Always recalculate on size change - same as bootup
                let isLandscape = newSize.width > newSize.height
                let orientationChanged = lastIsLandscape != nil && lastIsLandscape != isLandscape
                let sizeChanged = abs(newSize.width - lastSize.width) > 1.0 || abs(newSize.height - lastSize.height) > 1.0

                // Update if size changed OR orientation changed
                if sizeChanged || orientationChanged {
                    lastSize = newSize
                    lastIsLandscape = isLandscape
                    // Immediate update - same code path as initial startup
                    onUpdate(newSize, safeInsets, isLandscape)
                }
            }
            .onChange(of: safeInsets) { newInsets in
                // Guard against invalid size
                guard size.width > 0 && size.height > 0 else { return }

                // Use same immediate calculation path as onAppear
                // Always recalculate on safe inset change - same as bootup
                let insetsChanged = abs(newInsets.top - lastSafeInsets.top) > 0.5 ||
                                   abs(newInsets.bottom - lastSafeInsets.bottom) > 0.5 ||
                                   abs(newInsets.leading - lastSafeInsets.leading) > 0.5 ||
                                   abs(newInsets.trailing - lastSafeInsets.trailing) > 0.5
                if insetsChanged {
                    let isLandscape = size.width > size.height
                    lastSafeInsets = newInsets
                    // Immediate update - same code path as initial startup
                    onUpdate(size, newInsets, isLandscape)
                }
            }
    }
}
