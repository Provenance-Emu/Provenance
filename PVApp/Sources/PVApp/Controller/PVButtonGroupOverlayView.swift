//
//  PVButtonOverlayView.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
import PVLogging

final class PVButtonGroupOverlayView: MovableButtonView {
    var buttons = [JSButton]()

    init(buttons: [JSButton]) {
        super.init(frame: CGRect.zero)

#if os(iOS)
        isMultipleTouchEnabled = true
#endif
        backgroundColor = UIColor.clear
        self.buttons = buttons
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if inMoveMode {
            super.touchesBegan(touches, with: event)
            return
        }
        let touch = touches.first!
        let location = touch.location(in: self)
        for button: JSButton in buttons {
            let touchArea = CGRect(x: location.x - 10, y: location.y - 10, width: 20, height: 20)
            let buttonFrame: CGRect = convert(button.frame, to: self)
            if touchArea.intersects(buttonFrame) {
                button.touchesBegan(touches, with: event)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if inMoveMode {
            super.touchesMoved(touches, with: event)
            return
        }
		guard let touch = touches.first else {
			ELOG("No touches!?")
			return
		}
        let location = touch.location(in: self)
        for button: JSButton in buttons {
            let touchArea = CGRect(x: location.x - 10, y: location.y - 10, width: 20, height: 20)
            let buttonFrame: CGRect = convert(button.frame, to: self)
            if touchArea.intersects(buttonFrame) {
                button.touchesMoved(touches, with: event)
            } else if button.pressed {
                button.touchesEnded(touches, with: event)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if inMoveMode {
            super.touchesCancelled(touches, with: event)
            return
        }
        for button: JSButton in buttons {
            button.touchesCancelled(touches, with: event)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if inMoveMode {
            super.touchesEnded(touches, with: event)
            return
        }
        for button: JSButton in buttons {
            button.touchesEnded(touches, with: event)
        }
    }

    var isMovable: Bool {
        return true
    }

	override func didStartMoving() {
		super.didStartMoving()
		buttons.forEach { $0.isUserInteractionEnabled = false }
	}

	override func didFinishMoving(velocity:CGPoint) {
		super.didFinishMoving(velocity: velocity)
		buttons.forEach { $0.isUserInteractionEnabled = true }
	}
}
