//
//  FirstResponderViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/27/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import SwiftUI
import Foundation
import PVUIBase

public struct FirstResponderViewControllerWrapper: UIViewControllerRepresentable {
    public init() {
        
    }
    public func makeUIViewController(context: Context) -> FirstResponderViewController {
        let vc = FirstResponderViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    public func updateUIViewController(_ uiViewController: FirstResponderViewController, context: Context) {
        // Update the view controller if needed
    }
}

open class FirstResponderViewController: UIViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    public override var canBecomeFirstResponder: Bool {
        return true
    }

    // Handle and forward touch events
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleAndForwardTouches(touches, with: event)
        super.touchesBegan(touches, with: event)
        next?.touchesBegan(touches, with: event)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleAndForwardTouches(touches, with: event)
        super.touchesMoved(touches, with: event)
        next?.touchesMoved(touches, with: event)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleAndForwardTouches(touches, with: event)
        super.touchesEnded(touches, with: event)
        next?.touchesEnded(touches, with: event)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleAndForwardTouches(touches, with: event)
        super.touchesCancelled(touches, with: event)
        next?.touchesCancelled(touches, with: event)
    }

    private func handleAndForwardTouches(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle the event here (e.g., send to emulator core)
        print("Handling touch event: \(event?.type.rawValue ?? -1)")
        if let core = AppState.shared.emulationState.core {
            core.sendEvent(event)
        }
    }

    // Handle and forward motion events
    public override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        handleAndForwardMotion(motion, with: event)
        super.motionBegan(motion, with: event)
        next?.motionBegan(motion, with: event)
    }

    public override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        handleAndForwardMotion(motion, with: event)
        super.motionEnded(motion, with: event)
        next?.motionEnded(motion, with: event)
    }

    public override func motionCancelled(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        handleAndForwardMotion(motion, with: event)
        super.motionCancelled(motion, with: event)
        next?.motionCancelled(motion, with: event)
    }

    private func handleAndForwardMotion(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        // Handle the motion event here (e.g., send to emulator core)
        print("Handling motion event: \(motion.rawValue)")
        if let core = AppState.shared.emulationState.core {
            core.sendEvent(event)
        }
    }

    // Optionally, handle remote control events
    public override func remoteControlReceived(with event: UIEvent?) {
        // Handle remote control event (e.g., send to emulator core)
        print("Handling remote control event: \(event?.subtype.rawValue ?? -1)")

        // Forward the event to the next responder in the responder chain
        super.remoteControlReceived(with: event)
        if let core = AppState.shared.emulationState.core {
            core.sendEvent(event)
        }
    }
}
