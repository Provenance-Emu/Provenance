//
//  CoreOptionsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVCoreBridge
import PVThemes

/// View that provides access to core-specific options with RetroWave styling
///
/// This view displays a list of all cores that implement the CoreOptional protocol,
/// allowing users to view and modify core-specific options. Each core can define its
/// own set of options, which can be boolean toggles, numeric ranges, string values,
/// or selections from predefined lists.
///
/// Options are automatically persisted between app launches, and can be reset to their
/// default values either individually or all at once.
public struct CoreOptionsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    #if os(tvOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    /// Initialize a new CoreOptionsView
    public init() {}

    /// The body of the view
    public var body: some View {
        ZStack {
            /// Theme-aware background
            Color(themeManager.currentPalette.gameLibraryBackground)
                .edgesIgnoringSafeArea(.all)

            /// Grid overlay with theme-appropriate styling
            RetroGrid(
                lineSpacing: 20,
                lineColor: themeManager.currentPalette.dark
                    ? themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.07)
                    : themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.05)
            )
            .edgesIgnoringSafeArea(.all)
            .opacity(themeManager.currentPalette.dark ? 0.3 : 0.2)

            /// Core options list with theme-aware styling
            CoreOptionsListView()
                #if os(tvOS)
                .focusSection() // Contain focus to prevent escape to parent tab bar
                #endif
        }
        .navigationTitle("Core Options")
        #if os(tvOS)
        .onExitCommand {
            // Handle Menu button to go back properly
            dismiss()
        }
        #endif
    }
}
