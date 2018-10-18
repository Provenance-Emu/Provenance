//
//  VgcWatch.swift
//  
//
//  Created by Rob Reuss on 12/18/15.
//
//

import Foundation
#if os(iOS)
import WatchConnectivity
#endif

#if !os(watchOS)

@objc internal protocol VgcWatchDelegate {
    
    func receivedWatchMessage(_ element: Element)
    
}

public let VgcWatchDidConnectNotification:     String = "VgcWatchDidConnectNotification"
public let VgcWatchDidDisconnectNotification:  String = "VgcWatchDidDisconnectNotification"

#if os(iOS)
    open class VgcWatch: NSObject, WCSessionDelegate {

    var delegate: VgcWatchDelegate!
    var wcSession: WCSession!
    var watchController: VgcController!
    var centralPublisher: VgcCentralPublisher!
    open var reachable: Bool = false
    
    public typealias VgcValueChangedHandler = (Element) -> Void
    open var valueChangedHandler: VgcValueChangedHandler!
    
    init(delegate: VgcWatchDelegate) {
        
        self.delegate = delegate
        
        super.init()
        
        scanForWatch()
        
    }
    
    func scanForWatch() {

        
        if WCSession.isSupported() {
            vgcLogDebug("Watch connectivity is supported, activating")
            if self.wcSession == nil {
                vgcLogDebug("Setting up watch session")
                #if swift(>=4)
                self.wcSession = WCSession.default
                #else
                self.wcSession = WCSession.default()
                #endif
                
                self.wcSession.delegate = self
            }
            self.wcSession.activate()
            if self.wcSession.isPaired == false {
                vgcLogDebug("There is no watch paired with this device")
                return
            }
            if self.wcSession.isWatchAppInstalled == false {
                vgcLogDebug("The watch app is not installed")
                return
            }
            if self.wcSession.isReachable == true {
                
                vgcLogDebug("Watch is reachable")
                reachable = wcSession.isReachable
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: VgcWatchDidConnectNotification), object: nil)
                
            } else {
                vgcLogDebug("Watch is not reachable")
            }
        } else {
            vgcLogDebug("Watch connectivity is not supported on this platform")
        }
        
    }
    
    open func sessionReachabilityDidChange(_ session: WCSession) {
        
        vgcLogDebug("Watch reachability changed to \(session.isReachable)")
        reachable = wcSession.isReachable
        
        if reachable {
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: VgcWatchDidConnectNotification), object: nil)

        } else {
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: VgcWatchDidDisconnectNotification), object: nil)

        }
        
    }
    
    open func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        
        vgcLogDebug("Watch connectivity received message: " + message.description)
        for elementTypeString: String in message.keys {
            
            let element = VgcManager.elements.elementFromIdentifier(Int(elementTypeString)!)
            element?.value = message[elementTypeString]! as AnyObject
            
            if let handler = valueChangedHandler {
                handler(element!)
            } else {
                delegate.receivedWatchMessage(element!)
            }
            
        }
    }
        
    
    // Called when all delegate callbacks for the previously selected watch has occurred. The session can be re-activated for the now selected watch using activateSession. */
    @available(iOS 9.3, *)
    open func sessionDidDeactivate(_ session: WCSession) {
        vgcLogDebug("Watch sessionDidDeactivate")
    }
    
    
    // Called when the session can no longer be used to modify or add any new transfers and, all interactive messages will be cancelled, but delegate callbacks for background transfers can still occur. This will happen when the selected watch is being changed. */
    @available(iOS 9.3, *)
    open func sessionDidBecomeInactive(_ session: WCSession) {
        vgcLogDebug("Watch sessionDidBecomeInactive")
    }
    

    // Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    @available(iOS 9.3, *)
    open func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        vgcLogDebug("Watch activationDidCompleteWith activationState")
    }
        
    open func sendElementState(_ element: Element) {
        
        if wcSession != nil && wcSession.isReachable {
            let message = ["\(element.identifier)": element.value]
            wcSession.sendMessage(message , replyHandler: { (content:[String : Any]) -> Void in
                vgcLogDebug("Watch Connectivity: Our counterpart sent something back. This is optional")
                }, errorHandler: {  (error ) -> Void in
                    vgcLogDebug("Watch Connectivity: We got an error from our paired device : \(error)")
            })
        }
        
    }
}
#endif
#endif
