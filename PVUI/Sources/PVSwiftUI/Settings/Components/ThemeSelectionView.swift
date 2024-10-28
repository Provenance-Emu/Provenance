//
//  ThemeSelectionView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVThemes

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

    var body: some View {
        List {
            /// Standard theme options section
            Section(header: Text("Standard Themes")) {
                ForEach(ThemeOptionsStandard.allCases, id: \.self) { option in
                    /// Display current system mode for auto theme option
                    let systemMode = colorScheme == .dark ? "Dark" : "Light"
                    let modeLabel = option == .auto ? option.description + " (\(systemMode))" : option.description

                    Button(action: {
                        /// Determine if dark theme should be applied
                        let darkTheme = (option == .auto && colorScheme == .dark) || option == .dark
                        let newPalette = darkTheme ? ProvenanceThemes.dark.palette : ProvenanceThemes.light.palette
                        /// Apply the selected theme
                        ThemeManager.shared.setCurrentPalette(newPalette)
                        currentTheme = .standard(option)
                        ThemeManager.applySavedTheme()
                        dismiss()
                    }) {
                        HStack {
                            Text(modeLabel)
                            Spacer()
                            /// Show checkmark for currently selected theme
                            if case .standard(let current) = currentTheme, current == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }

            /// CGA theme options section
            Section(header: Text("CGA Themes")) {
                ForEach(CGAThemes.allCases, id: \.self) { cgaTheme in
                    Button(action: {
                        /// Apply selected CGA theme
                        let palette = cgaTheme.palette
                        ThemeManager.shared.setCurrentPalette(palette)
                        let themeOptionCGA = ThemeOptionsCGA(rawValue: cgaTheme.rawValue) ?? .blue
                        currentTheme = .cga(themeOptionCGA)
                        ThemeManager.applySavedTheme()
                        dismiss()
                    }) {
                        HStack {
                            Text(cgaTheme.palette.name)
                            Spacer()
                            /// Show checkmark for currently selected CGA theme
                            if case .cga(let current) = currentTheme,
                               let currentCGATheme = CGAThemes(rawValue: current.rawValue),
                               currentCGATheme == cgaTheme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Theme")
    }
}
