//
//  SettingsPresentation.swift
//  PVUIBase
//
//  One decision for every place that presents the app Settings screen on iOS: a sheet on
//  iPhone, a full-screen cover on iPad (#3780).
//
//  A SwiftUI `.sheet` on a regular-width iPad is a form sheet about 540pt wide whatever the
//  window size, so in landscape most of the screen sat unused around a cramped Settings. That
//  width also never clears `SettingsLayoutRules.regularSidebarMinimumWidth` (600pt), so the
//  sidebar the layout was designed around never appeared. A full-screen cover fills whatever
//  window the app has (Stage Manager, Split View and Slide Over included) and lets the
//  layout rules pick the sidebar or the tab strip from the real width. Settings dismisses
//  through its own Done button, so the cover's missing swipe-to-dismiss costs nothing.
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum SettingsPresentation {
    /// Whether Settings should fill the window instead of appearing in a sheet.
    ///
    /// iPad only (which includes "Designed for iPad" on a Mac). iPhone keeps the sheet; tvOS
    /// callers already use their own full-screen presentation.
    public static var fillsScreen: Bool {
        #if os(iOS)
        return fillsScreen(for: UIDevice.current.userInterfaceIdiom)
        #else
        return false
        #endif
    }

    #if canImport(UIKit)
    /// The pure rule behind `fillsScreen`, kept separate so it can be unit-tested.
    public static func fillsScreen(for idiom: UIUserInterfaceIdiom) -> Bool {
        idiom == .pad
    }
    #endif
}

public extension View {
    /// Presents the app Settings screen: as a full-screen cover where
    /// `SettingsPresentation.fillsScreen` is true (iPad), as a sheet everywhere else.
    ///
    /// The choice is fixed for the process lifetime, so the two branches never swap while
    /// the view is alive.
    @ViewBuilder
    func settingsPresentation<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        if SettingsPresentation.fillsScreen {
            fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        } else {
            sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        }
        #endif
    }
}
