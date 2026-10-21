//
//  PVSearchBar.swift
//  Provenance
//
//  Created by Ian Clawson on 2/10/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//
//  From: https://github.com/Geri-Borbas/iOS.Blog.SwiftUI_Search_Bar_in_Navigation_Bar

import Foundation
import SwiftUI
import PVThemes

public struct PVSearchBar: View {
    @Binding public var text: String
    @State private var isSearching: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared

    public init(text: Binding<String>) {
        _text = text
    }

    public var body: some View {
        HStack {
            HStack {
                // Magnifying glass icon with animation
                Image(systemName: "magnifyingglass")
                    .foregroundColor(
                        isSearching
                            ? themeManager.currentPalette.defaultTintColor.swiftUIColor
                            : (themeManager.currentPalette.dark
                                ? Color.white.opacity(0.7)
                                : Color.gray.opacity(0.65))
                    )
                    .animation(.easeInOut(duration: 0.2), value: isSearching)

                // Search text field
                TextField("SEARCH", text: $text, onEditingChanged: { editing in
                    withAnimation {
                        isSearching = editing
                    }
                })
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .font(.system(size: 14, weight: .medium))

                // Clear button
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.8))
                    }
                }
            }
            .padding(10)
            .background {
                RetroPauseSearchFieldBackgroundThemed(isDark: themeManager.currentPalette.dark)
            }
        }
//        .padding(.vertical, 8)
//        .padding(.horizontal, 8)
    }
}
