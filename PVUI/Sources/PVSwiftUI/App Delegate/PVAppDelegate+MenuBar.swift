// PVAppDelegate+MenuBar.swift
// PVSwiftUI
//
// Installs Provenance's app-wide menu bar.
//
// The actions themselves live elsewhere: in-game ones on
// `PVEmulatorViewController` (PVEmulatorViewController+MenuBar.swift) and the ⌘,
// fallback on `UIApplication` (PVMenuBarActions.swift). Nothing is implemented on
// the delegate — menu validation walks the responder chain, and `UIApplication` is
// a link this app can rely on unconditionally.
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
        ILOG("[MenuBar] Building \(builder.system == .main ? "main" : "context") menu")
        PVMenuBarBuilder.build(with: builder)
    }
}
#endif // os(iOS)
