//
//  PauseMenuNavigationInput.swift
//  PVUI
//
//  Controller navigation for the pause menu grid on iOS.
//

import Combine
import Foundation
import GameController

/// One step of controller navigation in the pause menu.
enum PauseMenuNavigationCommand: Equatable, Sendable {
    case up, down, left, right
    /// The pad's A / Cross button.
    case activate
    /// The pad's B / Circle button.
    case back
    /// L1 and R1: the page before and after.
    case previousTab, nextTab
    /// The pad's X / Square and Y / Triangle buttons.
    case quickSave, quickLoad

    /// Held directions repeat.
    static let directions: [PauseMenuNavigationCommand] = [.up, .down, .left, .right]
    /// Buttons fire once per press.
    static let buttons: [PauseMenuNavigationCommand] = [.activate, .back, .previousTab, .nextTab, .quickSave, .quickLoad]
}

/// What the pads are holding, merged across every connected controller.
struct PauseMenuNavigationSample: Equatable, Sendable {
    var held: Set<PauseMenuNavigationCommand> = []
}

/// Turns successive samples into navigation commands: one per press, and a held
/// direction repeats so a long grid can be crossed without tapping.
struct PauseMenuNavigationRepeater: Sendable {
    /// How long a direction is held before it starts repeating.
    static let initialDelay: TimeInterval = 0.4
    static let repeatInterval: TimeInterval = 0.12

    private var held: Set<PauseMenuNavigationCommand>?
    private var nextRepeat: [PauseMenuNavigationCommand: TimeInterval] = [:]

    /// Returns the commands that fire on this sample.
    ///
    /// The first sample only records what is held: the button that opened the menu, or
    /// one still down from the game, must be released before it counts.
    mutating func update(with sample: PauseMenuNavigationSample, at uptime: TimeInterval) -> [PauseMenuNavigationCommand] {
        defer { held = sample.held }
        guard let held else { return [] }
        var fired: [PauseMenuNavigationCommand] = []
        for command in PauseMenuNavigationCommand.directions + PauseMenuNavigationCommand.buttons {
            guard sample.held.contains(command) else {
                nextRepeat[command] = nil
                continue
            }
            if !held.contains(command) {
                fired.append(command)
                nextRepeat[command] = uptime + Self.initialDelay
            } else if PauseMenuNavigationCommand.directions.contains(command),
                      let due = nextRepeat[command], uptime >= due {
                fired.append(command)
                nextRepeat[command] = uptime + Self.repeatInterval
            }
        }
        return fired
    }
}

#if canImport(UIKit)
/// Reads the connected pads while the pause menu is on screen and publishes navigation commands.
///
/// iOS has no focus engine for buttons without a hardware keyboard, and the shared
/// `GamepadManager` handlers follow one controller's d-pad and are lost when a core installs
/// its own handlers on the same elements. Sampling every pad covers the left stick and any
/// connected controller, and depends on no handler. tvOS moves the cursor with its focus
/// engine and takes only the shoulder buttons from here.
@MainActor
final class PauseMenuControllerInput {
    /// How far a stick must be pushed to count as a direction.
    private static let stickThreshold: Float = 0.5

    let commands = PassthroughSubject<PauseMenuNavigationCommand, Never>()

    private var repeater = PauseMenuNavigationRepeater()
    private var displayLink: OwnedDisplayLink?

    func start() {
        guard displayLink == nil else { return }
        repeater = PauseMenuNavigationRepeater()
        let link = OwnedDisplayLink(owner: self) { [weak self] in self?.sample() }
        link.start()
        displayLink = link
    }

    func stop() {
        displayLink?.stop()
        displayLink = nil
    }

    private func sample() {
        var held: Set<PauseMenuNavigationCommand> = []
        for controller in PVControllerManager.shared.controllers {
            /// The keyboard-backed controller is a snapshot; it navigates only where
            /// keyboard-driven navigation is on (Mac, or the iPad setting).
            if controller.isSnapshot, !GamepadManager.isDesktopInputMode { continue }
            guard let gamepad = controller.extendedGamepad else { continue }
            let stick = gamepad.leftThumbstick
            if gamepad.dpad.up.isPressed || stick.yAxis.value > Self.stickThreshold { held.insert(.up) }
            if gamepad.dpad.down.isPressed || stick.yAxis.value < -Self.stickThreshold { held.insert(.down) }
            if gamepad.dpad.left.isPressed || stick.xAxis.value < -Self.stickThreshold { held.insert(.left) }
            if gamepad.dpad.right.isPressed || stick.xAxis.value > Self.stickThreshold { held.insert(.right) }
            if gamepad.buttonA.isPressed { held.insert(.activate) }
            if gamepad.buttonB.isPressed { held.insert(.back) }
            if gamepad.leftShoulder.isPressed { held.insert(.previousTab) }
            if gamepad.rightShoulder.isPressed { held.insert(.nextTab) }
            if gamepad.buttonX.isPressed { held.insert(.quickSave) }
            if gamepad.buttonY.isPressed { held.insert(.quickLoad) }
        }
        let uptime = ProcessInfo.processInfo.systemUptime
        for command in repeater.update(with: PauseMenuNavigationSample(held: held), at: uptime) {
            commands.send(command)
        }
    }
}
#endif
