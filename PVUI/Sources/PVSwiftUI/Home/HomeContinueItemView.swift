//
//  HomeContinueItemView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

import SwiftUI
import PVThemes
import PVUIBase
import RealmSwift
import PVLogging

/// Optimized HomeContinueItemView with cached image loading and efficient retro effects.
///
/// When the save is part of an autosave stack (`model.isStacked == true`), the card renders
/// ghost cards behind it to convey depth, and a badge shows how many autosaves are hidden.
/// Long-pressing the card (or tapping the badge) opens `AutoSaveFilmstripView` to browse the autosave timeline.
@available(iOS 15, tvOS 15, *)
struct HomeContinueItemView: SwiftUI.View {
    // Use computed properties instead of @ObservedRealmObject to reduce re-renders
    let saveStateId: String
    let gameTitle: String?
    let imageURL: URL?
    let isInvalidated: Bool

    @ObservedObject private var themeManager = ThemeManager.shared
    let height: CGFloat
    let hideSystemLabel: Bool
    var action: () -> Void
    let isFocused: Bool
    weak var rootDelegate: PVRootDelegate?

    /// All saves in this session (representative first, then stacked, newest → oldest).
    /// Used to populate the filmstrip when the user expands the stack.
    private let allSavesInSession: [ContinueItemModel]
    /// Number of autosaves collapsed behind this representative card.
    private let stackDepth: Int

    @State private var showDeleteAlert = false
    @State private var isVisible = false
    @State private var showFilmstrip = false

    /// Constants for CRT and retrowave effects
    internal enum CRTEffects {
        // Scanline effects
        static let scanlineOpacity: CGFloat = 0.3
        static let lcdOpacity: CGFloat = 0.1

        // Image presentation
        static let zoomFactor: CGFloat = 1.15
    }

    /// Stack visual constants.
    private enum StackLayout {
        /// Pixel offset between adjacent ghost cards.
        static let cardOffset: CGFloat = 4
        /// Extra padding around the ZStack to accommodate ghost card overhang.
        static let overhangPadding: CGFloat = 8
    }

    /// Convenience initializer that extracts data from ContinueItemModel.
    init(model: ContinueItemModel,
         height: CGFloat,
         hideSystemLabel: Bool,
         action: @escaping () -> Void,
         isFocused: Bool,
         rootDelegate: PVRootDelegate?) {
        self.saveStateId = model.id
        self.gameTitle = model.gameTitle
        self.imageURL = model.imageURL
        self.isInvalidated = false
        self.height = height
        self.hideSystemLabel = hideSystemLabel
        self.action = action
        self.isFocused = isFocused
        self.rootDelegate = rootDelegate
        self.resolver = model.resolver
        self.stackDepth = model.stackDepth
        // Build the full list for the filmstrip: representative (without its own stackedSaves
        // to avoid recursion) followed by all stacked saves.
        let representative = ContinueItemModel(
            id: model.id,
            gameTitle: model.gameTitle,
            imageURL: model.imageURL,
            date: model.date,
            systemIdentifier: model.systemIdentifier,
            isAutosave: model.isAutosave,
            stackedSaves: [],
            resolver: model.resolver
        )
        self.allSavesInSession = [representative] + model.stackedSaves
    }

    private let resolver: () -> PVSaveState?

    var body: some SwiftUI.View {
        if !isInvalidated {
            ZStack(alignment: .topTrailing) {
                // Ghost cards conveying stack depth (rendered behind the main card).
                if stackDepth >= 3 {
                    ghostCard(depthIndex: 2)
                }
                if stackDepth >= 2 {
                    ghostCard(depthIndex: 1)
                }

                // Main interactive card.
                mainCard
            }
            // Accommodate the ghost card overhang so cards aren't clipped.
            .padding(.trailing, stackDepth >= 3 ? StackLayout.overhangPadding : (stackDepth >= 2 ? StackLayout.overhangPadding / 2 : 0))
            .padding(.bottom, stackDepth >= 3 ? StackLayout.overhangPadding : (stackDepth >= 2 ? StackLayout.overhangPadding / 2 : 0))
            .sheet(isPresented: $showFilmstrip) {
                if #available(iOS 16, tvOS 16, *) {
                    filmstripSheet
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                } else {
                    filmstripSheet
                }
            }
        }
    }

    // MARK: - Ghost Cards

    /// A non-interactive background card at the given depth (1 = closest, 2 = furthest).
    @ViewBuilder
    private func ghostCard(depthIndex: Int) -> some View {
        let offset = CGFloat(depthIndex) * StackLayout.cardOffset
        let opacity = depthIndex == 1 ? 0.50 : 0.28
        let scale = depthIndex == 1 ? 0.97 : 0.94

        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.4),
                        RetroTheme.retroBlue.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: height)
            .scaleEffect(scale, anchor: .center)
            .offset(x: offset, y: offset)
            .opacity(opacity)
            .allowsHitTesting(false)
    }

    // MARK: - Main Card

    private var mainCard: some View {
        Button {
            action()
        } label: {
            ZStack(alignment: .top) {
                // Screenshot / artwork
                CachedAsyncImageView(
                    url: imageURL,
                    fallbackImage: UIImage.missingArtworkImage(gameTitle: gameTitle ?? "Deleted", ratio: 1),
                    height: height,
                    zoomFactor: CRTEffects.zoomFactor
                )
                .overlay(
                    Group {
                        if isVisible {
                            if isFocused {
                                OptimizedRetroEffects()
                            } else {
                                LightweightRetroEffects()
                            }
                        }
                    }
                )
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: RetroPauseChrome.menuCellCornerRadius()))
            // Focus border aligned with `PauseTileMenuView` cell stroke when focused.
            .overlay(
                RoundedRectangle(cornerRadius: RetroPauseChrome.menuCellCornerRadius())
                    .strokeBorder(
                        (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color.retroCyan)
                            .opacity(isFocused ? RetroPauseChrome.menuCellStrokeOpacityFocused : 0),
                        lineWidth: isFocused ? RetroPauseChrome.menuCellStrokeWidthFocused : 0
                    )
            )
            .shadow(
                color: isFocused
                    ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? Color.retroCyan)
                        .opacity(RetroPauseChrome.menuCellFocusShadowOpacity)
                    : Color.clear,
                radius: isFocused ? RetroPauseChrome.menuCellFocusShadowRadius : 0,
                x: 0,
                y: 3
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .brightness(isFocused ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        // Long-press to expand the session filmstrip.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    guard stackDepth > 1 else { return }
                    triggerFilmstripExpansion()
                }
        )
        .contextMenu {
            Button { action() } label: {
                Label("Load Save", systemImage: "play.fill")
            }

            // Expand stacked saves if present
            if stackDepth > 1 {
                Button {
                    triggerFilmstripExpansion()
                } label: {
                    Label(
                        "View \(stackDepth) Autosaves…",
                        systemImage: "square.stack.3d.up"
                    )
                }
            }

            if let continueState = resolver(),
               let game = continueState.game, !game.isInvalidated {
                Button {
                    Task.detached { @MainActor in
                        SceneCoordinator.shared.launchGame(game.freeze())
                    }
                } label: {
                    Label("Load Game", systemImage: "gamecontroller")
                }

                Button {
                    Task.detached { @MainActor in
                        rootDelegate?.root_showContinuesManagement(game)
                    }
                } label: {
                    Label("Manage Game Save States", systemImage: "clock.arrow.circlepath")
                }

                if let system = game.system {
                    Button {
                        Task.detached { @MainActor in
                            rootDelegate?.root_showContinuesManagement(forSystemID: system.identifier)
                        }
                    } label: {
                        Label("Manage All \(system.shortName) Save States", systemImage: "folder")
                    }
                }
            }

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete Save State", systemImage: "trash")
            }
        }
        .uiKitAlert(
            "Delete Save State",
            message: "Are you sure you want to delete this save state for \(gameTitle ?? "Deleted")?",
            isPresented: $showDeleteAlert,
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "Delete", style: .destructive) { _ in
                if let continueState = RomDatabase.sharedInstance.object(ofType: PVSaveState.self, wherePrimaryKeyEquals: saveStateId) {
                    do {
                        try RomDatabase.sharedInstance.delete(saveState: continueState)
                    } catch {
                        ELOG("Failed to delete save state: \(error.localizedDescription)")
                    }
                }
                showDeleteAlert = false
            }
            UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                showDeleteAlert = false
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        // Stack badge is overlaid as a sibling of the Button (not nested inside it).
        // Nested Buttons in SwiftUI don't receive taps reliably; this overlay approach
        // keeps the badge as a separate hit-testing target with its own tap area.
        .overlay(alignment: .topTrailing) {
            if stackDepth > 1 {
                stackBadge
                    .padding(6)
            }
        }
    }

    // MARK: - Stack Badge

    /// Neon pill badge in the corner showing "+N" hidden saves.
    private var stackBadge: some View {
        Button {
            triggerFilmstripExpansion()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 8, weight: .bold))
                Text("+\(stackDepth - 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                RetroTheme.retroPurple
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(
                        color: (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.7),
                        radius: 4
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filmstrip Sheet

    @available(iOS 15, tvOS 15, *)
    private var filmstripSheet: some View {
        AutoSaveFilmstripView(
            gameTitle: gameTitle,
            allSaves: allSavesInSession,
            onSelect: { selectedSave in
                showFilmstrip = false
                if let saveState = selectedSave.resolver() {
                    Task.detached { @MainActor in
                        SceneCoordinator.shared.launchSaveState(saveState.freeze(), core: saveState.core?.freeze())
                    }
                }
            }
        )
    }

    // MARK: - Helpers

    private func triggerFilmstripExpansion() {
        #if !os(tvOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        showFilmstrip = true
    }
}
