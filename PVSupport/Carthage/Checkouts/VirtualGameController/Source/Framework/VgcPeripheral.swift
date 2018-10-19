//
//  VirtualGameControllerPeripheral.swift
//  PeripheralVirtualGameControlleriOSSample
//
//  Created by Rob Reuss on 9/13/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//
//  Testing git

import Foundation

// No CoreBluetooth or GameController on WatchOS
#if os(iOS) || os(OSX) || os(tvOS)
    import CoreBluetooth
    import GameController
#endif

#if os(iOS) || os(tvOS)
    import AudioToolbox
#endif

#if !os(watchOS)

public let VgcPeripheralDidConnectNotification:      String = "VgcPeripheralDidConnectNotification"
public let VgcPeripheralConnectionFailedNotification:String = "VgcPeripheralConnectionFailed"
public let VgcPeripheralDidDisconnectNotification:   String = "VgcPeripheralDidDisconnectNotification"
public let VgcPeripheralFoundService:                String = "VgcPeripheralFoundService"
public let VgcPeripheralLostService:                 String = "VgcPeripheralLostService"
public let VgcPeripheralDidResetBrowser:             String = "VgcPeripheralDidResetBrowser"
public let VgcSystemMessageNotification:             String = "VgcSystemMessageNotification"
public let VgcPeripheralSetupNotification:           String = "VgcPeripheralSetupNotification"
public let VgcNewPlayerIndexNotification:            String = "VgcNewPlayerIndexNotification"

open class Peripheral: NSObject {
    
    fileprivate var vgcDeviceInfo: DeviceInfo!
    var browser: VgcBrowser!
    #if os(iOS)
    open var watch: VgcWatch!
    #endif
    var playerIndex: GCControllerPlayerIndex!
    weak var controller: VgcController!
    var localController: VgcController!
    
    #if !(os(tvOS)) && !(os(OSX))
    @objc open var motion: VgcMotionManager!
    #endif

    open var haveConnectionToCentral: Bool = false
    var haveOpenStreamsToCentral: Bool = false
    var connectionAcknowledgementWaitTimeout: Timer!
    var previousElements = [Element?](repeating: nil, count:VgcManager.elements.allElementsCollection().count + 1)
    
    override init() {
        
        super.init()

        haveConnectionToCentral = false
        
        #if !os(watchOS)
            browser = VgcBrowser(peripheral: self)
        #endif
        
        vgcLogDebug("Setting up motion manager on peripheral")
        #if !os(OSX) && !os(tvOS)
            motion = VgcMotionManager()
        #endif
        
        playerIndex = GCControllerPlayerIndex.indexUnset
  
    }
    
    deinit {
        vgcLogDebug("Peripheral deinitalized")
        if controller != nil { controller.peripheral = nil }
        controller = nil
    }
    
    ///
    /// Key method used to send a change in an element's state to the
    /// Central or Bridge that we're currently connected to with this
    /// Peripheral.  "State" in this case refers to the Element "value"
    /// property.
    ///
    @objc open func sendElementState(_ element: Element) {
        
        if previousElements.count > 0 && element.dataType == .Float && VgcManager.enableDupFiltering {
            if let previousElement = previousElements[element.type.rawValue] {
                let previousElementValue = String(format: "%.\(VgcManager.dupFilteringPrecision)f", previousElement.value as! Float)
                let currentElementValue = String(format: "%.\(VgcManager.dupFilteringPrecision)f", element.value as! Float)
                if previousElementValue == currentElementValue {
                    vgcLogVerbose("Not sending value because it's the same as last sent: \(previousElementValue)")
                    return
                }
            }
            previousElements[element.type.rawValue]?.value = element.value

        }
        
        // As a Peripheral, we don't need a connection to send if we're an EnhancementBridge, using instead the
        // stream associated with the hardware controllers VgcController.
        if haveConnectionToCentral == true || deviceIsTypeOfBridge() {
            
            //vgcLogDebug("Sending: \(element.name): \(element.value)")
            
            // If we're enhancing a hardware controller with virtual elements, we pass values through to the controller
            // so they appear to the Central as coming from the hardware controller
            if VgcManager.appRole == .EnhancementBridge && VgcController.enhancedController != nil {
                VgcController.enhancedController.peripheral.browser.sendElementStateOverNetService(element)
            } else {
                browser.sendElementStateOverNetService(element)
            }
            
            //vgcLogDebug("Element to be mapped: \(element.name)")
            if VgcManager.usePeripheralSideMapping == true {
                // Only map an element if it isn't the result of a mapping
                if (element.mappingComplete == false) {
                    mapElement(element, peripheral: self)
                }
            }
            
            element.mappingComplete = false
            
        } else {
            
            vgcLogError("Attempted to send without a connection: \(element.name): \(element.value)")
            
        }
        
        if (self.localController != nil) { self.localController.updateGameControllerWithValue(element) }
        
    }
    
    ///
    /// DeviceInfo for the controller represented by this Peripheral instance.
    ///
    @objc open var deviceInfo: DeviceInfo! {
        
        get {
            if vgcDeviceInfo == nil {
                vgcLogError("Required value deviceInfo not set")
                return nil
            }
            return vgcDeviceInfo
        }
        
        set {
            
            vgcDeviceInfo = newValue
            
            #if os(iOS)

                motion.deviceSupportsMotion = deviceInfo.supportsMotion
                
                // Override device info parameter if the hardware doesn't support motion
                if motion.manager.isDeviceMotionAvailable == false { deviceInfo.supportsMotion = false } else { deviceInfo.supportsMotion = true }
                
            #endif
            
            if let localCtrlr = self.localController {
                if VgcManager.enableLocalController {
                    localCtrlr.deviceInfo = newValue
                    vgcLogDebug("Device info set on LOCAL controller")
                    print(newValue)
                }
            }
            
            haveConnectionToCentral = false
            
        }
        
    }
    
    ///
    /// Connect to a Central or Bridge using a VgcService object obtained
    /// by browsing the network.
    ///
    @objc open func connectToService(_ vgcService: VgcService) {
        browser.connectToService(vgcService)
    }
    
    @objc open func disconnectFromService() {
        
        if haveConnectionToCentral == false { return }
        
        vgcLogDebug("Disconnecting from Central")
        
        haveConnectionToCentral = false
        
        browser.disconnectFromCentral()
        
    }
    
    @objc open func browseForServices() {
        
        browser.reset()
        
        vgcLogDebug("Browsing for services...")
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralDidResetBrowser), object: nil)
        
        // If we're a bridge, this peripheral is a controller-specific instance.  If the controller is no
        // longer in the array of controllers, it means it has disconnected and we don't want to advertise it
        // any longer.
        if deviceIsTypeOfBridge() {
            let (existsAlready, _) = VgcController.controllerAlreadyExists(controller)
            if existsAlready == false {
                vgcLogDebug("Refusing to announce Bridge-to-Central peripheral because it's controller no longer exists.  If the controller is MFi, it may have gone to sleep.")
                return
            }
        }
        
        browser.browseForCentral()
        
    }
    
    @objc open func stopBrowsingForServices() {
        
        if deviceIsTypeOfBridge() {
            vgcLogDebug("Refusing to stop browsing for service because I am a BRIDGE")
        } else {
            vgcLogDebug("Stopping browsing for services")
        }
        browser.stopBrowsing()
        
    }
    
    @objc open var connectedService: VgcService? {
        get {
            guard let service = browser.connectedVgcService else { return nil }
            return service
        }
    }
    
    @objc open var availableServices: [VgcService] {
        get {
            let services = [VgcService](browser.serviceLookup.values)
            return services
        }
    }
    
    @objc func gotConnectionAcknowledgementTimeout(_ timer: Timer) {
        
        vgcLogDebug("Got connection acknowledgement timeout")

        browser.disconnect()
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralConnectionFailedNotification), object: nil)
        
        connectionAcknowledgementWaitTimeout.invalidate()
        
    }

    func gotConnectionToCentral() {
        
        vgcLogDebug("Got connection to Central (Already? \(haveConnectionToCentral))")
        
        if (haveOpenStreamsToCentral == true) { return }
        
        previousElements.reserveCapacity(VgcManager.elements.allElementsCollection().count)
        for element in VgcManager.elements.allElementsCollection() {
            previousElements.insert(element.clone(), at: element.type.rawValue)
        }
        
        haveOpenStreamsToCentral = true
        
        connectionAcknowledgementWaitTimeout = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(Peripheral.gotConnectionAcknowledgementTimeout(_:)), userInfo: nil, repeats: false)
        
        if deviceIsTypeOfBridge() {
            
            if controller != nil { bridgePeripheralDeviceInfoToCentral(controller) }
            
        } else {
            
            sendDeviceInfo(deviceInfo)

        }
        
    }
    
    func lostConnectionToCentral(_ vgcService: VgcService) {
        
        vgcLogDebug("Peripheral lost connection to \(vgcService.fullName)")
        haveConnectionToCentral = false
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralDidDisconnectNotification), object: nil)
        NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralLostService), object: vgcService)
        
        // Avoid situation where a "ghost" instance will end up on the Bridge after a Peripheral
        // disconnects.  This provides support for the situation where a Central disconnects, but
        // a Peripheral is still connected to the Bridge - when the Central returns the Bridge will
        // connect any Peripherals to it.
        if controller != nil { browser.browseForCentral() }

        #if !(os(tvOS))  && !(os(OSX))
            if !deviceIsTypeOfBridge() {
                vgcLogDebug("Stopping motion data on motion \(motion)")
                motion.stop()
            }
        #endif
        
    }
    
    func sendDeviceInfo(_ deviceInfo: DeviceInfo) {
        
        if (haveOpenStreamsToCentral == false) {
            vgcLogDebug("No streams to Central so not sending controller device info")
            return
        }
        
        vgcLogDebug("Sending device info for controller \(deviceInfo.vendorName) to \(browser.connectedVgcService.fullName)")
        
        NSKeyedArchiver.setClassName("DeviceInfo", for: DeviceInfo.self)
        let element = VgcManager.elements.deviceInfoElement
        element.value = NSKeyedArchiver.archivedData(withRootObject: deviceInfo) as AnyObject
        vgcLogDebug("\(deviceInfo)")
        
        browser.sendDeviceInfoElement(element)

    }
    
    func receivedWatchMessage(_ element: Element) {
        vgcLogDebug("Received element \(element.name) with value \(element.value) from watch, forwarding to Central or Bridge")
        sendElementState(element)
    }
    
    func bridgePeripheralDeviceInfoToCentral(_ controller: VgcController) {
        
        vgcLogDebug("Forwarding controller \(controller.deviceInfo.vendorName) to Central")
        
        let deviceInfo = controller.deviceInfo.copy() as! DeviceInfo
        deviceInfo.vendorName = deviceInfo.vendorName + " (Bridged)"
        if deviceInfo.controllerType == .MFiHardware { deviceInfo.controllerType = .BridgedMFiHardware }
        if deviceInfo.controllerType == .ICadeHardware { deviceInfo.controllerType = .BridgedICadeHardware }
        if deviceInfo.attachedToDevice {
            deviceInfo.profileType = .ExtendedGamepad
            deviceInfo.supportsMotion = true
        }
        if deviceIsTypeOfBridge() { deviceInfo.supportsMotion = true }
        
        // microGamepad is only supported when running on Apple TV, so we transform to
        // Gamepad when bridging it over to a Central on iOS or OSX
        if deviceInfo.profileType == .MicroGamepad { deviceInfo.profileType = .Gamepad }
        sendDeviceInfo(deviceInfo)
        
    }
    
    func mapElement(_ elementToBeMapped: Element, peripheral: Peripheral) {
        
        if let mappedElementIdentifier = Elements.customMappings.mappings[elementToBeMapped.identifier] {
            
            let mappedElement = VgcManager.elements.elementFromIdentifier(mappedElementIdentifier)
            mappedElement?.mappingComplete = true
            vgcLogDebug("   Mapping \(elementToBeMapped.name) to \(String(describing: mappedElement?.name))")
            mappedElement?.value = elementToBeMapped.value
            sendElementState(mappedElement!)
            
        }
    }
    
    func vibrateDevice() {
        #if os(iOS)
        AudioServicesPlayAlertSound(UInt32(kSystemSoundID_Vibrate))
        #endif
    }

}
#endif
