// PVAppDelegate+MenuBar.swift
// PVSwiftUI
//
// Installs Provenance's app-wide menu bar and provides the last-resort ⌘,
// handler.
//
// `UIResponder.buildMenu(with:)` is overridden here, on the app delegate, because
// that is the one responder guaranteed to exist before any window does — UIKit
// asks it to build `UIMenuSystem.main` once at launch. On macOS ("Designed for
// iPad": the iOS binary on Apple Silicon — Mac Catalyst is NOT supported) the
// system renders that tree as a real menu bar; on iPadOS the same tree backs the
// ⌘-hold shortcut HUD. tvOS has no menu system at all, hence `#if os(iOS)`.
//
// The menu replaces the SwiftUI `.commands` blocks that used to live on
// `ProvenanceApp`'s main `WindowGroup` and on `EmulatorScene` — see the header of
// `PVMenuBarActions.swift` for why those could not be kept.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if os(iOS)
import UIKit
import PVUIBase
import PVLogging

extension PVAppDelegate {

    override public func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        PVMenuBarBuilder.build(with: builder)
    }

    /// ⌘, fallback for every scene that isn't a running game.
    ///
    /// The app delegate is the final link in the responder chain, so this runs only
    /// when nothing nearer the first responder handles the action. While a game is
    /// running `PVEmulatorViewController.pvMenuShowSettings(_:)` wins and presents
    /// Settings over the emulator; everywhere else this posts `PVShowSettings`,
    /// which `RetroMainView` (iOS) and `TVMediaMainView` (tvOS) observe to switch to
    /// the Settings tab. Switching to a tab the app is already showing is a no-op,
    /// so repeated ⌘, cannot stack duplicate Settings screens.
    @objc public func pvMenuShowSettings(_ sender: Any?) {
        ILOG("[MenuBar] Settings requested (app-level fallback)")
        NotificationCenter.default.post(name: .pvShowSettings, object: nil)
    }
}
#endif // os(iOS)
