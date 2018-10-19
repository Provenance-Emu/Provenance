//
//  VgcPeripheralNetService.swift
//
//
//  Created by Rob Reuss on 10/1/15.
//
//

import Foundation

#if os(iOS)
    import UIKit
#endif

#if os(iOS) || os(OSX) || os(tvOS)
    import GameController // Needed only because of a reference to playerIndex
#endif

// Set deviceName in a platform specific way
#if os(iOS) || os(tvOS)
//let deviceName = UIDevice.current.name
let deviceName = VgcManager.uniqueServiceIdentifierString
    public let peripheralBackgroundColor = UIColor(red: 0.76, green: 0.76, blue: 0.76, alpha: 1)
#endif

#if os(OSX)
let deviceName = VgcManager.uniqueServiceIdentifierString
    public let peripheralBackgroundColor = NSColor(red: 0.76, green: 0.76, blue: 0.76, alpha: 1)
#endif

#if !os(watchOS)

// MARK: NetService Peripheral Management

class VgcBrowser: NSObject, NetServiceDelegate, NetServiceBrowserDelegate, StreamDelegate, VgcStreamerDelegate {

    var elements: Elements!
    var peripheral: Peripheral!
    var connectedVgcService: VgcService!
    var localService: NetService!
    var inputStream: [StreamDataType: InputStream] = [:]
    var outputStream: [StreamDataType: OutputStream] = [:]
    var registeredName: String!
    var bridgeBrowser: NetServiceBrowser!
    var centralBrowser: NetServiceBrowser!
    var browsing = false
    var streamer: [StreamDataType: VgcStreamer] = [:]
    var serviceLookup = Dictionary<NetService, VgcService>()
    
    init(peripheral: Peripheral) {
        
        super.init()
        
        self.peripheral = peripheral
        
        elements = VgcManager.elements
        
        self.streamer[.largeData] = VgcStreamer(delegate: self, delegateName: "Browser")
        self.streamer[.smallData] = VgcStreamer(delegate: self, delegateName: "Browser")
        
        vgcLogDebug("Setting up NSNetService for browsing")
        
        self.localService = NetService.init(domain: VgcManager.serviceDomain, type: VgcManager.bonjourTypeCentral, name: deviceName, port: 0)
        self.localService.delegate = self
        self.localService.includesPeerToPeer = VgcManager.includesPeerToPeer
        
    }
    
    func closeStream(_ streamDataType: StreamDataType) {
        
        if inputStream[streamDataType] != nil { inputStream[streamDataType]!.close() }
        if outputStream[streamDataType] != nil { outputStream[streamDataType]!.close() }
        
    }
    
    func closeStreams() {
        
        vgcLogDebug("Closing streams")
        
        closeStream(.largeData)
        closeStream(.smallData)
        
        peripheral.haveOpenStreamsToCentral = false
        
    }
    
    // This is a callback from the streamer
    func disconnect() {
        vgcLogDebug("Browser received disconnect")
        closeStreams()
        browsing = false
        if connectedVgcService != nil { peripheral.lostConnectionToCentral(connectedVgcService) }
        connectedVgcService = nil
        browseForCentral()
    }
    
    func receivedNetServiceMessage(_ elementIdentifier: Int, elementValue: Data) {
        
        // Get the element in the message using the hash value reference
        guard let element = elements.elementFromIdentifier(elementIdentifier) else {
            vgcLogError("Received unknown element identifier: \(elementIdentifier) from \(connectedVgcService.fullName)")
            return
        }
        
        element.valueAsNSData = elementValue
        
        switch (element.type) {
            
        case .systemMessage:
            
            let systemMessageType = SystemMessages(rawValue: Int(truncating: element.value as! NSNumber))
            
            vgcLogDebug("Central sent system message: \(systemMessageType!.description)")
            if connectedVgcService != nil {
                vgcLogDebug("Central sent system message to \(connectedVgcService.fullName)")
            }

            if systemMessageType == .connectionAcknowledgement {
                
                DispatchQueue.main.async {

                    if self.peripheral.connectionAcknowledgementWaitTimeout != nil { self.peripheral.connectionAcknowledgementWaitTimeout.invalidate() }
                    
                    self.peripheral.haveConnectionToCentral = true
                    
                    NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralDidConnectNotification), object: nil)
                    
                }
                
            } else {
            
                NotificationCenter.default.post(name: Notification.Name(rawValue: VgcSystemMessageNotification), object: systemMessageType!.rawValue)
                
            }
            
            break
            
        case .peripheralSetup:
            
            NSKeyedUnarchiver.setClass(VgcPeripheralSetup.self, forClassName: "VgcPeripheralSetup")
            VgcManager.peripheralSetup = (NSKeyedUnarchiver.unarchiveObject(with: element.valueAsNSData) as! VgcPeripheralSetup)

            vgcLogDebug("Central sent peripheral setup: \(VgcManager.peripheralSetup)")

            NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralSetupNotification), object: nil)

            break
            
        case .vibrateDevice:
            
            peripheral.vibrateDevice()
            
            break
            
        case .playerIndex:

            let playerIndex = Int(truncating: element.value as! NSNumber)
            peripheral.playerIndex = GCControllerPlayerIndex(rawValue: playerIndex)!
            
            if deviceIsTypeOfBridge(){
                
                self.peripheral.controller.playerIndex = GCControllerPlayerIndex(rawValue: playerIndex)!
                
            }
            NotificationCenter.default.post(name: Notification.Name(rawValue: VgcNewPlayerIndexNotification), object: playerIndex)
            
        default:
          
            // Call the handler set on the global object
            if let handler = element.valueChangedHandlerForPeripheral {
                handler(element)
            }
            
            #if os(iOS)
                if VgcManager.peripheral.watch != nil { VgcManager.peripheral.watch.sendElementState(element) }
            #endif
            
        }
        
        // If we're a bridge, send along the value to the Central
        if deviceIsTypeOfBridge() && element.type != .playerIndex {
            
            //peripheral.browser.sendElementStateOverNetService(element)
            peripheral.controller.sendElementStateToPeripheral(element)
            
        }

    }
    
    // Used to disconnect a peripheral from a center
    func disconnectFromCentral() {
        if connectedVgcService == nil { return }
        vgcLogDebug("Browser sending system message Disconnect)")
        elements.systemMessage.value = SystemMessages.disconnect.rawValue as AnyObject
        sendElementStateOverNetService(elements.systemMessage)
        closeStreams()
    }
    
    // This is triggered by the Streamer if it receives a malformed message.  We just log it here.
    func sendInvalidMessageSystemMessage() {
        vgcLogDebug("Peripheral received invalid checksum message from Central")
    }
    
    func sendDeviceInfoElement(_ element: Element!) {
        
        if element == nil {
            vgcLogDebug("Browser got attempt to send nil element to \(connectedVgcService.fullName)")
            return
        }
        
        var outputStreamLarge: OutputStream!
        var outputStreamSmall: OutputStream!
        
        if (VgcManager.appRole == .Peripheral || VgcManager.appRole == .MultiplayerPeer) {
            outputStreamLarge = self.outputStream[.largeData]
            outputStreamSmall = self.outputStream[.smallData]
        } else if deviceIsTypeOfBridge() {
            outputStreamLarge = peripheral.controller.toCentralOutputStream[.largeData]
            outputStreamSmall = peripheral.controller.toCentralOutputStream[.smallData]
        }
        
        if peripheral.haveOpenStreamsToCentral {
            streamer[.largeData]!.writeElement(element, toStream:outputStreamLarge)
            streamer[.smallData]!.writeElement(element, toStream:outputStreamSmall)
        }
    }

    func sendElementStateOverNetService(_ element: Element!) {
        
        if element == nil {
            vgcLogDebug("Browser got attempt to send nil element to \(connectedVgcService.fullName)")
            return
        }
        
        var outputStream: OutputStream!
        
        if (VgcManager.appRole == .Peripheral || VgcManager.appRole == .MultiplayerPeer) {
            if element.dataType == .Data {
                outputStream = self.outputStream[.largeData]
            } else {
                outputStream = self.outputStream[.smallData]
            }
        } else if deviceIsTypeOfBridge() {
            if element.dataType == .Data {
                outputStream = peripheral.controller.toCentralOutputStream[.largeData]
            } else {
                outputStream = peripheral.controller.toCentralOutputStream[.smallData]
            }
        }
    
        if outputStream == nil {
            if connectedVgcService != nil { vgcLogDebug("\(connectedVgcService.fullName) failed to send element \(element.name) because we don't have an output stream") } else { vgcLogDebug("Failed to send element \(element.name) because we don't have an output stream") }
            return
        }

        // Prevent writes without a connection except deviceInfo
        if element.dataType == .Data {
            if (peripheral.haveConnectionToCentral || element.type == .deviceInfoElement) && streamer[.largeData] != nil { streamer[.largeData]!.writeElement(element, toStream:outputStream) }
        } else {
            if (peripheral.haveConnectionToCentral || element.type == .deviceInfoElement) && streamer[.smallData] != nil { streamer[.smallData]!.writeElement(element, toStream:outputStream) }
        }
       
    }

    func reset() {
        vgcLogDebug("Resetting service browser")
        serviceLookup.removeAll()
    }
    
    func browseForCentral() {
        
        if browsing {
        
            vgcLogDebug("Not browsing for central because already browsing")
            return
        
        }
        
        browsing = true
        
        vgcLogDebug("Searching for Centrals on \(VgcManager.bonjourTypeCentral)")
        centralBrowser = NetServiceBrowser()
        centralBrowser.includesPeerToPeer = VgcManager.includesPeerToPeer
        centralBrowser.delegate = self
        centralBrowser.searchForServices(ofType: VgcManager.bonjourTypeCentral, inDomain: VgcManager.serviceDomain)
        
        // We only searches for bridges if we are not type bridge (bridges don't connect to bridges)
        if !deviceIsTypeOfBridge() {
            vgcLogDebug("Searching for Bridges on \(VgcManager.bonjourTypeBridge)")
            bridgeBrowser = NetServiceBrowser()
            bridgeBrowser.includesPeerToPeer = VgcManager.includesPeerToPeer
            bridgeBrowser.delegate = self
            bridgeBrowser.searchForServices(ofType: VgcManager.bonjourTypeBridge, inDomain: VgcManager.serviceDomain)
        }
    }
    
    func stopBrowsing() {
        vgcLogDebug("Stopping browse for Centrals")
        if centralBrowser != nil { centralBrowser.stop() } else {
            vgcLogError("stopBrowsing() called before browser started")
            return
        }
        vgcLogDebug("Stopping browse for Bridges")
        if !deviceIsTypeOfBridge() { bridgeBrowser.stop() } // Bridges don't browse for Bridges
        vgcLogDebug("Clearing service lookup")
        browsing = false
        if serviceLookup.count > 0 { serviceLookup.removeAll() }
    }
    
    func openStreamsFor(_ streamDataType: StreamDataType, vgcService: VgcService) {

        vgcLogDebug("Attempting to open \(streamDataType) streams for: \(vgcService.fullName)")
        var success: Bool
        var inStream: InputStream?
        var outStream: OutputStream?
        success = vgcService.netService.getInputStream(&inStream, outputStream: &outStream)
        if ( !success ) {
            
            vgcLogDebug("Something went wrong connecting to service: \(vgcService.fullName)")
            NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralConnectionFailedNotification), object: nil)
            
        } else {
            
            vgcLogDebug("Successfully opened \(streamDataType) streams to service: \(vgcService.fullName)")
            
            connectedVgcService = vgcService
            
            if deviceIsTypeOfBridge() && peripheral.controller != nil {
                
                peripheral.controller.toCentralOutputStream[streamDataType] = outStream;
                peripheral.controller.toCentralOutputStream[streamDataType]!.delegate = streamer[streamDataType]
                peripheral.controller.toCentralOutputStream[streamDataType]!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                peripheral.controller.toCentralOutputStream[streamDataType]!.open()
                
                peripheral.controller.fromCentralInputStream[streamDataType] = inStream
                peripheral.controller.fromCentralInputStream[streamDataType]!.delegate = streamer[streamDataType]
                peripheral.controller.fromCentralInputStream[streamDataType]!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                peripheral.controller.fromCentralInputStream[streamDataType]!.open()
                
            } else {
                
                outputStream[streamDataType] = outStream;
                outputStream[streamDataType]!.delegate = streamer[streamDataType]
                outputStream[streamDataType]!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                outputStream[streamDataType]!.open()
                
                inputStream[streamDataType] = inStream
                inputStream[streamDataType]!.delegate = streamer[streamDataType] 
                inputStream[streamDataType]!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                inputStream[streamDataType]!.open()
                
            }
            
            // SmallData comes second, so we wait for it before sending deviceInfo
            if streamDataType == .smallData {
                
                peripheral.gotConnectionToCentral()
                
            }
            
        }
        
    }
    
    func connectToService(_ vgcService: VgcService) {
       
        if (peripheral.haveConnectionToCentral == true) {
            vgcLogDebug("Refusing to connect to service \(vgcService.fullName) because we already have a connection.")
            return
        }
        
        vgcLogDebug("Attempting to connect to service: \(vgcService.fullName)")
        
        openStreamsFor(.largeData, vgcService: vgcService)
        openStreamsFor(.smallData, vgcService: vgcService)
        
        stopBrowsing()
    }
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        vgcLogDebug("Browser will search")
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        vgcLogDebug("Browser did resolve address")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        
        if (service.name == localService.name && TARGET_OS_SIMULATOR == 0) {
            vgcLogDebug("Ignoring service because it is our own: \(service.name)")
        } else {
            vgcLogDebug("Found service of type \(service.type) at \(service.name)")
            var vgcService: VgcService
            if service.type == VgcManager.bonjourTypeBridge {
                vgcService = VgcService(name: service.name, type:.Bridge, netService: service)
            } else {
                vgcService = VgcService(name: service.name, type:.Central, netService: service)
            }
            
            serviceLookup[service] = vgcService
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralFoundService), object: vgcService)
            
            if vgcService.type == .Central && connectedVgcService != vgcService {
                vgcLogDebug("Attempt to connect to service: \(service.name)")
                connectToService(vgcService) }
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        
        vgcLogDebug("Service was removed: \(service.type) isMainThread: \(Thread.isMainThread)")
        let vgcService = serviceLookup.removeValue(forKey: service)
        vgcLogDebug("VgcService was removed: \(String(describing: vgcService?.fullName))")
        // If VgcService is nil, it means we already removed the service so we do not send the notification
        if vgcService != nil { NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralLostService), object: vgcService) }
        
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        browsing = false
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        vgcLogDebug("Net service browser reports error \(errorDict)")
        browsing = false
    }
    
}

#endif
