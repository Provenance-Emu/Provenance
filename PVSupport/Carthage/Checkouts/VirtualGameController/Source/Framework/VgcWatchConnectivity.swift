//
//  VgcWatchConnectivity.swift
//  
//
//  Created by Rob Reuss on 10/4/15.
//
//

import Foundation
#if !(os(tvOS)) && !(os(OSX))
import WatchKit
import WatchConnectivity
    
    public class VgcWatchConnectivity: NSObject, WCSessionDelegate, URLSessionDelegate {


    @objc public let elements = Elements()
    @objc var session: WCSession!
    @objc var httpSession: URLSession!
    @objc public var motion: VgcMotionManager!
    
    public typealias VgcValueChangedHandler = (Element) -> Void
    @objc public var valueChangedHandler: VgcValueChangedHandler!
    
    public override init() {
      
        super.init()
        
        #if swift(>=4)
            session = WCSession.default
        #else
            session = WCSession.default()
        #endif
        session.delegate = self
        session.activate()
        
        #if os(watchOS)
        motion = VgcMotionManager()
        motion.elements = VgcManager.elements
        motion.deviceSupportsMotion = true
        //motion.updateInterval = 1.0 / 30
        
        motion.watchConnectivity = self
        #endif
        
    }
    
    @objc public func sendElementState(element: Element) {
        
        if session.isReachable {
            let message = ["\(element.identifier)": element.value]
            vgcLogDebug("Watch connectivity sending message: \(message) for element \(element.name) with value \(element.value)")
            session.sendMessage(message , replyHandler: { (content:[String : Any]) -> Void in
                // Response to message shows up here
                }, errorHandler: {  (error ) -> Void in
                    vgcLogError("Received an error while attempt to send element \(element) to bridge: \(error)")
            })
        } else {
            vgcLogError("Unable to send element \(element) because bridge is unreachable")
        }
    }

    @nonobjc public func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        
        vgcLogDebug("Received message: \(message)")
        
        for elementTypeString: String in message.keys {
            
            let element = elements.elementFromIdentifier(Int(elementTypeString)!)
            element?.value = message[elementTypeString]!
            
            if element?.identifier == elements.vibrateDevice.identifier {
                
                #if os(watchOS)
                    WKInterfaceDevice.current().play(WKHapticType.click)
                #endif
                
            } else {

                vgcLogDebug("Calling handler with element: \(String(describing: element?.identifier)): \(String(describing: element?.value))")
                
                if let handler = valueChangedHandler {
                    handler(element!)
                }
                
            }
            
        }
    }
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        
        vgcLogDebug("Reachability changed to \(session.isReachable)")

        if session.isReachable == false {
            vgcLogDebug("Stopping motion")
            motion.stop()
        }
        
    }
        
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    @available(watchOS 2.2, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        vgcLogDebug("activationDidCompleteWith")
    }

}
#endif
