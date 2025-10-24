//
//  HomeContinueItemView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

import SwiftUI
import PVThemes
import RealmSwift

/// Optimized HomeContinueItemView with cached image loading and efficient retro effects
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

    @State private var showDeleteAlert = false
    @State private var isVisible = false

    /// Constants for CRT and retrowave effects
    internal enum CRTEffects {
        // Scanline effects
        static let scanlineOpacity: CGFloat = 0.3
        static let lcdOpacity: CGFloat = 0.1
        
        // Retrowave effects
        static let glowRadius: CGFloat = 4.0
        static let glowOpacity: CGFloat = 0.7
        static let borderWidth: CGFloat = 2.0

        // Image presentation
        static let zoomFactor: CGFloat = 1.15
    }
    
    /// Convenience initializer that extracts data from PVSaveState to reduce Realm observation overhead
    init(continueState: PVSaveState, height: CGFloat, hideSystemLabel: Bool, action: @escaping () -> Void, isFocused: Bool, rootDelegate: PVRootDelegate?) {
        self.saveStateId = continueState.id
        self.gameTitle = continueState.game?.title
        self.imageURL = continueState.image?.url
        self.isInvalidated = continueState.isInvalidated
        self.height = height
        self.hideSystemLabel = hideSystemLabel
        self.action = action
        self.isFocused = isFocused
        self.rootDelegate = rootDelegate
    }

    var body: some SwiftUI.View {
        if !isInvalidated {
            Button {
                action()
            } label: {
                ZStack(alignment: .top) {
                    // Use optimized cached async image loading
                    CachedAsyncImageView(
                        url: imageURL,
                        fallbackImage: UIImage.missingArtworkImage(gameTitle: gameTitle ?? "Deleted", ratio: 1),
                        height: height,
                        zoomFactor: CRTEffects.zoomFactor
                    )
                    .overlay(
                        // Use lightweight effects when not focused, full effects when focused
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
                .clipShape(Rectangle())
                // Retrowave-styled border with gradient and glow when focused
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            // Use AnyShapeStyle to handle different types
                            isFocused ?
                            // Gradient border when focused
                            AnyShapeStyle(LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink,
                                    RetroTheme.retroPurple,
                                    RetroTheme.retroBlue
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )) :
                            // No border when not focused
                            AnyShapeStyle(Color.clear),
                            lineWidth: isFocused ? CRTEffects.borderWidth : 0
                        )
                )
                // Add glow effect when focused
                .shadow(color: isFocused ? 
                        (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(CRTEffects.glowOpacity) : 
                        Color.clear, 
                        radius: CRTEffects.glowRadius)
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .brightness(isFocused ? 0.1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
            }
            .contextMenu {
                Button {
                    action()
                } label: {
                    Label("Load Save", systemImage: "play.fill")
                }

                // Context menu items that require Realm access - fetch fresh data
                if let continueState = RomDatabase.sharedInstance.object(ofType: PVSaveState.self, wherePrimaryKeyEquals: saveStateId),
                   let game = continueState.game, !game.isInvalidated {
                    Button {
                        Task.detached { @MainActor in
                            await rootDelegate?.root_load(
                                game,
                                sender: self,
                                core: nil,
                                saveState: nil
                            )
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
                    // Fetch fresh save state for deletion
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
            .onAppear {
                isVisible = true
            }
            .onDisappear {
                isVisible = false
            }
        }
    }
}
