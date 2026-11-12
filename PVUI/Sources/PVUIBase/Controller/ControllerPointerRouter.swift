//
//  ControllerPointerRouter.swift
//  PVUI
//
//  Decides what a pad's touchpad drives in the running game, and drives it.
//

import Foundation
import GameController
import PVCoreBridge
import PVLogging
import PVSystems
import QuartzCore

#if canImport(UIKit)
import UIKit

/// One game's link between a pad's touchpad and the core.
///
/// It owns the role decision (`ControllerPointerPolicy`): whether the touchpad is the game's
/// mouse, light gun or Wii pointer, or is free, in which case its click opens the pause menu
/// (`PauseMenuTriggerMonitor` asks `touchpadIsFree(on:)`).
///
/// While the touchpad has a role, the pad is sampled on every display refresh and the result
/// is handed to the core. Nothing here installs a handler on a controller element: cores and
/// the remap pipeline already compete for those single slots.
@MainActor
final class ControllerPointerRouter {
    /// Roles that have somewhere to deliver to. A game whose role is not in this set leaves
    /// the touchpad free, so its click still opens the pause menu.
    static let deliverableRoles: Set<ControllerPointerRole> = [.mouse]
    /// How long the "Pointer speed" readout stays up after a two-finger slide.
    private static let speedReadoutDuration: TimeInterval = 1.5
    /// One readout at a time: each step replaces the last.
    private static let speedReadoutKey = "controllerPointerSpeed"

    private weak var host: PVEmulatorViewController?
    private var observers: [NSObjectProtocol] = []
    private var displayLink: OwnedDisplayLink?

    /// The cursor and the touch in progress. Kept across pauses so the cursor stays where it was.
    private var session: ControllerPointerSession?
    private weak var sessionPad: GCController?
    /// The game is paused or the app is not active; nothing is delivered.
    private var isSuspended = false

    private let store = ControllerPointerSettingsStore.shared
    /// The player's settings for this game: mode, speed, acceleration and click bindings.
    private var settings: ControllerPointerSettingsStore.Resolved
    /// A setting changed since `settings` was read.
    private var settingsAreStale = false

    /// What the touchpad drives right now.
    private(set) var role: ControllerPointerRole = .none

    init(host: PVEmulatorViewController) {
        self.host = host
        self.settings = ControllerPointerSettingsStore.shared.resolved(
            system: Self.system(of: host), gameMD5: host.core.romMD5)
    }

    private static func system(of host: PVEmulatorViewController) -> SystemIdentifier? {
        SystemIdentifier(rawValue: host.core.systemIdentifier ?? "")
    }

    // MARK: - Lifecycle

    func start() {
        guard displayLink == nil else { return }
        let center = NotificationCenter.default
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshRole() }
            })
        }
        observers.append(center.addObserver(forName: .PVMousePositionDidChange, object: nil, queue: .main) { [weak self] note in
            /// A mouse or the touch screen moved the cursor: carry on from where it left it.
            let sender = note.object as AnyObject?
            let position = (note.userInfo?[PVMousePositionKey] as? NSValue)?.cgPointValue
            MainActor.assumeIsolated {
                guard let self, sender !== self, let position else { return }
                self.session?.adoptCursor(position)
            }
        })
        /// The store's own changes, and the Mouse Sensitivity and Input Source settings it reads.
        for name in [ControllerPointerSettingsStore.didChangeNotification, UserDefaults.didChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.settingsAreStale = true }
            })
        }
        let link = OwnedDisplayLink(owner: self) { [weak self] in self?.tick() }
        link.start()
        displayLink = link
        refreshRole()
    }

    func stop() {
        releaseHeldInput()
        displayLink?.stop()
        displayLink = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        setRole(.none)
    }

    // MARK: - Role

    /// Works the role out again. Call when the game starts, when a pad comes or goes, and
    /// when the virtual mouse or light gun is switched on or off.
    func refreshRole() {
        guard let host else { return }
        let core = host.core
        let context = ControllerPointerContext(
            system: Self.system(of: host),
            gameSupportsMouse: (core as? MouseResponder)?.gameSupportsMouse ?? false,
            gameSupportsLightGun: (core as? LightGunResponder)?.gameSupportsLightGun ?? false,
            padHasPointerInput: pointerPad() != nil)
        let decided = ControllerPointerPolicy.role(for: context, mode: settings.mode)
        setRole(Self.deliverableRoles.contains(decided) ? decided : .none)
    }

    private func setRole(_ newRole: ControllerPointerRole) {
        guard newRole != role else { return }
        ILOG("Controller pointer role: \(role.rawValue) -> \(newRole.rawValue)")
        /// Buttons held under the old role are released through the old role's sink.
        releaseHeldInput()
        session = nil
        role = newRole
        #if os(tvOS)
        if newRole == .mouse {
            host?.installPointerOverlayIfNeeded()
        } else {
            host?.removePointerOverlay()
        }
        #endif
    }

    /// Whether `controller`'s touchpad click may open the pause menu right now: the touchpad
    /// is not the game's pointer, and the player has not mapped the click to something else.
    func touchpadIsFree(on controller: GCController) -> Bool {
        role == .none && !Self.isTouchpadClickRemapped(on: controller)
    }

    /// The player's own mapping of the touchpad click wins over everything here.
    private static func isTouchpadClickRemapped(on controller: GCController) -> Bool {
        guard let vendor = controller.hardwareController.vendorName else { return false }
        return ControllerMappingStore.shared.destination(forSource: .touchpadButton, vendor: vendor) != .touchpadButton
    }

    /// Player 1's pad if it has a touchpad, otherwise the first connected pad that has one.
    /// Whichever it is, the pointer belongs to player 1.
    private func pointerPad() -> GCController? {
        let manager = PVControllerManager.shared
        if let first = manager.player1, first.hasTouchpad { return first }
        return manager.controllers.first { $0.hasTouchpad }
    }

    // MARK: - Sampling

    /// Reads the player's settings again and applies them to the role and the session.
    private func reloadSettings() {
        settingsAreStale = false
        guard let host else { return }
        let fresh = store.resolved(system: Self.system(of: host), gameMD5: host.core.romMD5)
        guard fresh != settings else { return }
        settings = fresh
        refreshRole()
        session?.curve = fresh.curve
        session?.bindings = fresh.bindings(for: role)
    }

    private func tick() {
        if settingsAreStale { reloadSettings() }
        guard role != .none, let host else { return }
        #if os(tvOS)
        host.refreshPointerOverlayLayout()
        #endif

        guard !host.isShowingMenu, UIApplication.shared.applicationState == .active else {
            if !isSuspended {
                isSuspended = true
                releaseHeldInput()
            }
            return
        }
        isSuspended = false

        guard let pad = pointerPad(), let sample = pad.touchpadSample else {
            releaseHeldInput()
            sessionPad = nil
            return
        }
        if sessionPad !== pad {
            releaseHeldInput()
            sessionPad = pad
        }

        var current = session ?? ControllerPointerSession(curve: settings.curve, bindings: settings.bindings(for: role))
        let outputs = current.update(sample, at: CACurrentMediaTime())
        session = current
        deliver(outputs, ignoringActions: Self.isTouchpadClickRemapped(on: pad))
    }

    /// Lets go of every button the pointer is holding in the core. The session keeps its
    /// cursor, and ignores a click that is still held until the pad is released.
    private func releaseHeldInput() {
        guard var current = session else { return }
        let outputs = current.reset()
        session = current
        deliver(outputs, ignoringActions: false)
    }

    // MARK: - Delivery

    private func deliver(_ outputs: [PointerOutput], ignoringActions: Bool) {
        guard !outputs.isEmpty, let core = host?.core else { return }
        for output in outputs {
            if ignoringActions, case .action(_, isDown: true) = output { continue }
            if case let .speedChanged(speed) = output {
                saveSpeed(speed)
                continue
            }
            switch role {
            case .mouse:
                if let mouse = core as? MouseResponder { deliver(output, toMouse: mouse) }
            case .none, .wiiPointer, .lightGun:
                break
            }
        }
    }

    private func deliver(_ output: PointerOutput, toMouse mouse: MouseResponder) {
        let position = session?.cursor.position ?? PointerCursor.centre
        switch output {
        case let .moved(delta, newPosition):
            if mouse.mouseMoved?(byNormalizedDelta: delta) == nil {
                /// The core only takes positions. On tvOS `mouseMoved(atPoint:)` means a delta
                /// in view points, which this cursor is not, so nothing is sent there.
                #if !os(tvOS)
                mouse.mouseMoved(atPoint: newPosition)
                #endif
            }
            postCursor(newPosition)
        case let .recentered(newPosition):
            postCursor(newPosition)
        case let .action(action, isDown):
            deliver(action, isDown: isDown, at: position, toMouse: mouse)
        case .touching, .speedChanged:
            break
        }
    }

    private func deliver(_ action: PointerAction, isDown: Bool, at position: CGPoint, toMouse mouse: MouseResponder) {
        switch action {
        case .leftButton:
            if isDown { mouse.leftMouseDown(atPoint: position) } else { mouse.leftMouseUp() }
        case .rightButton:
            if isDown { mouse.rightMouseDown(atPoint: position) } else { mouse.rightMouseUp() }
        case .pauseMenu:
            PauseMenuTrigger.touchpadButton.postPauseRequest()
        case .trigger, .reload, .auxA, .auxB, .gunStart, .wiiA, .wiiB, .none:
            return
        }
        if isDown, action != .pauseMenu {
            NotificationCenter.default.post(name: .PVMouseButtonDidPress, object: self)
        }
    }

    /// The player changed the speed from the pad: keep it for this game and say what it is now.
    private func saveSpeed(_ speed: Double) {
        let md5 = host?.core.romMD5 ?? ""
        store.update(md5.isEmpty ? .global : .game(md5: md5)) { $0.speed = speed }
        let text = String(format: String(localized: "Pointer speed %.1f×"), speed)
        PVToastManager.post(
            text, type: .info, duration: Self.speedReadoutDuration, icon: "cursorarrow.motionlines",
            replaceKey: Self.speedReadoutKey)
    }

    /// Tells the on-screen cursor where the pointer is. Other cursor sources listen too.
    private func postCursor(_ position: CGPoint) {
        NotificationCenter.default.post(
            name: .PVMousePositionDidChange, object: self,
            userInfo: [PVMousePositionKey: NSValue(cgPoint: position)])
    }
}
#endif
