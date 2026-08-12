// PVEmulatorViewController+MenuBar.swift
// PVUIBase
//
// The emulator half of the app's menu bar (see `Menus/PVMenuBarActions.swift`).
//
// Everything here is deliberately implemented on the view controller rather than
// on the app delegate: menu-item validation walks the responder chain from the key
// window's first responder, so an action that only this class implements is
// automatically DISABLED whenever an emulator isn't on screen. That is the whole
// enable/disable story for "Save State", "Reset", "Quit Emulation" and friends —
// there is no separate "am I in a game?" bookkeeping to keep in sync.
//
// `pvMenuShowSettings(_:)` is the exception. `PVAppDelegate` implements it too, as
// the last link in the responder chain, so ⌘, resolves everywhere. When a game is
// running THIS implementation wins (it is nearer the first responder) and presents
// Settings over the emulator instead of poking the — currently hidden — library
// window's tab bar.
//
// tvOS has no menu system; `UIMenuBuilder` and this whole file are `os(iOS)`-only.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if os(iOS)
import UIKit
import SwiftUI
import RealmSwift
import PVRealm
import PVLibrary
import PVLogging
import PVEmulatorCore
import PVCoreBridge

// MARK: - Settings host

/// Hosts the app-settings SwiftUI view when it is opened with ⌘, over a running
/// game. A distinct type (rather than a bare `UIHostingController`) so the
/// already-presented check can recognise it while walking the presentation chain.
final class PVMenuSettingsHostingController: UIHostingController<AnyView> {
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("PVMenuSettingsHostingController is not storyboard-instantiable")
    }

    @MainActor init(settingsView: AnyView) {
        super.init(rootView: settingsView)
    }
}

// MARK: - Menu actions

// Deliberately NOT declaring `: PVMenuBarActions` conformance — every member of
// that protocol is `@objc optional`, so conformance would check nothing, and the
// selectors below are matched by UIKit through `responds(to:)` either way. The
// protocol exists purely to give the builder and these methods one shared,
// compiler-checked selector vocabulary.
@MainActor
extension PVEmulatorViewController {

    // MARK: Settings

    /// ⌘, while a game is running.
    ///
    /// Presents the same settings UI the pause menu's "App Settings" entry shows
    /// (`PauseMenuViewRegistry.appSettingsView`), so there is one settings screen,
    /// not an emulator-specific copy. Emulation is intentionally left running:
    /// nothing here changes the core's pause state, so opening settings can neither
    /// resume a game the user paused with ⌘P nor desync `isShowingMenu`.
    @objc public func pvMenuShowSettings(_ sender: Any?) {
        // Already up? Bring it forward by doing nothing rather than stacking a
        // second copy. The check walks the whole presentation chain because the
        // host may have been presented by the pause menu rather than by `self`.
        var probe: UIViewController? = self
        while let candidate = probe {
            if candidate is PVMenuSettingsHostingController { return }
            probe = candidate.presentedViewController
        }

        // `weak` matters: the hosting controller owns its rootView, the rootView owns
        // this dismiss closure, and the closure captures this box. A strong capture
        // would close that loop and leak the settings screen on every ⌘,.
        weak var host: PVMenuSettingsHostingController?
        guard let settingsView = PauseMenuViewRegistry.appSettingsView(dismissAction: {
            host?.dismiss(animated: true)
        }) else {
            // No settings view registered (PVSwiftUI registers it at launch). Fall
            // back to the cross-scene notification so ⌘, still does something.
            WLOG("[MenuBar] No app settings view registered; falling back to PVShowSettings")
            NotificationCenter.default.post(name: .pvShowSettings, object: nil)
            return
        }

        let controller = PVMenuSettingsHostingController(settingsView: settingsView)
        host = controller

        // Present from the topmost presented controller: presenting from `self`
        // while the pause menu is up fails silently ("already presenting").
        var presenter: UIViewController = self
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        presenter.present(controller, animated: true)
    }

    // MARK: Save states

    /// ⌘S. Uses `createNewSaveState(auto:screenshot:)` directly rather than
    /// `quicksave()`, which has an age-eligibility guard that would make an
    /// explicit user request silently throw.
    @objc public func pvMenuSaveState(_ sender: Any?) {
        let screenshot = captureScreenshot()
        Task { @MainActor in
            do {
                try await createNewSaveState(auto: false, screenshot: screenshot)
            } catch {
                ELOG("[MenuBar] Save state failed: \(error.localizedDescription)")
            }
        }
    }

    /// ⌘L. Mirrors the pause menu's "loadState" entry: newest state for this game.
    @objc public func pvMenuLoadLastSaveState(_ sender: Any?) {
        guard let state = mostRecentSaveState else { return }
        Task { @MainActor [weak self] in
            _ = await self?.loadSaveState(state)
        }
    }

    /// Newest save state for the current game, or `nil` when there is none.
    /// Also drives the enabled state of the ⌘L menu item.
    private var mostRecentSaveState: PVSaveState? {
        guard let game, !game.isInvalidated else { return nil }
        return game.saveStates.sorted(byKeyPath: "date", ascending: false).first
    }

    // MARK: Screenshot

    /// ⇧⌘S. `takeScreenshot()` ends with `core.setPauseEmulation(false)` and
    /// `isShowingMenu = false` because it was written for the pause menu's
    /// dismiss-then-capture flow. That tail is why this item is disabled while the
    /// pause menu is showing (see `canPerformAction`) — firing it there would clear
    /// `isShowingMenu` without dismissing the menu VC, and
    /// `cleanupAfterMenuDismissal()` (gated on `isShowingMenu`) would then no-op,
    /// stranding controller input in menu mode.
    @objc public func pvMenuTakeScreenshot(_ sender: Any?) {
        takeScreenshot()
    }

    // MARK: Session

    /// ⇧⌘Q — quit to the library.
    @objc public func pvMenuQuitEmulation(_ sender: Any?) {
        Task { @MainActor in
            await quit(optionallySave: true) {
                SceneCoordinator.shared.closeEmulator()
            }
        }
    }

    /// ⇧⌘M — the in-game pause menu. NOT ⌘M, which is Minimize on macOS.
    @objc public func pvMenuShowPauseMenu(_ sender: Any?) {
        showMenu(nil)
    }

    /// ⌘P. Keys off `core.isEmulationPaused` (i.e. `!isRunning`). `core.isOn` is a
    /// different thing — "the core is up at all" — so toggling against it, as the
    /// old SwiftUI command did, only ever resumed.
    @objc public func pvMenuTogglePause(_ sender: Any?) {
        core.setPauseEmulation(!core.isEmulationPaused)
    }

    /// ⌘R.
    @objc public func pvMenuResetEmulation(_ sender: Any?) {
        core.resetEmulation()
    }

    /// ⇧⌘K. No-ops when the HUD was never installed (i.e. outside desktop input
    /// mode), which is also when the menu item is disabled.
    @objc public func pvMenuToggleKeyboardHUD(_ sender: Any?) {
        toggleKeyboardHUDPinned()
    }

    // MARK: - Validation

    /// Refines the automatic "is this action implemented anywhere in the chain?"
    /// enablement with per-action run-state rules.
    override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(PVMenuBarActions.pvMenuShowSettings(_:)):
            return true
        case #selector(PVMenuBarActions.pvMenuSaveState(_:)):
            return core.isOn && core.supportsSaveStates
        case #selector(PVMenuBarActions.pvMenuLoadLastSaveState(_:)):
            return core.isOn && core.supportsSaveStates && mostRecentSaveState != nil
        case #selector(PVMenuBarActions.pvMenuTakeScreenshot(_:)):
            return core.isOn && !isShowingMenu
        case #selector(PVMenuBarActions.pvMenuQuitEmulation(_:)):
            return core.isOn
        case #selector(PVMenuBarActions.pvMenuShowPauseMenu(_:)):
            // `showMenu(_:)` bails when the core isn't on, and re-showing an
            // already-visible menu is a no-op — reflect both in the menu.
            return core.isOn && !isShowingMenu
        case #selector(PVMenuBarActions.pvMenuTogglePause(_:)),
             #selector(PVMenuBarActions.pvMenuResetEmulation(_:)):
            return core.isOn
        case #selector(PVMenuBarActions.pvMenuToggleKeyboardHUD(_:)):
            return GamepadManager.isDesktopInputMode
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }

    /// Retitles ⌘P to match the core's current run state.
    ///
    /// `super` runs first: its default implementation is what consults
    /// `canPerformAction(_:withSender:)` and applies the `.disabled` attribute.
    /// Retitling afterwards means our title survives.
    override public func validate(_ command: UICommand) {
        super.validate(command)
        if command.action == #selector(PVMenuBarActions.pvMenuTogglePause(_:)) {
            command.title = core.isEmulationPaused ? "Resume" : "Pause"
        }
    }
}
#endif // os(iOS)
