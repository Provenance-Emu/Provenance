import Foundation
import GameController
import SwiftUI
import Combine

public enum GamepadEvent {
    case buttonPress
    case buttonB
    case verticalNavigation(Float, Bool)
    case horizontalNavigation(Float, Bool)
    case menuToggle
    case shoulderLeft
    case shoulderRight
    case start
}

public class GamepadManager: ObservableObject {
    public static let shared = GamepadManager()

    @Published public private(set) var isControllerConnected: Bool = false
    private var observers: [NSObjectProtocol] = []
    private let eventSubject = PassthroughSubject<GamepadEvent, Never>()

    public var eventPublisher: AnyPublisher<GamepadEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private init() {
        setupNotifications()
        isControllerConnected = GCController.controllers().isEmpty == false
    }

    private func setupNotifications() {
        let connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.connectGamepad()
            self?.isControllerConnected = true
        }

        let disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("Gamepad disconnected")
            self?.isControllerConnected = false
        }

        observers.append(connectObserver)
        observers.append(disconnectObserver)

        // Connect to any already-connected gamepad
        connectGamepad()
    }

    private func connectGamepad() {
        guard let controller = GCController.current ?? GCController.controllers().first else {
            print("No gamepad connected")
            return
        }

        print("Gamepad connected and setting up handlers")
        setupBasicControls(controller)
        setupMenuToggleHandlers(controller)
    }

    private func setupBasicControls(_ controller: GCController) {
        controller.extendedGamepad?.buttonA.valueChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            DispatchQueue.main.async {
                self?.eventSubject.send(.buttonPress)
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
            guard pressed else { return }
            DispatchQueue.main.async {
                self?.eventSubject.send(.buttonB)
            }
        }

        controller.extendedGamepad?.leftShoulder.valueChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            DispatchQueue.main.async {
                self?.eventSubject.send(.shoulderLeft)
            }
        }

        controller.extendedGamepad?.rightShoulder.valueChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            DispatchQueue.main.async {
                self?.eventSubject.send(.shoulderRight)
            }
        }

        controller.extendedGamepad?.buttonMenu.valueChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            DispatchQueue.main.async {
                self?.eventSubject.send(.start)
            }
        }
    }

    private func setupMenuToggleHandlers(_ controller: GCController) {
        /// Handle L2 button using isPressed for digital behavior
        controller.extendedGamepad?.leftTrigger.valueChangedHandler = { [weak self] button, _, _ in
            guard button.isPressed else { return }
            DispatchQueue.main.async {
                self?.eventSubject.send(.menuToggle)
            }
        }

        controller.extendedGamepad?.buttonOptions?.valueChangedHandler = { [weak self] button, _, _ in
            guard button.isPressed else { return }
            DispatchQueue.main.async {
                self?.eventSubject.send(.menuToggle)
            }
        }
    }
}
