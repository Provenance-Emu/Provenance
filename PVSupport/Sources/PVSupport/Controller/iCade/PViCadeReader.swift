//
//  PViCadeReader.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/29/18.
//  Copyright (c) 2018 Joseph Mattiello. All rights reserved.
//

#if canImport(UIKit) && canImport(GameController)
import UIKit
import PVLogging

public typealias iCadeButtonEventHandler = ((_ button: iCadeControllerState) -> Void)
public typealias iCadeStateEventHandler =  ((_ state: iCadeControllerState) -> Void)

@MainActor
public final class PViCadeReader: NSObject, Sendable {
    var stateChangedHandler: iCadeStateEventHandler? = nil
    var buttonDownHandler: iCadeButtonEventHandler? = nil
    var buttonUpHandler: iCadeButtonEventHandler? = nil
    
    @MainActor
    var internalReader: iCadeReaderView = iCadeReaderView(frame: CGRect.zero)
    
    @MainActor
    init(stateChangedHandler: iCadeStateEventHandler? = nil, buttonDownHandler: iCadeButtonEventHandler? = nil, buttonUpHandler: iCadeButtonEventHandler? = nil, internalReader: iCadeReaderView) {
        self.stateChangedHandler = stateChangedHandler
        self.buttonDownHandler = buttonDownHandler
        self.buttonUpHandler = buttonUpHandler
        self.internalReader = internalReader
    }
    
    @MainActor
    public convenience init(stateChangedHandler: iCadeStateEventHandler?, buttonDownHandler: iCadeButtonEventHandler?, buttonUpHandler: iCadeButtonEventHandler?) {
        self.init(stateChangedHandler: stateChangedHandler, buttonDownHandler: buttonDownHandler, buttonUpHandler: buttonUpHandler, internalReader: iCadeReaderView(frame: CGRect.zero))
    }
    
    @preconcurrency
    public struct SharedPViCadeReader: @unchecked Sendable {
        public let shared: PViCadeReader
    }
    
    @MainActor
    public static var shared: SharedPViCadeReader = SharedPViCadeReader(shared: PViCadeReader(internalReader: iCadeReaderView(frame: CGRect.zero)))
    
    @MainActor
    public func listen(to window: UIWindow? = nil) {
        // get the window from the current UIScene//
        let scene = UIApplication.shared.connectedScenes.first(where: {
                    $0.activationState == .foregroundActive }) as? UIWindowScene
        let keyWindow: UIWindow? = scene?.windows.first { $0.isKeyWindow }
                                                 
        // the old way
//        let keyWindow: UIWindow? = window ?? UIApplication.shared.windows.first { $0.isKeyWindow }
        if keyWindow != internalReader.window {
            internalReader.removeFromSuperview()
            keyWindow?.addSubview(internalReader)
        } else {
            keyWindow?.bringSubviewToFront(internalReader)
        }
        internalReader.delegate = self
        internalReader.active = true
    }
    
    @MainActor
    public func listenToKeyWindow() {
        listen(to: nil)
    }
    
    @MainActor
    public func stopListening() {
        internalReader.active = false
        internalReader.delegate = nil
        internalReader.removeFromSuperview()
    }
    
    @MainActor
    public var states: [iCadeControllerState] {
        return internalReader.states
    }
}

extension PViCadeReader: @preconcurrency iCadeEventDelegate {
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
#endif
