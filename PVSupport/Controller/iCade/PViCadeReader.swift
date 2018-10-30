//
//  PViCadeReader.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/29/18.
//  Copyright (c) 2018 Joseph Mattiello. All rights reserved.
//

import UIKit

public typealias iCadeButtonEventHandler = (_ button: Int) -> Void
public typealias iCadeStateEventHandler = (_ state: iCadeControllerState) -> Void

final public class PViCadeReader: NSObject, iCadeEventDelegate {

	var stateChangedHandler: iCadeStateEventHandler? = nil
	var buttonDownHandler: iCadeButtonEventHandler? = nil
    var buttonUpHandler: iCadeButtonEventHandler? = nil
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

	public var state : iCadeControllerState {
        return internalReader.state
    }

// MARK: - iCadeEventDelegate
    public func buttonDown(button: Int) {
		buttonDownHandler?(button)
    }

    public func buttonUp(button: Int) {
		buttonUpHandler?(button)
    }

	public func stateChanged(state: iCadeControllerState) {
		stateChangedHandler?(state)
	}
}
