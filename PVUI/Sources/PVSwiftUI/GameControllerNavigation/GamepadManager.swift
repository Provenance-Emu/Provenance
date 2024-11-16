import Foundation
import GameController
import SwiftUI

public protocol GamepadNavigationDelegate {
    var focusedSection: GameSection? { get }
    var focusedItemInSection: String? { get }

    func handleButtonPress()
    func handleVerticalNavigation(_ yValue: Float)
    func handleHorizontalNavigation(_ xValue: Float)
}

public class GamepadManager {
    public static let shared = GamepadManager()

    private var observers: [NSObjectProtocol] = []
    private var navigationDelegate: (any GamepadNavigationDelegate)?

    private init() {
        setupNotifications()
    }

    public func setDelegate(_ delegate: (any GamepadNavigationDelegate)) {
        navigationDelegate = delegate
        connectGamepad()
    }

    private func setupNotifications() {
        let connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.connectGamepad()
        }

        observers.append(connectObserver)
    }

    private func connectGamepad() {
        guard let controller = GCController.current ?? GCController.controllers().first else {
            print("No gamepad connected")
            return
        }

        print("Gamepad connected and setting up handlers")

        controller.extendedGamepad?.buttonA.valueChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }

            DispatchQueue.main.async {
                self?.navigationDelegate?.handleButtonPress()
            }
        }

        controller.extendedGamepad?.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            DispatchQueue.main.async {
                if abs(yValue) == 1.0 {
                    self?.navigationDelegate?.handleVerticalNavigation(yValue)
                } else if abs(xValue) == 1.0 {
                    self?.navigationDelegate?.handleHorizontalNavigation(xValue)
                }
            }
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
