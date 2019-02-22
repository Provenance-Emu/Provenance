//
//  PViCadeReader.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/29/18.
//  Copyright (c) 2018 Joseph Mattiello. All rights reserved.
//

import UIKit

public typealias iCadeButtonEventHandler = (_ button: iCadeControllerState) -> Void
public typealias iCadeStateEventHandler = (_ state: iCadeControllerState) -> Void

public final class PViCadeReader: NSObject, iCadeEventDelegate {
    var stateChangedHandler: iCadeStateEventHandler?
    var buttonDownHandler: iCadeButtonEventHandler?
    var buttonUpHandler: iCadeButtonEventHandler?
    var internalReader: iCadeReaderView = iCadeReaderView(frame: CGRect.zero)

    public static var shared: PViCadeReader = PViCadeReader()

    public func listen(to window: UIWindow?) {
        let keyWindow: UIWindow? = window ?? UIApplication.shared.keyWindow
        if keyWindow != internalReader.window {
            internalReader.removeFromSuperview()
            keyWindow?.addSubview(internalReader)
        } else {
            keyWindow?.bringSubviewToFront(internalReader)
        }
        internalReader.delegate = self
        internalReader.active = true
    }

    public func listenToKeyWindow() {
        listen(to: nil)
    }

    public func stopListening() {
        internalReader.active = false
        internalReader.delegate = nil
        internalReader.removeFromSuperview()
    }

    public var states: [iCadeControllerState] {
        return internalReader.states
    }

    deinit {
        internalReader.active = false
        internalReader.delegate = nil
    }

    // MARK: - iCadeEventDelegate

    public func buttonDown(button: iCadeControllerState) {
        #if DEBUG
            if buttonDownHandler == nil { WLOG("No buttonDownHandler set") }
        #endif
        buttonDownHandler?(button)
    }

    public func buttonUp(button: iCadeControllerState) {
        #if DEBUG
            if buttonUpHandler == nil { WLOG("No button up handler set") }
        #endif
        buttonUpHandler?(button)
    }

    public func stateChanged(state: iCadeControllerState) {
        #if DEBUG
            if stateChangedHandler == nil { WLOG("No stateChangedHandler set") }
        #endif
        stateChangedHandler?(state)
    }
}
