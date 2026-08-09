import Foundation
import GameController
import SwiftUI
import Combine
import PVSettings
import PVLogging

public enum GamepadEvent {
    case buttonPress(Bool)
    case buttonB(Bool)
    case verticalNavigation(Float, Bool)
    case horizontalNavigation(Float, Bool)
    case menuToggle(Bool)
    case shoulderLeft(Bool)
    case shoulderRight(Bool)
    case start(Bool)
}

public class GamepadManager: ObservableObject {
    public static let shared = GamepadManager()

    @Published public private(set) var isControllerConnected: Bool = false
    /// Whether at least one physical (non-remote) game controller is connected.
    /// On tvOS, the Siri Remote is also a `GCController`, so this property
    /// excludes it to reflect true gamepad availability.
    @Published public private(set) var hasPhysicalGamepad: Bool = false
    /// Whether a hardware keyboard is attached (GCKeyboard). Keyboard-only desktops
    /// (Mac "Designed for iPad", iPad with keyboard) use this to enable
    /// controller-style navigation without a physical gamepad.
    @Published public private(set) var isKeyboardConnected: Bool = false
    /// True when some form of directional/button navigation input is available:
    /// a real gamepad, or a hardware keyboard while the user has opted into
    /// controller-style navigation (`Defaults[.controllerStyleNavigation]`).
    ///
    /// This is a stored `@Published` property re-derived by `updateNavigationInputAvailability()`
    /// any time one of its three inputs changes (controller connect/disconnect, keyboard
    /// connect/disconnect, or the setting being flipped at runtime) rather than a computed
    /// property. A computed property over `@Published` inputs only reflects the fresh value
    /// when something re-reads it — it does not itself republish through Combine, so a
    /// SwiftUI view observing only this property (not the underlying inputs) would not
    /// invalidate when they change. Keeping it as its own `@Published` guarantees
    /// `objectWillChange` fires and dependent views actually update.
    @Published public private(set) var isNavigationInputAvailable: Bool = false
    /// Tracks whether a full-screen retrowave alert / picker is currently presented
    /// over the root UI. iOS gamepad subscribers (root view, home, sidebar, etc.)
    /// should early-return when this is `true` so that A / d-pad presses don't
    /// "leak" through to background views while a modal picker is up.
    ///
    /// tvOS has its own focus-coordinator gating; this flag is intentionally
    /// usable on both platforms but only consulted by iOS subscribers today.
    @Published public var isModalAlertPresented: Bool = false
    private var observers: [NSObjectProtocol] = []
    private var cancellables: Set<AnyCancellable> = []
    private let eventSubject = PassthroughSubject<GamepadEvent, Never>()

    public var eventPublisher: AnyPublisher<GamepadEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private init() {
        setupNotifications()
        isControllerConnected = GCController.controllers().isEmpty == false
        hasPhysicalGamepad = GCController.controllers().contains { !$0.isRemote }
        isKeyboardConnected = GCKeyboard.coalesced != nil
        updateNavigationInputAvailability()
        observeControllerStyleNavigationSetting()
    }

    private func setupNotifications() {
        let connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.connectGamepad()
            self?.isControllerConnected = true
            self?.hasPhysicalGamepad = GCController.controllers().contains { !$0.isRemote }
            self?.updateNavigationInputAvailability()
        }

        let disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DLOG("[GamepadManager] Gamepad disconnected")
            self?.isControllerConnected = !GCController.controllers().isEmpty
            self?.hasPhysicalGamepad = GCController.controllers().contains { !$0.isRemote }
            self?.updateNavigationInputAvailability()
        }

        let keyboardConnectObserver = NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isKeyboardConnected = true
            self?.updateNavigationInputAvailability()
            // PVControllerManager creates the virtual keyboard controller from the same
            // notification; hop the run loop so it exists before we attach handlers.
            DispatchQueue.main.async { self?.connectKeyboardControllerIfAvailable() }
        }

        let keyboardDisconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isKeyboardConnected = GCKeyboard.coalesced != nil
            self?.updateNavigationInputAvailability()
        }

        observers.append(connectObserver)
        observers.append(disconnectObserver)
        observers.append(keyboardConnectObserver)
        observers.append(keyboardDisconnectObserver)

        // Connect to any already-connected gamepad
        connectGamepad()

        // Connect to an already-attached keyboard (covers launch-time connection), if
        // the user has opted into controller-style navigation.
        connectKeyboardControllerIfAvailable()
    }

    /// Recomputes `isNavigationInputAvailable` from its three inputs. Must be called any
    /// time `isControllerConnected`, `isKeyboardConnected`, or
    /// `Defaults[.controllerStyleNavigation]` changes.
    private func updateNavigationInputAvailability() {
        isNavigationInputAvailable = isControllerConnected || (Defaults[.controllerStyleNavigation] && isKeyboardConnected)
    }

    /// React to the user flipping Settings > Controllers > "Controller-Style Navigation"
    /// at runtime — attach/detach the keyboard-controller navigation handlers and
    /// republish `isNavigationInputAvailable` without requiring an app relaunch.
    ///
    /// `.receive(on: DispatchQueue.main)` mirrors the fix applied to the identical
    /// `.GCKeyboardDidConnect`/`.GCKeyboardDidDisconnect` pattern in KeyboardMappingView:
    /// `Defaults.publisher` delivers on whatever thread wrote the key (main for the
    /// Settings toggle today, but not structurally guaranteed — e.g. iCloud KV sync),
    /// and `connectKeyboardControllerIfAvailable()`/`disconnectKeyboardControllerHandlers()`
    /// both hard-trap via `MainActor.assumeIsolated` rather than degrade gracefully off-main.
    private func observeControllerStyleNavigationSetting() {
        Defaults.publisher(.controllerStyleNavigation)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateNavigationInputAvailability()
                if Defaults[.controllerStyleNavigation] {
                    self.connectKeyboardControllerIfAvailable()
                } else {
                    self.disconnectKeyboardControllerHandlers()
                }
            }
            .store(in: &cancellables)
    }

    /// Attach navigation handlers to PVControllerManager's virtual keyboard controller.
    /// Virtual controllers never post GCControllerDidConnect, so connectGamepad() misses them.
    ///
    /// Gated on `Defaults[.controllerStyleNavigation]`: keyboard-driven TVMedia/root-view
    /// navigation is strictly opt-in, so a Magic Keyboard user who never enabled the
    /// setting must not have keystrokes routed into `eventSubject` at all. Not `private`
    /// so `PVControllerManager.rebuildKeyboardController()` (same module) can re-attach
    /// handlers to the freshly rebuilt virtual controller after a key rebind — see its
    /// doc comment for why that call is necessary.
    func connectKeyboardControllerIfAvailable() {
        guard Defaults[.controllerStyleNavigation] else { return }
        MainActor.assumeIsolated {
            guard let keyboardController = PVControllerManager.shared.keyboardController else { return }
            DLOG("[GamepadManager] Attaching navigation handlers to keyboard controller")
            setupBasicControls(keyboardController)
            setupMenuToggleHandlers(keyboardController)
        }
    }

    /// Detach the navigation handlers this class previously attached to the virtual
    /// keyboard controller, so keystrokes stop feeding `eventSubject` the moment
    /// controller-style navigation is turned off at runtime — mirrors exactly the set of
    /// elements `setupBasicControls`/`setupMenuToggleHandlers` attach to.
    private func disconnectKeyboardControllerHandlers() {
        MainActor.assumeIsolated {
            guard let keyboardController = PVControllerManager.shared.keyboardController else { return }
            DLOG("[GamepadManager] Detaching navigation handlers from keyboard controller")
            keyboardController.extendedGamepad?.buttonA.valueChangedHandler = nil
            keyboardController.extendedGamepad?.dpad.valueChangedHandler = nil
            keyboardController.extendedGamepad?.buttonB.valueChangedHandler = nil
            keyboardController.extendedGamepad?.leftShoulder.valueChangedHandler = nil
            keyboardController.extendedGamepad?.rightShoulder.valueChangedHandler = nil
            keyboardController.extendedGamepad?.buttonMenu.valueChangedHandler = nil
            keyboardController.extendedGamepad?.leftTrigger.valueChangedHandler = nil
            keyboardController.extendedGamepad?.buttonOptions?.valueChangedHandler = nil
        }
    }
    
    private func connectGamepad() {
        guard let controller = GCController.current ?? GCController.controllers().first else {
            DLOG("[GamepadManager] No gamepad connected")
            return
        }

        DLOG("[GamepadManager] Gamepad connected and setting up handlers")
        setupBasicControls(controller)
        setupMenuToggleHandlers(controller)
        disableDefaultGestures(controller)
    }
    
    private func setupBasicControls(_ controller: GCController) {
        controller.extendedGamepad?.buttonA.valueChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.eventSubject.send(.buttonPress(pressed))
            }
        }
        
        controller.extendedGamepad?.dpad.valueChangedHandler = { [weak self] dpad, xValue, yValue in
            DispatchQueue.main.async {
                if abs(yValue) == 1.0 {
                    self?.eventSubject.send(.verticalNavigation(yValue, dpad.up.isPressed || dpad.down.isPressed))
                } else if abs(xValue) == 1.0 {
                    self?.eventSubject.send(.horizontalNavigation(xValue, dpad.left.isPressed || dpad.right.isPressed))
                }
            }
        }
        
        controller.extendedGamepad?.buttonB.valueChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.eventSubject.send(.buttonB(pressed))
            }
        }
        
        controller.extendedGamepad?.leftShoulder.valueChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.eventSubject.send(.shoulderLeft(pressed))
            }
        }
        
        controller.extendedGamepad?.rightShoulder.valueChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.eventSubject.send(.shoulderRight(pressed))
            }
        }
        
        controller.extendedGamepad?.buttonMenu.valueChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.eventSubject.send(.start(pressed))
            }
        }
    }
    
    private func setupMenuToggleHandlers(_ controller: GCController) {
        controller.extendedGamepad?.leftTrigger.valueChangedHandler = { [weak self] button, _, _ in
            DispatchQueue.main.async {
                self?.eventSubject.send(.menuToggle(button.isPressed))
            }
        }
        
        controller.extendedGamepad?.buttonOptions?.valueChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.eventSubject.send(.menuToggle(pressed))
            }
        }
    }
    
    private func disableDefaultGestures(_ controller: GCController) {
        controller.buttonOptions?.preferredSystemGestureState = .disabled
        controller.buttonMenu?.preferredSystemGestureState    = .disabled
        controller.buttonHome?.preferredSystemGestureState    = .disabled
    }
}
