//
//  VgcCentralPublisher.swift
//
//
//  Created by Rob Reuss on 10/1/15.
//
//

import Foundation
#if os(iOS) || os(tvOS) // Need this only for UIDevice
    import UIKit
#endif
#if os(iOS) || os(OSX) || os(tvOS)
    import GameController
#endif

#if !os(watchOS)

@objc internal protocol VgcPendingStreamDelegate {
    
    func testForMatchingStreams()
    
}

class VgcPendingStream: NSObject, VgcStreamerDelegate {
    
    weak var delegate: VgcPendingStreamDelegate?
    var createTime = Date()
    var inputStream: InputStream
    var outputStream: OutputStream
    var streamer: VgcStreamer!
    var deviceInfo: DeviceInfo!
    
    init(inputStream: InputStream, outputStream: OutputStream, delegate: VgcPendingStreamDelegate) {
        
        self.delegate = delegate
        self.inputStream = inputStream
        self.outputStream = outputStream
        
        super.init()
    }
    
    
    func disconnect() {
        vgcLogError("Got disconnect from pending stream streamer")
    }

    
    func receivedNetServiceMessage(_ elementIdentifier: Int, elementValue: Data) {
        
        if let element = VgcManager.elements.elementFromIdentifier(elementIdentifier) {
        
            if element.type == .deviceInfoElement {
                
                element.valueAsNSData = elementValue
                NSKeyedUnarchiver.setClass(DeviceInfo.self, forClassName: "DeviceInfo")
                if let di = (NSKeyedUnarchiver.unarchiveObject(with: (element.valueAsNSData)) as? DeviceInfo) {
                    deviceInfo = di
                    delegate?.testForMatchingStreams()
                } else {
                    
                    vgcLogError("Received nil DeviceInfo")
                    
                }
                
            }
        } else {
            vgcLogError("Expected DeviceInfo but got nil element based on identifer \(elementIdentifier)")
        }
    }
    
    func openstreams() {
        
        vgcLogDebug("Opening pending streams")

        outputStream.delegate = streamer
        outputStream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        outputStream.open()
        
        inputStream.delegate = streamer
        inputStream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        inputStream.open()
        
    }

    // Make class hashable - function to make it equatable appears below outside the class definition
    override var hashValue: Int {
        return inputStream.hashValue
    }

}

// Make class equatable
func ==(lhs: VgcPendingStream, rhs: VgcPendingStream) -> Bool {
    return lhs.inputStream.hashValue == rhs.inputStream.hashValue
}


internal class VgcCentralPublisher: NSObject, NetServiceDelegate, StreamDelegate, VgcPendingStreamDelegate {
    
    var localService: NetService!
    var remoteService: NetService!
    var registeredName: String!
    var haveConnectionToPeripheral: Bool
    var unusedInputStream: InputStream!
    var unusedOutputStream: OutputStream!
    var streamMatchingTimer: Timer!
    var pendingStreams = Set<VgcPendingStream>()
    
    override init() {
        
        vgcLogDebug("Initializing Central Publisher")
        
        self.haveConnectionToPeripheral = false
        
        super.init()
        
        if deviceIsTypeOfBridge() {
            self.localService = NetService.init(domain: VgcManager.serviceDomain, type: VgcManager.bonjourTypeBridge, name: VgcManager.centralServiceName, port: 0)
        } else {
            self.localService = NetService.init(domain: VgcManager.serviceDomain, type: VgcManager.bonjourTypeCentral, name: VgcManager.centralServiceName, port: 0)
        }
        
        self.localService.delegate = self
        self.localService.includesPeerToPeer = VgcManager.includesPeerToPeer

    }
    
    // So that peripherals will be able to see us over NetServices
    func publishService() {
        vgcLogDebug("Publishing NetService service to listen for Peripherals on \(self.localService.name)")
        vgcLogDebug("Service bonjour domain is \(self.localService.domain), type is \(self.localService.type), name is \(self.localService.name)")
        self.localService.publish(options: .listenForConnections)
    }
    
    func unpublishService() {
        vgcLogDebug("Central unpublishing service")
        localService.stop()
    }
    
    func updateMatchingStreamTimer() {
        
        if pendingStreams.count == 0 && streamMatchingTimer.isValid {
            vgcLogDebug("Invalidating matching stream timer")
            streamMatchingTimer.invalidate()
            streamMatchingTimer = nil
        } else if pendingStreams.count > 0 && streamMatchingTimer == nil {
            vgcLogDebug("Setting matching stream timer")
            streamMatchingTimer = Timer.scheduledTimer(timeInterval: VgcManager.maxTimeForMatchingStreams, target: self, selector: #selector(VgcPendingStreamDelegate.testForMatchingStreams), userInfo: nil, repeats: false)
        }
        
    }
    
    let lockQueuePendingStreams = DispatchQueue(label: "net.simplyformed.lockQueuePendingStreams", attributes: [])
    
    func testForMatchingStreams() {
        
        var pendingStream1: VgcPendingStream! = nil
        var pendingStream2: VgcPendingStream! = nil
        
        lockQueuePendingStreams.sync {
            
            if self.pendingStreams.count > 0 { vgcLogDebug("Testing for matching streams among \(self.pendingStreams.count) pending streams") }
            
                for comparisonStream in self.pendingStreams {
                    if pendingStream1 == nil {
                        for testStream in self.pendingStreams {
                            if (testStream.deviceInfo != nil && comparisonStream.deviceInfo != nil) && (testStream.deviceInfo.deviceUID == comparisonStream.deviceInfo.deviceUID) && testStream != comparisonStream {
                                vgcLogDebug("Found matching stream for deviceUID: \(comparisonStream.deviceInfo.deviceUID)")
                                pendingStream1 = testStream
                                pendingStream2 = comparisonStream
                                continue
                            }
                        }
                    }
                
                // Test primarily for the situation where we only get one of the two required
                // stream sets, and therefore there are potential orphans
                if fabs(comparisonStream.createTime.timeIntervalSinceNow) > VgcManager.maxTimeForMatchingStreams {
                    vgcLogDebug("Removing expired pending streams and closing")
                    comparisonStream.inputStream.close()
                    comparisonStream.outputStream.close()
                    self.pendingStreams.remove(comparisonStream)
                }
            }
            
            if pendingStream1 != nil {
                
                self.pendingStreams.remove(pendingStream1)
                self.pendingStreams.remove(pendingStream2)
                
                vgcLogDebug("\(self.pendingStreams.count) pending streams remain in set")
                
                let controller = VgcController()
                controller.centralPublisher = self
                pendingStream1.streamer.delegate = controller
                pendingStream2.streamer.delegate = controller
                controller.openstreams(.largeData, inputStream: pendingStream1.inputStream, outputStream: pendingStream1.outputStream, streamStreamer: pendingStream1.streamer)
                controller.openstreams(.smallData, inputStream: pendingStream2.inputStream, outputStream: pendingStream2.outputStream, streamStreamer: pendingStream2.streamer)
                
                // Use of pendingStream1 is arbitrary - both streams have same deviceInfo
                controller.deviceInfo = pendingStream1.deviceInfo
                
                pendingStream1.streamer = nil
                pendingStream2.streamer = nil 
            }

        }

        updateMatchingStreamTimer()

    }
    
    internal func netService(_ service: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {

        vgcLogDebug("Assigning input/output streams to pending stream object")
        
        self.haveConnectionToPeripheral = true
        
        let pendingStream = VgcPendingStream(inputStream: inputStream, outputStream: outputStream, delegate: self)

        pendingStream.streamer = VgcStreamer(delegate: pendingStream, delegateName:"Central Publisher")

        lockQueuePendingStreams.sync {
            vgcLogDebug("Syncing pending stream")
            self.pendingStreams.insert(pendingStream)
        }
        pendingStream.openstreams()
        
        updateMatchingStreamTimer()
        
    }
    
    internal func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        vgcLogDebug("CENTRAL: netService NetService didUpdateTXTRecordData")
    }
    
    internal func netServiceDidPublish(_ sender: NetService) {
        if deviceIsTypeOfBridge() {
            vgcLogDebug("Bridge is now published on: \(sender.domain + sender.type + sender.name)")
        } else {
            vgcLogDebug("Central is now published on: \(sender.domain + sender.type + sender.name)")
        }
        self.registeredName = sender.name
    }
    
    internal func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        vgcLogDebug("Central net service did not publish, error: \(errorDict), registered name: \(self.registeredName), server name: \(self.localService.name)")
        vgcLogDebug("Republishing net service")
        unpublishService()
        publishService()
    }
    
    internal func netServiceWillPublish(_ sender: NetService) {
        vgcLogDebug("NetService will be published")
    }
    
    internal func netServiceWillResolve(_ sender: NetService) {
        vgcLogDebug("CENTRAL: netServiceWillResolve")
    }
    
    internal func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        vgcLogDebug("CENTRAL: netService didNotResolve: \(errorDict)")
    }
    
    internal func netServiceDidResolveAddress(_ sender: NetService) {
        vgcLogDebug("CENTRAL: netServiceDidResolveAddress")
    }
    
    internal func netServiceDidStop(_ sender: NetService) {
        vgcLogDebug("CENTRAL: netServiceDidStop")
        self.haveConnectionToPeripheral = false
    }
    
    
}

#endif
