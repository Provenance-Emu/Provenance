//
//  PauseMenuBrowserViews.swift
//  PVUI
//
//  Screenshot and save-state browsers presented from the pause menu.
//

import SwiftUI
import UIKit
import PVLibrary
import PVLogging
import PVSettings
import PVThemes

/// Fixed thumbnail frames used by the pause-menu browsers. These double as the
/// decode budget for `DownsampledFileImage`, so they must match the `.frame`
/// they are drawn in.
enum PauseMenuThumbnailSize {
    /// Screenshot browser row.
    static let screenshotRow = CGSize(width: 96, height: 72)
    /// Save-state row.
    static let saveStateRow = CGSize(width: 72, height: 54)
}

// MARK: - Pause-menu screenshot browser

/// Screenshot gallery presented as a sheet from the pause menu.
///
/// Shows all captured screenshots for the current game with share and delete
/// actions. The auto-add-to-Photo-Library toggle maps to the
/// `saveScreenshotsToPhotoLibrary` setting.
@MainActor
struct PauseMenuScreenshotBrowserView: View {
    let emulatorVC: PVEmulatorViewController
    let onDismiss: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var screenshots: [PVImageFile] = []
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @Default(.saveScreenshotsToPhotoLibrary) private var saveToPhotos

    private var palette: UXThemePalette { themeManager.currentPalette }

    var body: some View {
        NavigationView {
            Group {
                if screenshots.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.4))
                        Text(String(localized: "retro_menu.saves.no_screenshots", bundle: .module))
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.6))
                        Text(String(localized: "retro_menu.saves.screenshots_hint", bundle: .module))
                            .font(.caption)
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Auto-save toggle at the top
                        Toggle(isOn: $saveToPhotos) {
                            Label(String(localized: "retro_menu.saves.auto_save_to_photos", bundle: .module), systemImage: "photo.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(palette.gameLibraryText.swiftUIColor)
                        }
                        .tint(palette.defaultTintColor.swiftUIColor)
                        .listRowBackground(
                            (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(0.8)
                        )

                        ForEach(screenshots, id: \.partialPath) { shot in
                            screenshotRow(shot)
                                .listRowBackground(
                                    (palette.settingsCellBackground?.swiftUIColor ?? Color(palette.gameLibraryBackground)).opacity(0.8)
                                )
                        }
                        .onDelete { indexSet in
                            for index in indexSet { deleteScreenshot(screenshots[index]) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(palette.gameLibraryBackground))
            .navigationTitle("Screenshots")
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { onDismiss() }.font(.headline)
                }
            }
#endif
        }
#if !os(tvOS)
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
#endif
        .onAppear { reload() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Row

    @ViewBuilder
    private func screenshotRow(_ shot: PVImageFile) -> some View {
        HStack(spacing: 12) {
            // Thumbnail — downsampled at decode time. Screenshots are full
            // device resolution (~12 MB decoded); this row draws them at 96x72.
            DownsampledFileImage(url: shot.url, pointSize: PauseMenuThumbnailSize.screenshotRow) {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.4))
            }
            .frame(width: PauseMenuThumbnailSize.screenshotRow.width, height: PauseMenuThumbnailSize.screenshotRow.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(palette.defaultTintColor.swiftUIColor.opacity(0.2), lineWidth: 0.5)
            )

            // Filename / date
            VStack(alignment: .leading, spacing: 4) {
                Text(shot.url?.deletingPathExtension().lastPathComponent ?? shot.partialPath)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(palette.gameLibraryText.swiftUIColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            // Share button
            Button {
                if let url = shot.url, let img = UIImage(contentsOfFile: url.path) {
                    shareItems = [img]
                    showingShareSheet = true
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
                    .foregroundColor(palette.defaultTintColor.swiftUIColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func reload() {
        screenshots = Array(emulatorVC.game.screenShots.sorted(byKeyPath: "partialPath", ascending: false))
    }

    private func deleteScreenshot(_ shot: PVImageFile) {
        do {
            if let url = shot.url { try? FileManager.default.removeItem(at: url) }
            try RomDatabase.sharedInstance.delete(shot)
            reload()
        } catch {
            ELOG("Failed to delete screenshot: \(error)")
        }
    }
}

// MARK: - Pause-menu save state browser

/// Lightweight SwiftUI save-state picker presented as a sheet from the pause menu.
///
/// The caller provides an `onAction` closure that receives an optional frozen `PVSaveState`:
/// - `nil` → user dismissed without loading (sheet can close, pause menu stays open)
/// - non-nil → load the state (sheet should close AND pause menu should dismiss)
///
/// This view intentionally stays within the app's SwiftUI stack so that
/// dismissing it (without loading) returns the user to the pause menu rather than
/// abandoning it entirely.
@MainActor
struct PauseMenuSaveStateBrowserView: View {
    let emulatorVC: PVEmulatorViewController
    /// Called with a frozen `PVSaveState` to load, or `nil` to just close the sheet.
    let onAction: (PVSaveState?) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var saveStates: [PVSaveState] = []

    private var palette: UXThemePalette { themeManager.currentPalette }

    var body: some View {
        NavigationStack {
            Group {
                if saveStates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 48))
                            .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.4))
                        Text(String(localized: "retro_menu.saves.no_save_states", bundle: .module))
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.6))
                        Text(String(localized: "retro_menu.saves.save_states_hint", bundle: .module))
                            .font(.caption)
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(saveStates, id: \.id) { state in
                            saveStateRow(state)
                                .listRowBackground(Color.clear)
                                #if !os(tvOS)
                                .listRowSeparator(.hidden)
                                #endif
                                .listRowInsets(EdgeInsets(top: 4, leading: RetroPauseChrome.chromeInset,
                                                         bottom: 4, trailing: RetroPauseChrome.chromeInset))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                deleteSaveState(saveStates[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                    #if !os(tvOS)
                    .scrollContentBackground(.hidden)
                    #endif
                    .scrollIndicatorsFlash(onAppear: true)
                }
            }
            .background(Color(palette.gameLibraryBackground))
            .navigationTitle("Save States")
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        onAction(nil)
                    }
                    .font(.headline)
                }
            }
#endif
        }
        .onAppear { reload() }
        .preferredColorScheme(palette.dark ? .dark : .light)
    }

    // MARK: - Row

    @ViewBuilder
    private func saveStateRow(_ state: PVSaveState) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView(for: state)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if state.isAutosave {
                        Label("Auto", systemImage: "clock.badge.checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.7))
                    }
                    Text(state.date, style: .date)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(palette.gameLibraryText.swiftUIColor)
                }
                HStack(spacing: 4) {
                    Text(state.date, style: .time)
                        .font(.system(size: 11, design: .monospaced))
                    Text("·")
                    (Text(state.date, style: .relative) + Text(" ago"))
                        .font(.system(size: 11))
                }
                .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.55))

                if let coreName = state.core?.projectName {
                    Text(coreName)
                        .font(.system(size: 10))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.5))
                }
            }

            Spacer()

            // Load button
            Button {
                let frozen = state.isFrozen ? state : state.freeze()
                onAction(frozen)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(palette.defaultTintColor.swiftUIColor)
            }
            .buttonStyle(.plain)
            .frame(minWidth: RetroPauseChrome.controlHeight, minHeight: RetroPauseChrome.controlHeight)
            .accessibilityLabel("Load save state")
        }
        .padding(RetroPauseChrome.chromeInset)
        .retroChromeSurface()
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private func thumbnailView(for state: PVSaveState) -> some View {
        /// Downsampled at decode time — save-state images are full device
        /// resolution and this draws them at 72x54.
        DownsampledFileImage(url: state.image?.url, pointSize: PauseMenuThumbnailSize.saveStateRow) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 22))
                .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.4))
        }
        .frame(width: PauseMenuThumbnailSize.saveStateRow.width, height: PauseMenuThumbnailSize.saveStateRow.height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(palette.defaultTintColor.swiftUIColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func reload() {
        guard let game = emulatorVC.game, !game.isInvalidated else {
            saveStates = []
            return
        }
        // Refresh the Realm to pick up writes from other threads/contexts
        // (e.g., registerSaveState which opens its own Realm instance)
        game.realm?.refresh()
        saveStates = Array(
            game.saveStates
                .sorted(byKeyPath: "date", ascending: false)
        )
    }

    private func deleteSaveState(_ state: PVSaveState) {
        do {
            try PVSaveState.delete(state)
            reload()
        } catch {
            ELOG("Failed to delete save state: \(error)")
        }
    }
}
