//
//  AppearanceView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import Combine
import PVThemes
#if canImport(FreemiumKit)
import FreemiumKit
#endif

struct AppearanceView: View {
    @Default(.showGameTitles) var showGameTitles
    @Default(.showRecentGames) var showRecentGames
    @Default(.showRecentSaveStates) var showRecentSaveStates
    @Default(.showGameBadges) var showGameBadges
    @Default(.showFavorites) var showFavorites
    @Default(.missingArtworkStyle) private var missingArtworkStyle
#if os(tvOS) || targetEnvironment(macCatalyst)
    @Default(.largeGameArt) var largeGameArt
#endif

    var body: some View {
        Form {
            Section(header: Text("Display Options")) {
                ThemedToggle(isOn: $showGameTitles) {
                    SettingsRow(title: "Show Game Titles",
                              subtitle: "Display game titles under artwork.",
                              icon: .sfSymbol("textformat"))
                }

                ThemedToggle(isOn: $showRecentGames) {
                    SettingsRow(title: "Show Recently Played Games",
                              subtitle: "Display recently played games section.",
                              icon: .sfSymbol("clock"))
                }

                ThemedToggle(isOn: $showRecentSaveStates) {
                    SettingsRow(title: "Show Recent Save States",
                              subtitle: "Display recent save states section.",
                              icon: .sfSymbol("bookmark"))
                }

                ThemedToggle(isOn: $showFavorites) {
                    SettingsRow(title: "Show Favorites",
                              subtitle: "Display favorites section.",
                              icon: .sfSymbol("star"))
                }

                ThemedToggle(isOn: $showGameBadges) {
                    SettingsRow(title: "Show Game Badges",
                              subtitle: "Display badges on game artwork.",
                              icon: .sfSymbol("rosette"))
                }

                #if os(tvOS) || targetEnvironment(macCatalyst)
                ThemedToggle(isOn: $largeGameArt) {
                    SettingsRow(title: "Show Large Game Artwork",
                              subtitle: "Use larger artwork in game grid.",
                              icon: .sfSymbol("rectangle.expand.vertical"))
                }
                #endif
            }

            Section(header: Text("Missing Artwork")) {
                // Add the new navigation link wrapped in PaidFeatureView
                PaidFeatureView {
                    NavigationLink(destination: MissingArtworkStyleView()) {
                        SettingsRow(
                            title: "Missing Artwork Style",
                            subtitle: "Current style: \(missingArtworkStyle.description)",
                            icon: .sfSymbol("photo.artframe")
                        )
                    }
                } lockedView: {
                    SettingsRow(
                        title: "Missing Artwork Style",
                        subtitle: "Unlock to customize missing artwork style",
                        icon: .sfSymbol("lock.fill")
                    )
                }
                
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
}

//private struct AppearanceSection: View {
//    @Default(.showGameTitles) var showGameTitles
//    @Default(.showRecentGames) var showRecentGames
//    @Default(.showRecentSaveStates) var showRecentSaveStates
//    @Default(.showGameBadges) var showGameBadges
//    @Default(.showFavorites) var showFavorites
//
//    var body: some View {
//        Section(header: Text("Appearance")) {
//            ThemedToggle(isOn: $showGameTitles) {
//                SettingsRow(title: "Show Game Titles",
//                           subtitle: "Display game titles under artwork.",
//                           icon: .sfSymbol("text.below.photo"))
//            }
//            ThemedToggle(isOn: $showRecentGames) {
//                SettingsRow(title: "Show Recent Games",
//                           subtitle: "Display recently played games section.",
//                           icon: .sfSymbol("clock"))
//            }
//            ThemedToggle(isOn: $showRecentSaveStates) {
//                SettingsRow(title: "Show Recent Saves",
//                           subtitle: "Display recent save states section.",
//                           icon: .sfSymbol("clock.badge.checkmark"))
//            }
//            ThemedToggle(isOn: $showGameBadges) {
//                SettingsRow(title: "Show Game Badges",
//                           subtitle: "Display badges for favorite and recent games.",
//                           icon: .sfSymbol("star.circle"))
//            }
//            ThemedToggle(isOn: $showFavorites) {
//                SettingsRow(title: "Show Favorites",
//                           subtitle: "Display favorites section.",
//                           icon: .sfSymbol("star"))
//            }
//        }
//    }
//}

// Add the new view for selecting missing artwork style
fileprivate struct MissingArtworkStyleView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Default(.missingArtworkStyle) private var selectedStyle
    @Environment(\.dismiss) private var dismiss

    /// Animation states
    @State private var selectedPreviewScale: CGFloat = 1.0
    @State private var previewRotation: Double = 0
    @State private var showingFullScreenPreview = false
    @State private var animatingSelection = false

    private let previewTitle = "PRESS START!"

    var body: some View {
        List {
            Section {
                // Interactive preview of current style
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        showingFullScreenPreview.toggle()
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(uiImage: UIImage.missingArtworkImage(
                            gameTitle: previewTitle,
                            ratio: 1.6,
                            pattern: selectedStyle
                        ))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 160)
                        .cornerRadius(12)
                        .rotation3DEffect(.degrees(previewRotation), axis: (x: 0, y: 1, z: 0))
                        .scaleEffect(selectedPreviewScale)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    themeManager.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor,
                                    lineWidth: 3
                                )
                        )
                        .shadow(
                            color: (themeManager.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor).opacity(0.5),
                            radius: 10,
                            x: 0,
                            y: 5
                        )

                        Text("Tap to preview full screen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
                .padding(.horizontal)
            } header: {
                Text("Current Style")
            } footer: {
                Text("These retro-styled placeholders appear when a game is missing its cover artwork.")
                    .padding(.horizontal)
            }

            Section(header: Text("Available Styles")) {
                ForEach(RetroTestPattern.allCases, id: \.self) { style in
                    StyleOptionRow(
                        style: style,
                        isSelected: selectedStyle == style,
                        onSelect: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                selectedStyle = style
                                // Trigger preview animations
                                selectedPreviewScale = 1.1
                                previewRotation = 360
                                animatingSelection = true

                                // Reset animations
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        selectedPreviewScale = 1.0
                                        previewRotation = 0
                                        animatingSelection = false
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
                    )
                }
            }
        }
        .navigationTitle("Missing Artwork Style")
        .sheet(isPresented: $showingFullScreenPreview) {
            FullScreenPreview(style: selectedStyle, previewTitle: previewTitle)
        }
    }
}

/// Row view for each style option
private struct StyleOptionRow: View {
    let style: RetroTestPattern
    let isSelected: Bool
    let onSelect: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isPressed = false

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
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ?
                                (themeManager.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor) :
                                Color.clear,
                            lineWidth: 2
                        )
                )

                // Style description
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.description)
                        .font(.headline)
                    Text(style.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor)
                        .imageScale(.large)
                }
            }
        }
        .buttonStyle(StyleOptionButtonStyle(isSelected: isSelected))
        .padding(.vertical, 4)
    }
}

/// Custom button style for style options
private struct StyleOptionButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// Full screen preview view
private struct FullScreenPreview: View {
    let style: RetroTestPattern
    let previewTitle: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                Image(uiImage: UIImage.missingArtworkImage(
                    gameTitle: previewTitle,
                    ratio: 1.6,
                    pattern: style
                ))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: .black.opacity(0.3), radius: 20)
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
