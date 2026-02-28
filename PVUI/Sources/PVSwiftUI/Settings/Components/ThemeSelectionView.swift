//
//  ThemeSelectionView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVThemes
import PVUIBase
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// MARK: - Theme Button Style

/// Custom button style for theme selection buttons
struct ThemeButtonStyle: ButtonStyle {
    let isSelected: Bool
    let accentColor: Color
    @ObservedObject private var themeManager = ThemeManager.shared

    func makeBody(configuration: Configuration) -> some View {
        ThemeButtonContent(
            configuration: configuration,
            isSelected: isSelected,
            accentColor: accentColor,
            themeManager: themeManager
        )
    }
}

/// Content view for ThemeButtonStyle with focus handling
private struct ThemeButtonContent: View {
    let configuration: ButtonStyle.Configuration
    let isSelected: Bool
    let accentColor: Color
    @ObservedObject var themeManager: ThemeManager

    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused: Bool
    #else
    private var isFocused: Bool { false }
    #endif

    var body: some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(isFocused ? 0.8 : 0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                borderGradient,
                                lineWidth: borderWidth
                            )
                    )
            )
            .scaleEffect(scaleEffect)
            .shadow(color: shadowColor, radius: shadowRadius)
            #if os(tvOS)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
            #endif
    }

    private var borderGradient: some ShapeStyle {
        if isFocused {
            return AnyShapeStyle(LinearGradient(
                colors: [.retroPink, .retroBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else if isSelected {
            return AnyShapeStyle(RetroTheme.retroPink)
        } else {
            return AnyShapeStyle(accentColor.opacity(0.7))
        }
    }

    private var borderWidth: CGFloat {
        if isFocused { return 3 }
        if isSelected { return 2 }
        return 1
    }

    private var scaleEffect: CGFloat {
        if configuration.isPressed { return 0.98 }
        if isFocused { return 1.04 }
        return 1.0
    }

    private var shadowColor: Color {
        if isFocused { return RetroTheme.retroPink.opacity(0.6) }
        if isSelected { return RetroTheme.retroPink.opacity(0.5) }
        return .clear
    }

    private var shadowRadius: CGFloat {
        if isFocused { return 10 }
        if isSelected { return 5 }
        return 0
    }
}

// MARK: - Theme Color Swatch

/// A small preview of theme colors
struct ThemeColorSwatch: View {
    let colors: [Color]
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(colors.count, 3), id: \.self) { i in
                Rectangle()
                    .fill(colors[i])
                    .frame(width: 12, height: 12)
                    .cornerRadius(2)
            }
        }
        .padding(4)
        .background(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(0.3))
        .cornerRadius(4)
    }
}

// MARK: - Standard Theme Row

/// A row for standard theme options
struct StandardThemeRow: View {
    let option: ThemeOptionsStandard
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            HStack {
                Text(modeLabel)
                    .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(RetroTheme.retroPink)
                }
            }
        }
        .buttonStyle(ThemeButtonStyle(isSelected: isSelected, accentColor: RetroTheme.retroBlue))
        #if os(tvOS)
        .tvOSDisableFocusEffect()
        #endif
        .padding(.horizontal)
    }

    private var modeLabel: String {
        let systemMode = colorScheme == .dark ? "Dark" : "Light"
        return option == .auto ? option.description + " (\(systemMode))" : option.description
    }
}

// MARK: - CGA Theme Row

/// A row for CGA theme options
struct CGAThemeRow: View {
    let cgaTheme: CGAThemes
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            HStack {
                // Theme name with color preview
                HStack(spacing: 10) {
                    // Color swatch preview based on the CGA theme
                    cgaThemeColorSwatch

                    Text(cgaTheme.palette.name)
                        .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(RetroTheme.retroPink)
                }
            }
        }
        .buttonStyle(ThemeButtonStyle(isSelected: isSelected, accentColor: RetroTheme.retroPurple))
        #if os(tvOS)
        .tvOSDisableFocusEffect()
        #endif
        .padding(.horizontal)
    }

    // Generate color swatches based on the CGA theme
    private var cgaThemeColorSwatch: some View {
        let colors: [Color] = cgaThemeColors

        return HStack(spacing: 2) {
            ForEach(0..<min(colors.count, 3), id: \.self) { i in
                Rectangle()
                    .fill(colors[i])
                    .frame(width: 12, height: 12)
                    .cornerRadius(2)
            }
        }
        .padding(4)
        .background(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(0.3))
        .cornerRadius(4)
    }

    // Get appropriate colors for each CGA theme
    private var cgaThemeColors: [Color] {
        switch cgaTheme {
        case .blue:
            return [Color(UIColor.CGA.blue), Color(UIColor.CGA.blueShadow)]
        case .cyan:
            return [Color(UIColor.CGA.cyan), Color(UIColor.CGA.cyanShadow)]
        case .green:
            return [Color(UIColor.CGA.green), Color(UIColor.CGA.greenShadow)]
        case .magenta:
            return [Color(UIColor.CGA.magenta), Color(UIColor.CGA.magentaShadow)]
        case .red:
            return [Color(UIColor.CGA.red), Color(UIColor.CGA.redShadow)]
        case .yellow:
            return [Color(UIColor.CGA.yellow), Color(UIColor.CGA.yellowShadow)]
        case .purple:
            return [Color(UIColor.CGA.purple), Color(UIColor.CGA.purpleShadow)]
        case .rainbow, .random:
            return [Color.red, Color.green, Color.blue]
        }
    }
}

// MARK: - RetroWave Theme Row

/// A row for the RetroWave theme option
struct RetroWaveThemeRow: View {
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused: Bool
    #else
    private var isFocused: Bool { false }
    #endif

    var body: some View {
        Button(action: action) {
            HStack {
                // Retrowave preview with animated gradient
                HStack(spacing: 10) {
                    // Animated color preview
                    LinearGradient(
                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 50, height: 16)
                    .cornerRadius(4)
                    .overlay(RetroGrid(lineSpacing: 4, lineColor: Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText).opacity(0.3)))
                    .mask(RoundedRectangle(cornerRadius: 4))

                    Text("Retrowave")
                        .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                        .fontWeight(.medium)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(RetroTheme.retroPink)
                }
            }
        }
        .buttonStyle(ThemeButtonStyle(isSelected: isSelected, accentColor: Color.clear))
        #if os(tvOS)
        .tvOSDisableFocusEffect()
        #endif
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(isFocused ? 0.8 : 0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            RetroTheme.retroGradient,
                            lineWidth: isFocused ? 3 : 2
                        )
                )
        )
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .shadow(color: RetroTheme.retroPurple.opacity(isFocused ? 0.7 : 0.5), radius: isFocused ? 12 : 8)
        #if os(tvOS)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
        #endif
        .padding(.horizontal)
    }
}

// MARK: - Theme Section

/// A section in the theme selection view
struct ThemeSection<Content: View>: View {
    let title: String
    let titleColor: Color
    let content: Content

    init(title: String, titleColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.titleColor = titleColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(titleColor)
                .padding(.horizontal)

            content
        }
        .padding(.bottom, 20)
        .modifier(RetroTheme.RetroSectionStyle())
    }
}

// MARK: - Title View

/// The animated title for the theme selection view
struct ThemeSelectionTitleView: View {
    @Binding var glowOpacity: Double
    @Binding var isAnimating: Bool

    var body: some View {
        Text("THEME SELECTION")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(RetroTheme.retroHorizontalGradient)
            .padding(.top, 20)
            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 10, x: 0, y: 0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.7
                    isAnimating = true
                }
            }
    }
}

// MARK: - Back Button

/// The back button for the theme selection view
struct ThemeSelectionBackButton: View {
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused: Bool
    #else
    private var isFocused: Bool { false }
    #endif

    var body: some View {
        Button(action: action) {
            Text("BACK")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                .padding(.vertical, 12)
                .padding(.horizontal, 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(isFocused ? 0.9 : 0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(RetroTheme.retroGradient, lineWidth: isFocused ? 3 : 2)
                        )
                )
                .shadow(color: RetroTheme.retroPink.opacity(isFocused ? 0.6 : 0.3), radius: isFocused ? 10 : 5)
        }
        #if os(tvOS)
        .buttonStyle(TVMediaFlatButtonStyle(isFocused: isFocused))
        .tvOSDisableFocusEffect()
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
        #else
        .buttonStyle(PlainButtonStyle())
        #endif
        .padding(.vertical, 20)
    }
}

/// View for selecting and applying different theme options
struct ThemeSelectionView: View {
    /// Theme manager instance for managing app-wide theme state
    @ObservedObject private var themeManager = ThemeManager.shared
    /// Currently selected theme stored in user defaults
    @Default(.theme) private var currentTheme
    /// Environment variable for dismissing the view
    @Environment(\.dismiss) private var dismiss
    /// Current system color scheme (light/dark)
    @Environment(\.colorScheme) private var colorScheme

    // Animation states for retrowave effects
    @State private var isAnimating = false
    @State private var glowOpacity = 0.0

    // MARK: - Background Components

    /// Background view with retrowave grid
    private var backgroundView: some View {
        ZStack {
            // Background using theme palette
            Color(themeManager.currentPalette.gameLibraryBackground)
                .edgesIgnoringSafeArea(.all)

            // Grid overlay with retrowave styling
            RetroGrid(lineSpacing: 20, lineColor: Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText).opacity(0.07))
                .edgesIgnoringSafeArea(.all)
                .opacity(themeManager.currentPalette.dark ? 0.3 : 0.1)
        }
    }

    // MARK: - Standard Themes Section

    /// Standard themes section
    private var standardThemesSection: some View {
        ThemeSection(title: "STANDARD THEMES", titleColor: RetroTheme.retroBlue) {
            ForEach(ThemeOptionsStandard.allCases, id: \.self) { option in
                let isSelected = (currentTheme == .standard(option))

                StandardThemeRow(
                    option: option,
                    isSelected: isSelected,
                    colorScheme: colorScheme
                ) {
                    applyStandardTheme(option)
                }
            }
        }
    }

    // MARK: - CGA Themes Section

    /// CGA themes section — gated for Plus subscribers
    private var cgaThemesSection: some View {
        #if canImport(FreemiumKit)
        PaidFeatureView {
            ThemeSection(title: "CGA THEMES", titleColor: RetroTheme.retroPink) {
                ForEach(CGAThemes.allCases, id: \.self) { cgaTheme in
                    let isSelected = (currentTheme == .cga(ThemeOptionsCGA(rawValue: cgaTheme.rawValue) ?? .blue))

                    CGAThemeRow(
                        cgaTheme: cgaTheme,
                        isSelected: isSelected
                    ) {
                        applyCGATheme(cgaTheme)
                    }
                }
            }
        } lockedView: {
            // Show themes but locked with overlay
            ThemeSection(title: "CGA THEMES", titleColor: RetroTheme.retroPink) {
                ForEach(CGAThemes.allCases.prefix(4), id: \.self) { cgaTheme in
                    CGAThemeRow(
                        cgaTheme: cgaTheme,
                        isSelected: false
                    ) { }
                }

                // "Plus" lock overlay badge
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("PLUS")
                            .font(.system(size: 11, weight: .heavy))
                        Text("— 9 CGA color themes")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.retroPink.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.retroPink.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                    Spacer()
                }
                .padding(.top, 4)
            }
            .opacity(0.7)
            .disabled(true)
        }
        .freemiumKitColorReset()
        #else
        ThemeSection(title: "CGA THEMES", titleColor: RetroTheme.retroPink) {
            ForEach(CGAThemes.allCases, id: \.self) { cgaTheme in
                let isSelected = (currentTheme == .cga(ThemeOptionsCGA(rawValue: cgaTheme.rawValue) ?? .blue))

                CGAThemeRow(
                    cgaTheme: cgaTheme,
                    isSelected: isSelected
                ) {
                    applyCGATheme(cgaTheme)
                }
            }
        }
        #endif
    }

    // MARK: - RetroWave Theme Section

    /// RetroWave theme section — gated for Plus subscribers
    private var retroWaveThemeSection: some View {
        #if canImport(FreemiumKit)
        PaidFeatureView {
            ThemeSection(title: "RETROWAVE THEME", titleColor: RetroTheme.retroPurple) {
                let isRetrowaveSelected = (currentTheme == .standard(.dark))
                RetroWaveThemeRow(isSelected: isRetrowaveSelected) {
                    applyRetroWaveTheme()
                }
            }
        } lockedView: {
            ThemeSection(title: "RETROWAVE THEME", titleColor: RetroTheme.retroPurple) {
                RetroWaveThemeRow(isSelected: false) { }

                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("PLUS")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.retroPink.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.retroPink.opacity(0.3), lineWidth: 0.5)
                                )
                    )
                    Spacer()
                }
                .padding(.top, 4)
            }
            .opacity(0.7)
            .disabled(true)
        }
        .freemiumKitColorReset()
        #else
        ThemeSection(title: "RETROWAVE THEME", titleColor: RetroTheme.retroPurple) {
            let isRetrowaveSelected = (currentTheme == .standard(.dark))
            RetroWaveThemeRow(isSelected: isRetrowaveSelected) {
                applyRetroWaveTheme()
            }
        }
        #endif
    }

    // MARK: - Main Content

    /// Main content container
    private var contentView: some View {
        VStack(spacing: 20) {
            // Title
            ThemeSelectionTitleView(glowOpacity: $glowOpacity, isAnimating: $isAnimating)

            // Theme sections
            standardThemesSection
            cgaThemesSection
            retroWaveThemeSection

            RetroPalettePreview(palette: themeManager.currentPalette)
                .frame(maxWidth: .infinity)

            // Back button
            ThemeSelectionBackButton {
                dismiss()
            }
        }
        .padding()
    }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                contentView
            }
        }
        .navigationTitle("Select Theme")
    }

    // MARK: - Theme Application Methods

    /// Apply a standard theme
    private func applyStandardTheme(_ option: ThemeOptionsStandard) {
        // Determine if dark theme should be applied
        let darkTheme = (option == .auto && colorScheme == .dark) || option == .dark
        let newPalette = darkTheme ? ProvenanceThemes.dark.palette : ProvenanceThemes.light.palette

        // Apply the selected theme
        ThemeManager.shared.setCurrentPalette(newPalette)
        currentTheme = .standard(option)
        ThemeManager.applySavedTheme()
        dismiss()
    }

    /// Apply a CGA theme
    private func applyCGATheme(_ cgaTheme: CGAThemes) {
        // Apply selected CGA theme
        let palette = cgaTheme.palette
        ThemeManager.shared.setCurrentPalette(palette)
        let themeOptionCGA = ThemeOptionsCGA(rawValue: cgaTheme.rawValue) ?? .blue
        currentTheme = .cga(themeOptionCGA)
        ThemeManager.applySavedTheme()
        dismiss()
    }

    /// Apply the RetroWave theme
    private func applyRetroWaveTheme() {
        // Apply the official RetroWave theme
        ThemeManager.shared.setCurrentPalette(ProvenanceThemes.retrowave.palette)
        // Set the theme to retrowave (using standard dark as fallback for now)
        currentTheme = .standard(.dark)
        ThemeManager.applySavedTheme()
        dismiss()
    }
}
