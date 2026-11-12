//
//  PVEmulatorViewController+ControllerPointer.swift
//  PVUI
//
//  The running game's controller pointer (touchpad as mouse or Wii pointer, pause from the
//  touchpad click) and pad shake.
//

#if canImport(UIKit)
import GameController
import ObjectiveC
import PVCoreBridge
import SwiftUI
import UIKit

private enum ControllerPointerKeys {
    static var routerKey: UInt8 = 0
    static var motionRouterKey: UInt8 = 0
    #if os(tvOS)
    static var overlayKey: UInt8 = 0
    #endif
}

@MainActor
extension PVEmulatorViewController {

    /// Decides what a pad's touchpad drives in this game. Lives from the game's start to its end.
    var pointerRouter: ControllerPointerRouter? {
        get { objc_getAssociatedObject(self, &ControllerPointerKeys.routerKey) as? ControllerPointerRouter }
        set { objc_setAssociatedObject(self, &ControllerPointerKeys.routerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// What a pad's touchpad drives in this game right now.
    var controllerPointerRole: ControllerPointerRole {
        pointerRouter?.role ?? .none
    }

    /// Turns the players' pad shakes into the game's shake input. Lives as long as `pointerRouter`.
    var motionRouter: ControllerMotionRouter? {
        get { objc_getAssociatedObject(self, &ControllerPointerKeys.motionRouterKey) as? ControllerMotionRouter }
        set {
            objc_setAssociatedObject(self, &ControllerPointerKeys.motionRouterKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func startControllerPointer() {
        guard pointerRouter == nil else { return }
        let router = ControllerPointerRouter(host: self)
        router.start()
        pointerRouter = router

        let motion = ControllerMotionRouter(host: self)
        motion.start()
        motionRouter = motion
    }

    func stopControllerPointer() {
        pointerRouter?.stop()
        pointerRouter = nil
        motionRouter?.stop()
        motionRouter = nil
    }

    /// Whether `controller`'s touchpad click may open the pause menu right now.
    func touchpadIsFree(on controller: GCController) -> Bool {
        pointerRouter?.touchpadIsFree(on: controller) ?? false
    }
}

#if os(tvOS)
// MARK: - Cursor overlay
//
// On iOS the virtual mouse installs the arrow cursor for every mouse game
// (`PVEmulatorViewController+VirtualMouse.swift`). tvOS has no virtual mouse, so the
// arrow a pad's touchpad moves is hosted here.

@MainActor
extension PVEmulatorViewController {

    private var pointerOverlayHost: UIHostingController<MouseCursorOverlayView>? {
        get { objc_getAssociatedObject(self, &ControllerPointerKeys.overlayKey) as? UIHostingController<MouseCursorOverlayView> }
        set { objc_setAssociatedObject(self, &ControllerPointerKeys.overlayKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The game picture's frame: the cursor's 0-1 range maps onto it.
    private var pointerOverlayFrame: CGRect {
        if let target = currentTargetFrame, !target.isEmpty { return target }
        let gpuFrame = gpuViewController.view.frame
        return gpuFrame.isEmpty ? view.bounds : gpuFrame
    }

    func installPointerOverlayIfNeeded() {
        guard pointerOverlayHost == nil else { return }
        let overlay = MouseCursorOverlayView(
            showsCursor: !MouseCursorOverlayView.systemDrawsOwnPointer(
                core.systemIdentifier, coreIdentifier: core.coreIdentifier))
        let host = UIHostingController(rootView: overlay)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.isUserInteractionEnabled = false
        host.view.frame = pointerOverlayFrame
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        pointerOverlayHost = host
    }

    func removePointerOverlay() {
        guard let host = pointerOverlayHost else { return }
        host.willMove(toParent: nil)
        host.view.removeFromSuperview()
        host.removeFromParent()
        pointerOverlayHost = nil
    }

    /// Keeps the overlay over the game picture as the layout changes.
    func refreshPointerOverlayLayout() {
        guard let overlayView = pointerOverlayHost?.view else { return }
        let frame = pointerOverlayFrame
        if overlayView.frame != frame { overlayView.frame = frame }
    }
}
#endif
#endif
