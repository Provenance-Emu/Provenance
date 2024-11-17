import Foundation
import GameController
import SwiftUI
import Combine

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
}
