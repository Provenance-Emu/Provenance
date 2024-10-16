//
//  GameControllerManager.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/15/24.
//


import SwiftUI
import GameController

public final class GameControllerManager: ObservableObject {

    @Published var currentFocusIndex: Int = 0
    var totalItems: Int = 20 // Update this based on your actual item count
    var columns: Int = 3 // Update this based on your grid layout

    @Published var controller: GCController?
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(controllerConnected), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDisconnected), name: .GCControllerDidDisconnect, object: nil)
    }
    
    @objc func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        self.controller = controller
        setupControllerControls(controller)
    }
    
    @objc func controllerDisconnected(_ notification: Notification) {
        self.controller = nil
    }
    
    func setupControllerControls(_ controller: GCController) {
        controller.extendedGamepad?.dpad.valueChangedHandler = { [weak self] (dpad, xValue, yValue) in
            self?.handleDPadInput(x: xValue, y: yValue)
        }
    }
    
    
    func handleDPadInput(x: Float, y: Float) {
        if x > 0 {
            moveFocus(.right)
        } else if x < 0 {
            moveFocus(.left)
        } else if y > 0 {
            moveFocus(.down)
        } else if y < 0 {
            moveFocus(.up)
        }
    }
    
    func moveFocus(_ direction: Direction) {
        switch direction {
        case .up:
            if currentFocusIndex >= columns {
                currentFocusIndex -= columns
            }
        case .down:
            if currentFocusIndex + columns < totalItems {
                currentFocusIndex += columns
            }
        case .left:
            if currentFocusIndex % columns != 0 {
                currentFocusIndex -= 1
            }
        case .right:
            if (currentFocusIndex + 1) % columns != 0 && currentFocusIndex < totalItems - 1 {
                currentFocusIndex += 1
            }
        }
    }
    
    enum Selection {
        case primary, secondary
    }
    
    enum Pagination {
        case up, down, left, right
    }
    
    enum Direction {
        case up, down, left, right
    }
}
