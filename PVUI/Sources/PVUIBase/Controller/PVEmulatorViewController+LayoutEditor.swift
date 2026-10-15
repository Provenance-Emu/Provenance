//
//  PVEmulatorViewController+LayoutEditor.swift
//  PVUIBase
//
//  Ways into the touch-control layout editor (pause menu "Edit Layout" and a
//  three-finger hold on the game screen) and the controller the pause menu's
//  "Remap Controller" opens. Nothing here puts a control on the live game screen.
//

import UIKit
import GameController
import PVLogging

extension PVEmulatorViewController {

    // MARK: - Layout editor

    /// The editor that applies to the controls on screen, `nil` when none can be edited
    /// (tvOS, desktop input mode, classic on-screen controller, skin still loading).
    var activeLayoutEditorKind: LayoutEditorKind? {
        #if os(tvOS)
        return nil
        #else
        return LayoutEditorKind.resolve(skinLayerEnabled: isDeltaSkinEnabled && skinContainerView != nil,
                                        overlayMounted: isProgrammaticOverlayActive,
                                        skinLoaded: skinDidReportLoaded)
        #endif
    }

    /// Pause menu "Edit Layout": closes the menu, then asks the mounted controls (overlay or
    /// DeltaSkin) for their editor once the menu has resumed the core, so the editor's own
    /// pause takes over (and is released when it closes) instead of the game resuming under it.
    func openLayoutEditor() {
        dismissNav(resumeEmulation: true) { [weak self] in
            self?.restoreIndicatorOverlay()
            NotificationCenter.default.post(name: .overlayEditLayoutRequested, object: nil)
        }
    }

    #if os(iOS)
    /// Adds the three-finger hold to the root view once; the skin container is rebuilt on
    /// every skin reload, the root view is not.
    func installLayoutEditorHoldGestureIfNeeded() {
        let installed = view.gestureRecognizers?.contains { $0.name == LayoutEditorHoldGestureRecognizer.identifier } ?? false
        guard !installed else { return }
        let hold = LayoutEditorHoldGestureRecognizer(target: self, action: #selector(handleLayoutEditorHold(_:)))
        view.addGestureRecognizer(hold)
    }

    /// Opens the editor during play. Ignored while paused, which also covers the editor
    /// itself being open (it pauses the core) and the pause menu.
    @objc private func handleLayoutEditorHold(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              !isShowingMenu, core.isOn, !core.isEmulationPaused,
              presentedViewController == nil,
              let kind = activeLayoutEditorKind else { return }
        ILOG("Layout editor: opened by three-finger hold (\(kind))")
        PVToastManager.shared.show(String(localized: "Layout editor"), duration: Self.layoutEditorToastDuration,
                                   icon: "square.and.pencil", replaceKey: Self.layoutEditorToastKey)
        NotificationCenter.default.post(name: .overlayEditLayoutRequested, object: nil)
    }

    private static let layoutEditorToastDuration: TimeInterval = 1.5
    private static let layoutEditorToastKey = "layoutEditorHold"
    #endif

    // MARK: - Controller remapping

    /// The controller the pause menu's "Remap Controller" opens: player 1's, else the next
    /// assigned player's, else the first connected one. Only extended gamepads qualify, since
    /// press-to-assign listens on `extendedGamepad` (a Siri Remote cannot be captured).
    /// `nil` hides the entry, as does a missing remap screen (PVSwiftUI registers it).
    var remappableController: GCController? {
        guard PauseMenuViewRegistry.hasControllerRemapView else { return nil }
        // A GCVirtualController (the system's on-screen pad) also exposes an extended
        // gamepad; remapping it makes no sense, so it never qualifies. The live N64
        // controller view does not create one today (only the unused
        // PVN64ControllerViewController2 does), so the vendor name is the only signal.
        return RemapControllerResolver.controller(assigned: PVControllerManager.shared.allLiveControllers,
                                                  connected: GCController.controllers(),
                                                  isRemappable: { controller in
            controller.extendedGamepad != nil
                && !(controller.vendorName?.localizedCaseInsensitiveContains("virtual") ?? false)
        })
    }
}

#if os(iOS)
/// Three fingers held still for `LayoutEditorGesture.minimumPressDuration`. It never delays
/// or blocks the touches the controls see during play: touches are delivered as usual, a
/// release is not held back, and it recognizes alongside every other gesture. Once it
/// fires, the controls get `touchesCancelled`, so any held buttons are released.
final class LayoutEditorHoldGestureRecognizer: UILongPressGestureRecognizer, UIGestureRecognizerDelegate {
    static let identifier = "PVLayoutEditorHold"

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        name = Self.identifier
        numberOfTouchesRequired = LayoutEditorGesture.touchCount
        minimumPressDuration = LayoutEditorGesture.minimumPressDuration
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
#endif
