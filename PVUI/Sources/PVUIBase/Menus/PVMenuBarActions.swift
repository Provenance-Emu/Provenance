// PVMenuBarActions.swift
// PVUIBase
//
// The app's single menu-bar vocabulary and its builder.
//
// WHY UIKIT AND NOT SwiftUI `.commands`:
// The menu used to be built from `.commands` blocks on `ProvenanceApp`'s main
// `WindowGroup` (Settings) and on `EmulatorScene` (Game/Emulation). Two problems
// made that unworkable:
//
//   1. No validation. A SwiftUI `Button` in a `CommandMenu` is always enabled, so
//      "Save State" / "Load Last Save State" / "Quit Emulation" stayed clickable in
//      the library where there is no emulator to act on, and each closure had to
//      re-derive its target by reaching into `AppState.emulationUIState`.
//   2. Two scenes, two command sets. Whichever scene's commands SwiftUI decided to
//      surface won; ⌘, lived only on the main scene, which is exactly why it did
//      nothing while a game was running.
//
// `UIResponder.buildMenu(with:)` builds ONE app-wide menu whose items are validated
// against the key window's responder chain — the standard UIKit path. An item is
// automatically disabled when nothing in the chain implements its action, so the
// emulator items disable themselves in the library for free, and
// `PVEmulatorViewController` refines that further in `canPerformAction(_:withSender:)`
// / `validate(_:)`.
//
// PLATFORM: macOS here is the iOS binary on Apple Silicon ("Designed for iPad"),
// where the system builds a real menu bar from this same `UIMenuBuilder` tree.
// Mac Catalyst is NOT supported — never gate on `targetEnvironment(macCatalyst)`.
// tvOS has no menu system and no `UIMenuBuilder`, hence `#if os(iOS)`.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if os(iOS)
import UIKit

// MARK: - Action vocabulary

/// The set of selectors the menu bar dispatches through the responder chain.
///
/// This protocol is never used as a type — it exists so the builder and the
/// responders that implement these actions share one compiler-checked selector
/// vocabulary instead of trading `Selector("…")` strings.
///
/// Every member is `optional` on purpose: a responder implements only the actions
/// it can service. `PVAppDelegate` implements `pvMenuShowSettings(_:)` alone (the
/// last-resort link in the chain, which is what makes ⌘, work from any scene);
/// `PVEmulatorViewController` implements that plus the in-game actions. Nothing
/// else implements the in-game actions, so UIKit greys them out everywhere else.
@objc
public protocol PVMenuBarActions {
    /// ⌘, — open the Settings UI in whatever scene is frontmost.
    @objc optional func pvMenuShowSettings(_ sender: Any?)
    /// ⌘S — write a manual save state for the running game.
    @objc optional func pvMenuSaveState(_ sender: Any?)
    /// ⌘L — load the most recent save state for the running game.
    @objc optional func pvMenuLoadLastSaveState(_ sender: Any?)
    /// ⇧⌘S — capture a screenshot to the game's screenshot folder.
    @objc optional func pvMenuTakeScreenshot(_ sender: Any?)
    /// ⇧⌘Q — quit the running game and return to the library.
    @objc optional func pvMenuQuitEmulation(_ sender: Any?)
    /// ⇧⌘M — show the in-game pause menu. NOT ⌘M, which is Minimize on macOS.
    @objc optional func pvMenuShowPauseMenu(_ sender: Any?)
    /// ⌘P — pause or resume emulation.
    @objc optional func pvMenuTogglePause(_ sender: Any?)
    /// ⌘R — reset the running game.
    @objc optional func pvMenuResetEmulation(_ sender: Any?)
    /// ⇧⌘K — pin/unpin the desktop keyboard HUD.
    @objc optional func pvMenuToggleKeyboardHUD(_ sender: Any?)
}

// MARK: - Builder

/// Builds Provenance's main menu. Call from `UIResponder.buildMenu(with:)` on the
/// app delegate (see `PVAppDelegate+MenuBar.swift`).
@MainActor
public enum PVMenuBarBuilder {

    private enum MenuID {
        static let settings = UIMenu.Identifier("org.provenance-emu.menu.settings")
        static let saveStates = UIMenu.Identifier("org.provenance-emu.menu.saveStates")
        static let gameSession = UIMenu.Identifier("org.provenance-emu.menu.gameSession")
        static let game = UIMenu.Identifier("org.provenance-emu.menu.game")
        static let gameControls = UIMenu.Identifier("org.provenance-emu.menu.gameControls")
        static let gameOverlays = UIMenu.Identifier("org.provenance-emu.menu.gameOverlays")
    }

    /// Installs Provenance's menus into `builder`.
    ///
    /// Only touches `UIMenuSystem.main` — the context-menu system shares this
    /// callback and must be left alone or every long-press menu in the app grows
    /// a "Save State" item.
    public static func build(with builder: UIMenuBuilder) {
        guard builder.system == .main else { return }

        // File items go in first so that, on the fallback path where Settings has
        // to live in File (no `.preferences` menu), Settings still lands above them.
        installFileItems(with: builder)
        installGameMenu(with: builder)
        installSettings(with: builder)
    }

    // MARK: App menu

    /// Settings… (⌘,) belongs in the app menu on macOS. On "Designed for iPad" the
    /// system provides `.preferences` inside the app menu; if it is absent (plain
    /// iPadOS builds the app menu differently) fall back to the File menu so the
    /// shortcut is still registered rather than silently dropped.
    private static func installSettings(with builder: UIMenuBuilder) {
        let settings = UIKeyCommand(
            title: "Settings…",
            action: #selector(PVMenuBarActions.pvMenuShowSettings(_:)),
            input: ",",
            modifierFlags: .command
        )
        let menu = UIMenu(title: "", identifier: MenuID.settings, options: .displayInline, children: [settings])

        if builder.menu(for: .preferences) != nil {
            builder.replace(menu: .preferences, with: menu)
        } else {
            builder.insertChild(menu, atStartOfMenu: .file)
        }
    }

    // MARK: File menu

    /// Save/load/screenshot/quit are file-ish operations, so they go under File —
    /// the standard macOS home for them.
    private static func installFileItems(with builder: UIMenuBuilder) {
        let saveState = UIKeyCommand(
            title: "Save State",
            action: #selector(PVMenuBarActions.pvMenuSaveState(_:)),
            input: "s",
            modifierFlags: .command
        )
        let loadState = UIKeyCommand(
            title: "Load Last Save State",
            action: #selector(PVMenuBarActions.pvMenuLoadLastSaveState(_:)),
            input: "l",
            modifierFlags: .command
        )
        let screenshot = UIKeyCommand(
            title: "Take Screenshot",
            action: #selector(PVMenuBarActions.pvMenuTakeScreenshot(_:)),
            input: "s",
            modifierFlags: [.command, .shift]
        )
        let quit = UIKeyCommand(
            title: "Quit Emulation",
            action: #selector(PVMenuBarActions.pvMenuQuitEmulation(_:)),
            input: "q",
            modifierFlags: [.command, .shift]
        )

        let saves = UIMenu(
            title: "",
            identifier: MenuID.saveStates,
            options: .displayInline,
            children: [saveState, loadState, screenshot]
        )
        let session = UIMenu(
            title: "",
            identifier: MenuID.gameSession,
            options: .displayInline,
            children: [quit]
        )

        builder.insertChild(saves, atStartOfMenu: .file)
        builder.insertChild(session, atEndOfMenu: .file)
    }

    // MARK: Game menu

    /// A dedicated top-level "Game" menu for run-state controls. Sits after View
    /// (before Window/Help) on macOS; falls back to sitting after File if the
    /// system menu tree has no View menu.
    private static func installGameMenu(with builder: UIMenuBuilder) {
        let showMenu = UIKeyCommand(
            title: "Show Game Menu",
            action: #selector(PVMenuBarActions.pvMenuShowPauseMenu(_:)),
            input: "m",
            modifierFlags: [.command, .shift]
        )
        // `validate(_:)` on PVEmulatorViewController retitles this to
        // "Resume"/"Pause" to match the core's current run state.
        let togglePause = UIKeyCommand(
            title: "Pause",
            action: #selector(PVMenuBarActions.pvMenuTogglePause(_:)),
            input: "p",
            modifierFlags: .command
        )
        let reset = UIKeyCommand(
            title: "Reset",
            action: #selector(PVMenuBarActions.pvMenuResetEmulation(_:)),
            input: "r",
            modifierFlags: .command
        )
        let keyboardHUD = UIKeyCommand(
            title: "Toggle Keyboard HUD",
            action: #selector(PVMenuBarActions.pvMenuToggleKeyboardHUD(_:)),
            input: "k",
            modifierFlags: [.command, .shift]
        )

        let controls = UIMenu(
            title: "",
            identifier: MenuID.gameControls,
            options: .displayInline,
            children: [showMenu, togglePause, reset]
        )
        let overlays = UIMenu(
            title: "",
            identifier: MenuID.gameOverlays,
            options: .displayInline,
            children: [keyboardHUD]
        )
        let gameMenu = UIMenu(title: "Game", identifier: MenuID.game, children: [controls, overlays])

        if builder.menu(for: .view) != nil {
            builder.insertSibling(gameMenu, afterMenu: .view)
        } else {
            builder.insertSibling(gameMenu, afterMenu: .file)
        }
    }
}
#endif // os(iOS)
