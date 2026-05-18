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
    /// Tracks whether a full-screen retrowave alert / picker is currently presented
    /// over the root UI. iOS gamepad subscribers (root view, home, sidebar, etc.)
    /// should early-return when this is `true` so that A / d-pad presses don't
    /// "leak" through to background views while a modal picker is up.
    ///
    /// tvOS has its own focus-coordinator gating; this flag is intentionally
    /// usable on both platforms but only consulted by iOS subscribers today.
    @Published public var isModalAlertPresented: Bool = false
    private var observers: [NSObjectProtocol] = []
    private let eventSubject = PassthroughSubject<GamepadEvent, Never>()
    
    public var eventPublisher: AnyPublisher<GamepadEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    private init() {
        setupNotifications()
        isControllerConnected = GCController.controllers().isEmpty == false
        hasPhysicalGamepad = GCController.controllers().contains { !$0.isRemote }
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
        }

        let disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DLOG("[GamepadManager] Gamepad disconnected")
            self?.isControllerConnected = !GCController.controllers().isEmpty
            self?.hasPhysicalGamepad = GCController.controllers().contains { !$0.isRemote }
        }
        
        observers.append(connectObserver)
        observers.append(disconnectObserver)
        
        // Connect to any already-connected gamepad
        connectGamepad()
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
