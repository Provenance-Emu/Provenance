//
//  PVStellaControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVSupport
import PVEmulatorCore
import SwiftUI

private extension JSButton {
    var buttonTag: PV2600Button {
        get {
            return PV2600Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVAtari2600ControllerViewController: PVControllerViewController<PV2600SystemResponderClient> {

    private var hardwareSwitchHostingVC: UIViewController?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        addHardwareSwitchOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionHardwareSwitchOverlay()
    }

    // MARK: - Hardware switch overlay

    private func addHardwareSwitchOverlay() {
        let switches = [
            HardwareSwitchDescriptor(
                id: "left_diff",
                title: "LEFT DIFF",
                offPosition: HardwareSwitchPosition(label: "B", buttonId: "leftdiffb"),
                onPosition:  HardwareSwitchPosition(label: "A", buttonId: "leftdiffa"),
                defaultState: false
            ),
            HardwareSwitchDescriptor(
                id: "right_diff",
                title: "RIGHT DIFF",
                offPosition: HardwareSwitchPosition(label: "B", buttonId: "rightdiffb"),
                onPosition:  HardwareSwitchPosition(label: "A", buttonId: "rightdiffa"),
                defaultState: false
            )
        ]

        let switchRow = HardwareSwitchRowView(switches: switches) { [weak self] buttonId, _ in
            self?.handleHardwareSwitchToggle(buttonId: buttonId)
        }

        let hostingVC = UIHostingController(rootView: switchRow)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.isOpaque = false

        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)
        hardwareSwitchHostingVC = hostingVC
        positionHardwareSwitchOverlay()
    }

    private func positionHardwareSwitchOverlay() {
        guard let hostingVC = hardwareSwitchHostingVC else { return }
        let preferredSize = CGSize(width: 160, height: 50)
        let x = view.bounds.width - preferredSize.width - 12
        let y: CGFloat = 8
        hostingVC.view.frame = CGRect(origin: CGPoint(x: x, y: y), size: preferredSize)
        view.bringSubviewToFront(hostingVC.view)
    }

    private func handleHardwareSwitchToggle(buttonId: String) {
        // Route the button press through the core responder
        emulatorCore.didPush(PV2600Button(buttonId), forPlayer: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.emulatorCore.didRelease(PV2600Button(buttonId), forPlayer: 0)
        }
    }

    // MARK: - Control layout

    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            switch title.lowercased() {
            case "fire", "":
                button.buttonTag = .fire1
            case "select":
                button.buttonTag = .select
            case "reset", "start":
                button.buttonTag = .reset
            default:
                break
            }
        }

        startButton?.buttonTag = .reset
        selectButton?.buttonTag = .select
    }

    override func dPad(_: JSDPad, didPress direction: JSDPadDirection) {
        emulatorCore.didRelease(.up, forPlayer: 0)
        emulatorCore.didRelease(.down, forPlayer: 0)
        emulatorCore.didRelease(.left, forPlayer: 0)
        emulatorCore.didRelease(.right, forPlayer: 0)
        switch direction {
        case .upLeft:
            emulatorCore.didPush(.up, forPlayer: 0)
            emulatorCore.didPush(.left, forPlayer: 0)
        case .up:
            emulatorCore.didPush(.up, forPlayer: 0)
        case .upRight:
            emulatorCore.didPush(.up, forPlayer: 0)
            emulatorCore.didPush(.right, forPlayer: 0)
        case .left:
            emulatorCore.didPush(.left, forPlayer: 0)
        case .right:
            emulatorCore.didPush(.right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didPush(.down, forPlayer: 0)
            emulatorCore.didPush(.left, forPlayer: 0)
        case .down:
            emulatorCore.didPush(.down, forPlayer: 0)
        case .downRight:
            emulatorCore.didPush(.down, forPlayer: 0)
            emulatorCore.didPush(.right, forPlayer: 0)
        default:
            break
        }
        vibrate()
    }

   override func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection) {
        switch direction {
        case .upLeft:
            emulatorCore.didRelease(.up, forPlayer: 0)
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .up:
            emulatorCore.didRelease(.up, forPlayer: 0)
        case .upRight:
            emulatorCore.didRelease(.up, forPlayer: 0)
            emulatorCore.didRelease(.right, forPlayer: 0)
        case .left:
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .none:
            break
        case .right:
            emulatorCore.didRelease(.right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didRelease(.down, forPlayer: 0)
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .down:
            emulatorCore.didRelease(.down, forPlayer: 0)
        case .downRight:
            emulatorCore.didRelease(.down, forPlayer: 0)
            emulatorCore.didRelease(.right, forPlayer: 0)
        }
    }

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(.reset, forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.reset, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.select, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.select, forPlayer: player)
    }
}
