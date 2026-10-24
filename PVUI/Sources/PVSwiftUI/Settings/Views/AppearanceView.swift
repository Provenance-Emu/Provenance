//
//  AppearanceView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import Combine
import Defaults
import PVSettings
import PVThemes
import PVUIBase
#if canImport(FreemiumKit)
import FreemiumKit
#endif

struct AppearanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Default(.showGameTitles) var showGameTitles
    @Default(.scrollLongGameTitles) var scrollLongGameTitles
    @Default(.showRecentGames) var showRecentGames
    @Default(.showSearchbar) var showSearchbar
    @Default(.showRecentSaveStates) var showRecentSaveStates
    @Default(.showAutoSavesInRecents) var showAutoSavesInRecents
    @Default(.showGameBadges) var showGameBadges
    @Default(.showFavorites) var showFavorites
    @Default(.missingArtworkStyle) private var missingArtworkStyle
#if os(tvOS) || targetEnvironment(macCatalyst)
    @Default(.largeGameArt) var largeGameArt
#endif

    var body: some View {
        ZStack {
            // Retrowave background
            Color.black.edgesIgnoringSafeArea(.all)

            // Grid background
            RetroGrid()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.3)

            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Title with retrowave styling
                    Text("APPEARANCE")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)

                    // Display Options section with retrowave styling
                    VStack(alignment: .leading, spacing: 16) {
                        RetroSettingsSectionHeader(icon: "eye", title: "Display Options")

                        // Toggle options
                        VStack(spacing: 12) {
                            ThemedToggle(isOn: $showGameTitles) {
                                SettingsRow(title: "Show Game Titles",
                                            subtitle: "Display game titles under artwork.",
                                            icon: .sfSymbol("textformat"),
                                            showChevron: false)
                            }
                            .padding(.vertical, 4)

                            ThemedToggle(isOn: $showSearchbar) {
                                SettingsRow(title: "Show Search Bar",
                                            subtitle: "Show search bar for quick game searching.",
                                            icon: .sfSymbol("magnifyingglass"),
                                            showChevron: false)
                            }
                            .padding(.vertical, 4)

                            ThemedToggle(isOn: $scrollLongGameTitles) {
                                SettingsRow(title: "Scroll Long Titles",
                                            subtitle: "Animate long game titles in the library; off uses a single line with ellipsis.",
                                            icon: .sfSymbol("text.line.first.and.arrowtriangle.forward"),
                                            showChevron: false)
                            }
                            .padding(.vertical, 4)

                            ThemedToggle(isOn: $showRecentGames) {
                                SettingsRow(title: "Show Recently Played Games",
                                            subtitle: "Display recently played games section.",
                                            icon: .sfSymbol("clock"),
                                            showChevron: false)
                            }
                            .padding(.vertical, 4)

                            ThemedToggle(isOn: $showRecentSaveStates) {
                                SettingsRow(title: "Show Recent Save States",
                                            subtitle: "Display recent save states section.",
                                            icon: .sfSymbol("bookmark"),
                                            showChevron: false)
                            }
                            .padding(.vertical, 4)

                            ThemedToggle(isOn: $showAutoSavesInRecents) {
                                SettingsRow(title: "Show All Auto-Saves in Recent Saves",
                                            subtitle: "When off, only the latest auto-save per game is shown to reduce clutter.",
                                            icon: .sfSymbol("clock.badge.checkmark"),
                                            showChevron: false)
                            }
                            .padding(.vertical, 4)

                            ThemedToggle(isOn: $showFavorites) {
                                SettingsRow(title: "Show Favorites",
                                            subtitle: "Display favorites section.",
                                            icon: .sfSymbol("star"),
                                            showChevron: false)
                            }
                            .padding(.vertical, 4)

                            ThemedToggle(isOn: $showGameBadges) {
                                SettingsRow(title: "Show Game Badges",
                                            subtitle: "Display badges on game artwork.",
                                            icon: .sfSymbol("rosette"),
                                            showChevron: false)
                            }

#if os(tvOS) || targetEnvironment(macCatalyst)
                            ThemedToggle(isOn: $largeGameArt) {
                                SettingsRow(title: "Show Large Game Artwork",
                                            subtitle: "Use larger artwork in game grid.",
                                            icon: .sfSymbol("rectangle.expand.vertical"),
                                            showChevron: false)
                            }
#endif
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            RetroSettingsSectionHeader(icon: "photo.artframe", title: "Missing Artwork")

                            // Add the new navigation link wrapped in PaidFeatureView
                            PaidFeatureView {
                                NavigationLink(destination: MissingArtworkStyleView()) {
                                    SettingsRow(
                                        title: "Missing Artwork Style",
                                        subtitle: "Current style: \(missingArtworkStyle.description)",
                                        icon: .sfSymbol("photo.artframe")
                                    )
                                }
                                #if os(tvOS)
                                .retroFocusButtonStyle(showBorder: false)
                                #endif
                            } lockedView: {
                                SettingsRow(
                                    title: "Missing Artwork Style",
                                    subtitle: "Unlock to customize missing artwork style",
                                    icon: .sfSymbol("lock.fill"),
                                    showChevron: false
                                )
                            }
                            .freemiumKitColorReset()

                            // Preview of current style
                            if !missingArtworkStyle.description.isEmpty {
                                HStack {
                                    Spacer()
                                    Image(uiImage: UIImage.missingArtworkImage(
                                        gameTitle: "Preview",
                                        ratio: 1.0,
                                        pattern: missingArtworkStyle
                                    ))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 200, height: 200)
                                    .cornerRadius(8)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .navigationTitle("Appearance")
                }
                .tvOSSettingsHorizontalPadding()
                #if os(tvOS)
                .focusSection()
                .onExitCommand { dismiss() }
                #endif
                .settingsSubpageTracking()
            }
        }
    }
}

/// Lets the user pick the style of the placeholder shown for games without cover artwork.
private struct MissingArtworkStyleView: View {
    @Default(.missingArtworkStyle) private var selectedStyle
    @Environment(\.dismiss) private var dismiss

    /// Animation states
    @State private var selectedPreviewScale: CGFloat = 1.0
    @State private var previewRotation: Double = 0
    @State private var showingFullScreenPreview = false

    private let previewTitle = "PRESS START!"

    private static let selectionAnimation = Animation.spring(response: 0.3, dampingFraction: 0.6)
    private static let selectionAnimationDuration: TimeInterval = 0.3
    private static let sectionSpacing: CGFloat = 24
    private static let rowSpacing: CGFloat = 12
    private static let previewCornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            RetroSettingsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                    currentStyleSection
                    availableStylesSection
                }
                .tvOSSettingsHorizontalPadding()
                #if os(tvOS)
                .padding(.vertical, 24)
                #else
                .padding()
                #endif
            }
        }
        .navigationTitle("Missing Artwork Style")
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
        .sheet(isPresented: $showingFullScreenPreview) {
            FullScreenPreview(style: selectedStyle, previewTitle: previewTitle)
                #if os(tvOS)
                .settingsSheetDetachedFromSubpageDepth()
                #endif
        }
    }

    // MARK: - Sections

    private var currentStyleSection: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            RetroSettingsSectionHeader(icon: "photo", title: "Current Style")

            // Interactive preview of current style
            Button {
                showingFullScreenPreview = true
            } label: {
                VStack(spacing: Self.rowSpacing) {
                    Image(uiImage: UIImage.missingArtworkImage(
                        gameTitle: previewTitle,
                        ratio: 1.6,
                        pattern: selectedStyle
                    ))
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                    .cornerRadius(Self.previewCornerRadius)
                    .rotation3DEffect(.degrees(previewRotation), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(selectedPreviewScale)
                    .overlay(
                        RoundedRectangle(cornerRadius: Self.previewCornerRadius)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.retroPink.opacity(0.4), radius: 10, x: 0, y: 5)

                    #if os(tvOS)
                    Text("Select to preview full screen")
                        .font(.retroSettingsRowSubtitle)
                        .foregroundColor(.secondary)
                    #else
                    Text("Tap to preview full screen")
                        .font(.retroSettingsRowSubtitle)
                        .foregroundColor(.secondary)
                    #endif
                }
                .frame(maxWidth: .infinity)
                .padding(Self.rowSpacing)
            }
            .retroFocusButtonStyle(focusScale: 1.04, focusBorderWidth: 2.5, cornerRadius: Self.previewCornerRadius)

            Text("These retro-styled placeholders appear when a game is missing its cover artwork.")
                .font(.retroSettingsRowSubtitle)
                .foregroundColor(.secondary)
        }
    }

    private var availableStylesSection: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            RetroSettingsSectionHeader(icon: "square.grid.2x2", title: "Available Styles")

            ForEach(RetroTestPattern.allCases, id: \.self) { style in
                StyleOptionRow(
                    style: style,
                    isSelected: selectedStyle == style,
                    onSelect: { select(style) }
                )
            }
        }
    }

    // MARK: - Selection

    private func select(_ style: RetroTestPattern) {
        withAnimation(Self.selectionAnimation) {
            selectedStyle = style
            // Trigger preview animations
            selectedPreviewScale = 1.1
            previewRotation = 360

            // Reset animations
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.selectionAnimationDuration) {
                withAnimation(Self.selectionAnimation) {
                    selectedPreviewScale = 1.0
                    previewRotation = 0
                }
            }

            // Haptic feedback
#if !os(tvOS)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
#endif
        }
    }
}

/// Row view for each style option, drawn like `RetroSettingsPickerRow` with a thumbnail.
private struct StyleOptionRow: View {
    let style: RetroTestPattern
    let isSelected: Bool
    let onSelect: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    #if os(tvOS)
    private static let thumbnailSize: CGFloat = 100
    #else
    private static let thumbnailSize: CGFloat = 80
    #endif
    private static let rowCornerRadius: CGFloat = 10
    private static let thumbnailCornerRadius: CGFloat = 8

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Preview of the style
                Image(uiImage: UIImage.missingArtworkImage(
                    gameTitle: "DEMO",
                    ratio: 1.0,
                    pattern: style
                ))
                .resizable()
                .scaledToFit()
                .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                .cornerRadius(Self.thumbnailCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Self.thumbnailCornerRadius)
                        .strokeBorder(isSelected ? Color.retroPink : Color.clear, lineWidth: 2)
                )

                // Style description
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.description)
                        .font(.retroSettingsLabel)
                        .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                            ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    Text(style.subtitle)
                        .font(.retroSettingsRowSubtitle)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.retroBlue)
                        .imageScale(.large)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Self.rowCornerRadius)
                    .fill(isSelected ? Color.retroBlue.opacity(0.12) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Self.rowCornerRadius)
                            .strokeBorder(
                                isSelected ? Color.retroBlue.opacity(0.5) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
        }
        .retroFocusButtonStyle(focusScale: 1.04, focusBorderWidth: 2.5, cornerRadius: Self.rowCornerRadius)
    }
}

/// Full screen preview view
private struct FullScreenPreview: View {
    let style: RetroTestPattern
    let previewTitle: String
    @Environment(\.dismiss) private var dismiss

    #if os(tvOS)
    private static let doneButtonWidth: CGFloat = 400
    #endif

    var body: some View {
        #if os(tvOS)
        previewContent
            .onExitCommand { dismiss() }
        #else
        NavigationStack {
            previewContent
                .navigationTitle("Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
        #endif
    }

    private var previewContent: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 40) {
                Image(uiImage: UIImage.missingArtworkImage(
                    gameTitle: previewTitle,
                    ratio: 1.6,
                    pattern: style
                ))
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(0.3), radius: 20)

                #if os(tvOS)
                RetroSettingsActionButton(title: "Done", icon: "checkmark", color: .retroBlue) {
                    dismiss()
                }
                .frame(width: Self.doneButtonWidth)
                #endif
            }
        }
    }
}
