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


@available(iOS 14, tvOS 14, *)
struct ApplyBackgroundWrapper<Content: SwiftUI.View>: SwiftUI.View {
    @ViewBuilder var content: () -> Content
    var body: some SwiftUI.View {
        if #available(iOS 15, tvOS 15, *) {
            content().background(Material.ultraThinMaterial)
        } else {
            content().background(ThemeManager.shared.currentTheme.gameLibraryBackground.swiftUIColor)
        }
    }
}
#endif
