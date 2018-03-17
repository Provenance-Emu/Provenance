//
//  PVGBControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVGB

fileprivate extension JSButton {
    var buttonTag : PVGBButton {
        get {
            return PVGBButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVGBControllerViewController: PVControllerViewController<PVGBEmulatorCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            if (button.titleLabel?.text == "A") {
                button.buttonTag = .A
            }
            else if (button.titleLabel?.text == "B") {
                button.buttonTag = .B
            }
        }

        startButton?.buttonTag = .start
        selectButton?.buttonTag = .select
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let gbCore = emulatorCore
        gbCore?.release(.left)
        gbCore?.release(.right)
        gbCore?.release(.up)
        gbCore?.release(.down)
        switch direction {
            case .upLeft:
                gbCore?.push(.up)
                gbCore?.push(.left)
            case .up:
                gbCore?.push(.up)
            case .upRight:
                gbCore?.push(.up)
                gbCore?.push(.right)
            case .left:
                gbCore?.push(.left)
            case .right:
                gbCore?.push(.right)
            case .downLeft:
                gbCore?.push(.down)
                gbCore?.push(.left)
            case .down:
                gbCore?.push(.down)
            case .downRight:
                gbCore?.push(.down)
                gbCore?.push(.right)
            default:
                break
        }
        super.dPad(dPad, didPress: direction)
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        guard let emulatorCore = emulatorCore else {
            return
        }
        emulatorCore.release(.up)
        emulatorCore.release(.down)
        emulatorCore.release(.left)
        emulatorCore.release(.right)
        super.dPadDidReleaseDirection(dPad)
    }

    override func buttonPressed(_ button: JSButton) {
        let gbCore = emulatorCore
        gbCore?.push(button.buttonTag)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        let gbCore = emulatorCore
        gbCore?.release(button.buttonTag)
        super.buttonReleased(button)
    }

    override func pressStart(forPlayer player: Int) {
        let gbCore = emulatorCore
        gbCore?.push(.start)
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        let gbCore = emulatorCore
        gbCore?.release(.start)
        super.releaseStart(forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        let gbCore = emulatorCore
        gbCore?.push(.select)
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        let gbCore = emulatorCore
        gbCore?.release(.select)
        super.releaseSelect(forPlayer: player)
    }
}
