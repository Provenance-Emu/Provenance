//
//  PauseTileMenuView.swift
//  PVUI
//
//  Created by Claude on 3/17/26.
//  Part of #3248 — tile-based pause menu (feature-flagged, default OFF)
//
//  Design goals:
//  - Compact floating grid overlay; does NOT cover the full screen
//  - Dynamic column count based on available width
//  - Works in skins / legacy UIKit controller layout
//  - Retrowave neon aesthetic consistent with RetroMenuView
//  - iOS and tvOS compatible
//

import SwiftUI
import PVCoreBridge
import PVLogging
import PVLibrary
import PVSettings
import PVThemes
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// MARK: - PauseTileMenuView

/// Compact tile/grid pause overlay that floats over the game screen.
/// Enabled when the `pauseTileMenu` feature flag is on; otherwise `PVGameMenuOverlay`
/// falls back to the classic `RetroMenuView`.
struct PauseTileMenuView: View {
    let emulatorVC: PVEmulatorViewController
    let dismissAction: (Bool) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    // MARK: Sheet state

    @State private var showingSaveStateBrowser = false
    @State private var showingScreenshotBrowser = false

    // MARK: Size class / orientation

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    #if os(iOS)
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation
    #endif

    private var isLandscape: Bool {
        #if os(iOS)
        if horizontalSizeClass == .regular && verticalSizeClass == .compact { return true }
        return orientation.isLandscape
        #else
        return true
        #endif
    }

    private var palette: UXThemePalette { themeManager.currentPalette }

    // MARK: - Tile sections

    private var primaryTiles: [PauseMenuTile] {
        var tiles: [PauseMenuTile] = []
        let supportsSaveStates = emulatorVC.core.supportsSaveStates
        let hasSave: Bool = {
            guard let game = emulatorVC.game, !game.isInvalidated else { return false }
            return !game.saveStates.isEmpty
        }()
        let supportsCheatCodes = (emulatorVC.core as? GameWithCheat)?.supportsCheatCode == true
        let shouldSave = shouldSaveOnQuit

        tiles.append(PauseMenuTile(
            id: "resume",
            icon: "play.fill",
            label: String(localized: "Resume"),
            colorKey: .green
        ))

        tiles.append(PauseMenuTile(
            id: "saveState",
            icon: "square.and.arrow.down",
            label: String(localized: "Save State"),
            isEnabled: supportsSaveStates,
            colorKey: .cyan
        ))

        tiles.append(PauseMenuTile(
            id: "loadState",
            icon: "arrowshape.turn.up.left",
            label: String(localized: "Quick Load"),
            isEnabled: supportsSaveStates && hasSave,
            colorKey: .blue
        ))

        tiles.append(PauseMenuTile(
            id: "browseSaves",
            icon: "list.bullet.rectangle.portrait",
            label: String(localized: "Browse Saves"),
            isEnabled: supportsSaveStates,
            colorKey: .purple
        ))

        tiles.append(PauseMenuTile(
            id: "reset",
            icon: "arrow.counterclockwise",
            label: String(localized: "Reset"),
            colorKey: .orange
        ))

        tiles.append(PauseMenuTile(
            id: "cheats",
            icon: "wand.and.stars",
            label: String(localized: "Cheats"),
            isEnabled: supportsCheatCodes,
            colorKey: .purple
        ))

        tiles.append(PauseMenuTile(
            id: "gameInfo",
            icon: "info.circle",
            label: String(localized: "Game Info"),
            colorKey: .blue
        ))

        #if os(iOS) || targetEnvironment(macCatalyst)
        tiles.append(PauseMenuTile(
            id: "screenshot",
            icon: "camera",
            label: String(localized: "Screenshot"),
            colorKey: .yellow
        ))
        tiles.append(PauseMenuTile(
            id: "screenshots",
            icon: "photo.on.rectangle",
            label: String(localized: "Screenshots"),
            colorKey: .yellow
        ))
        #endif

        if shouldSave {
            tiles.append(PauseMenuTile(
                id: "saveQuit",
                icon: "square.and.arrow.down.on.square",
                label: String(localized: "Save & Quit"),
                colorKey: .cyan
            ))
        }

        tiles.append(PauseMenuTile(
            id: "quit",
            icon: "xmark.circle",
            label: shouldSave ? String(localized: "Quit (No Save)") : String(localized: "Quit Game"),
            colorKey: .pink
        ))

        return tiles
    }

    // MARK: - Tile action dispatcher

    private func handle(_ tile: PauseMenuTile) {
        guard tile.isEnabled else { return }
        #if !os(tvOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        switch tile.id {
        case "resume":
            dismissAction(true)
        case "saveState":
            let screenshot = emulatorVC.captureScreenshot()
            Task { @MainActor in
                do {
                    try await emulatorVC.createNewSaveState(auto: false, screenshot: screenshot)
                } catch {
                    ELOG("Tile menu save state error: \(error.localizedDescription)")
                }
                dismissAction(true)
            }
        case "loadState":
            guard let game = emulatorVC.game, !game.isInvalidated,
                  let mostRecent = game.saveStates.sorted(byKeyPath: "date", ascending: false).first else { return }
            dismissAction(false)
            Task { @MainActor [weak emulatorVC = emulatorVC] in
                await emulatorVC?.loadSaveState(mostRecent)
            }
        case "browseSaves":
            showingSaveStateBrowser = true
        case "reset":
            dismissAction(true)
            emulatorVC.core.resetEmulation()
        case "cheats":
            dismissForSubSheetThen { self.emulatorVC.showCheatsMenu() }
        case "gameInfo":
            dismissForSubSheetThen { self.emulatorVC.showMoreInfo() }
        case "screenshot":
            dismissAction(true)
            emulatorVC.takeScreenshot()
        case "screenshots":
            showingScreenshotBrowser = true
        case "saveQuit":
            dismissAction(false)
            let image = emulatorVC.captureScreenshot()
            Task { @MainActor in
                do {
                    try await emulatorVC.createNewSaveState(auto: true, screenshot: image)
                    await emulatorVC.quit(optionallySave: false)
                } catch {
                    ELOG("Tile menu save & quit error: \(error.localizedDescription)")
                }
            }
        case "quit":
            dismissAction(false)
            Task { @MainActor in
                await emulatorVC.quit(optionallySave: false)
            }
        default:
            break
        }
    }

    private func dismissForSubSheetThen(_ action: @escaping () -> Void) {
        emulatorVC.dismissNav(resumeEmulation: false, completion: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action() }
        })
    }

    // MARK: - Layout helpers

    /// Column count driven by available horizontal space.
    private func columnCount(for width: CGFloat) -> Int {
        #if os(tvOS)
        return 5
        #else
        if width >= 600 { return 4 }
        if width >= 400 { return 3 }
        return 2
        #endif
    }

    private var panelMaxWidth: CGFloat {
        #if os(tvOS)
        return 640
        #else
        return isLandscape ? 520 : 380
        #endif
    }

    // MARK: - Subviews

    private func tileView(for tile: PauseMenuTile) -> some View {
        let accentColor = color(for: tile.colorKey)
        let opacity: Double = tile.isEnabled ? 1.0 : 0.35

        return Button {
            handle(tile)
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tile.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(accentColor)
                        .shadow(color: accentColor.opacity(0.8), radius: 6, x: 0, y: 0)
                        .frame(width: 40, height: 40)

                    if let badge = tile.badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(accentColor)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -6)
                    }
                }

                Text(tile.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor.opacity(0.12))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(accentColor.opacity(0.45), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(TileButtonStyle())
        .opacity(opacity)
        .disabled(!tile.isEnabled)
        #if os(tvOS)
        .focusable()
        #endif
    }

    private func color(for key: PauseMenuTileColor) -> Color {
        switch key {
        case .green: return .retroGreen
        case .orange: return .retroOrange
        case .blue: return .retroBlue
        case .purple: return .retroPurple
        case .pink: return .retroPink
        case .cyan: return .retroCyan
        case .yellow: return .retroYellow
        case .gray: return .gray
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.black.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.retroPurple.opacity(0.7), .retroPink.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed game background — tapping it resumes
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { dismissAction(true) }

                // Floating tile panel
                let cols = columnCount(for: min(geo.size.width, panelMaxWidth) - 32)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: cols)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Panel title
                        Text(String(localized: "GAME MENU"))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(2)
                            .padding(.top, 4)

                        // Tile grid
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(primaryTiles) { tile in
                                tileView(for: tile)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    }
                    .padding(16)
                }
                .background(panelBackground)
                .frame(maxWidth: panelMaxWidth)
                .frame(maxHeight: geo.size.height * 0.75)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .retroPurple.opacity(0.3), radius: 20, x: 0, y: 0)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .sheet(isPresented: $showingSaveStateBrowser) {
            PauseMenuSaveStateBrowserView(emulatorVC: emulatorVC) { stateToLoad in
                showingSaveStateBrowser = false
                guard let state = stateToLoad else { return }
                dismissAction(false)
                Task { @MainActor [weak emulatorVC = emulatorVC] in
                    await emulatorVC?.loadSaveState(state)
                }
            }
        }
        .sheet(isPresented: $showingScreenshotBrowser) {
            PauseMenuScreenshotBrowserView(emulatorVC: emulatorVC) {
                showingScreenshotBrowser = false
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientation = UIDevice.current.orientation
        }
        .onAppear {
            orientation = UIDevice.current.orientation
        }
        #endif
        #if os(tvOS)
        .onExitCommand { dismissAction(true) }
        #endif
    }

    // MARK: - Helpers

    private var shouldSaveOnQuit: Bool {
        guard let game = emulatorVC.game, !game.isInvalidated else { return false }
        let twoMinutes: TimeInterval = 120
        let oneMinute: TimeInterval = 60
        let minimumPlayTime: TimeInterval = 60 * 2
        var result = Defaults[.autoSave]
        result = result && abs((game.lastPlayed ?? Date()).timeIntervalSinceNow) > minimumPlayTime
        result = result && (game.lastAutosaveAge ?? twoMinutes) > oneMinute
        result = result && abs((!game.isInvalidated ? game.saveStates.sorted(byKeyPath: "date", ascending: true).last?.date.timeIntervalSinceNow : nil) ?? twoMinutes) > oneMinute
        result = result && emulatorVC.core.supportsSaveStates
        return result
    }
}

// MARK: - TileButtonStyle

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
