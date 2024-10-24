//
//  ApplyBackgroundWrapper.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/4/24.
//
import Foundation
#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
@_exported import PVUIBase

#if canImport(Introspect)
import Introspect
#endif

/// Wraps a view and applies a background color based on the current theme.
struct ApplyBackgroundWrapper<Content: SwiftUI.View>: SwiftUI.View {
    /// The content view to wrap.
    @ViewBuilder var content: () -> Content
    /// The theme manager to use.
    @ObservedObject private var themeManager = ThemeManager.shared

    /// The body of the view.
    var body: some SwiftUI.View {
        content()
            .background(Material.ultraThinMaterial)
            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
    }
}
#endif
