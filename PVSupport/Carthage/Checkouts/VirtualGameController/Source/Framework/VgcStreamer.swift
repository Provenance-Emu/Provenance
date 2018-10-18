//
//  VgcStreamer.swift
//  VirtualGameController
//
//  Created by Rob Reuss on 10/28/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Foundation

#if !os(watchOS)

@objc internal protocol VgcStreamerDelegate {
    
    func receivedNetServiceMessage(_ elementIdentifier: Int, elementValue: Data)
    @objc optional func disconnect()
    @objc optional var deviceInfo: DeviceInfo! {get set}
    @objc optional var centralPublisher: VgcCentralPublisher! {get set}
    @objc optional func sendInvalidMessageSystemMessage()
    
}

class VgcStreamer: NSObject, NetServiceDelegate, StreamDelegate {

    fileprivate var elements: Elements!
    var delegate: VgcStreamerDelegate!
    var delegateName: String
    var malformedMessageCount: Int = 0
    var totalMessageCount: Int = 0
    var startTime: Date = Date()
    var dataBuffer: NSMutableData = NSMutableData()
    var nsStringBuffer: NSString = ""
    var cycleCount: Int = 0
    var lastTimeStamp = 0.0
    
    init(delegate: VgcStreamerDelegate, delegateName: String) {
        
        self.delegate = delegate
        self.delegateName = delegateName
        elements = VgcManager.elements

    }
    
    deinit {
        vgcLogDebug("Streamer deinitalized")
    }
    
    
    func writeElement(_ element: Element, toStream:OutputStream) {
        
        let messageData = element.dataMessage
        
        //vgcLogVerbose("Sending Data for \(element.name):\(messageData.length) bytes, value: \(element.value)")
        
        writeData(messageData as Data, toStream: toStream)
        
        if element.clearValueAfterTransfer {
            element.clearValue()
        }
 
    }
    
    @objc func delayedWriteData(_ timer: Timer) {
        let userInfo = timer.userInfo as! Dictionary<String, AnyObject>
        let outputStream = (userInfo["stream"] as! OutputStream)
        queueRetryTimer[outputStream]!.invalidate()
        vgcLogDebug("Timer triggered to process data send queue (\(self.dataSendQueue.count) messages) to stream \(outputStream) [\(Date().timeIntervalSince1970)]")
        self.writeData(Data(), toStream: outputStream)
    }
    
    // Two indicators for handling a busy send queue, both of which result in the message being appended
    // to an NSMutableData var
    var dataSendQueue = [Data]()
    let lockQueueWriteData = DispatchQueue(label: "net.simplyformed.lockQueueWriteData", attributes: [])
    var streamerIsBusy: Bool = false
    var queueRetryTimer: [OutputStream: Timer] = [:]
    
    func writeData(_ data: Data, toStream: OutputStream) {
        var data = data

        if (VgcManager.appRole == .Peripheral || VgcManager.appRole == .MultiplayerPeer) && VgcManager.peripheral == nil {
            vgcLogDebug("Attempt to write without peripheral object setup, exiting")
            return
        }

        // If no connection to Central, clean-up queue and exit
        if (VgcManager.appRole == .Peripheral) && VgcManager.peripheral.haveOpenStreamsToCentral == false {
            vgcLogDebug("No connection so clearing write queue (\(self.dataSendQueue.count) messages)")
            dataSendQueue = [Data]()
            return
        }
        
        struct PerformanceVars {
            static var messagesSent: Float = 0
            static var bytesSent: Int = 0
            static var messagesQueued: Int = 0
            static var lastPublicationOfPerformance = Date()
            static var totalSessionMessages: Float = 0
        }

        if !toStream.hasSpaceAvailable {
            
            vgcLogDebug("OutputStream has no space/streamer is busy (Status: \(toStream.streamStatus.rawValue))")
            if data.count > 0 {
                
                self.lockQueueWriteData.sync {
                    if self.dataSendQueue.count >= VgcManager.maxDataBufferSizeMessages {
                        self.dataSendQueue.removeFirst()
                    }
                    PerformanceVars.messagesQueued += 1
                    self.dataSendQueue.append(data)
                }
                
                vgcLogDebug("Appended data queue (\(self.dataSendQueue.count) total messages)")
            }
            if self.dataSendQueue.count > 0 {

                if queueRetryTimer[toStream] == nil || !queueRetryTimer[toStream]!.isValid {
                    vgcLogDebug("Setting data queue retry timer (Stream: \(toStream))")
                    queueRetryTimer[toStream] = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(VgcStreamer.delayedWriteData(_:)), userInfo: ["stream": toStream], repeats: false)
                }

            }
            return
       }

        if self.dataSendQueue.count > 0 {
            vgcLogDebug("Processing data queue (\(self.dataSendQueue.count) messages)")

            self.lockQueueWriteData.sync {
                self.dataSendQueue.append(data)
                for message in self.dataSendQueue {
                    data.append(message)
                }
                print("DATA MESSAGE: \(data)")
                self.dataSendQueue = [Data]()
            }
            if queueRetryTimer[toStream] != nil { queueRetryTimer[toStream]!.invalidate() }

        }
        
        if data.count > 0 { PerformanceVars.messagesSent = PerformanceVars.messagesSent + 1.0 }
        
        if VgcManager.performanceSamplingEnabled  && (VgcManager.appRole == .MultiplayerPeer || VgcManager.appRole == .Peripheral) {
            
            PerformanceVars.bytesSent += data.count
            
            if Float(PerformanceVars.lastPublicationOfPerformance.timeIntervalSinceNow) < -(VgcManager.performanceSamplingDisplayFrequency) {
                let messagesPerSecond: Float = PerformanceVars.messagesSent / VgcManager.performanceSamplingDisplayFrequency
                let kbPerSecond: Float = (Float(PerformanceVars.bytesSent) / VgcManager.performanceSamplingDisplayFrequency) / 1000
                PerformanceVars.totalSessionMessages += PerformanceVars.messagesSent
                vgcLogDebug("Peripheral Performance: \(PerformanceVars.messagesSent) msgs (\(PerformanceVars.totalSessionMessages) total), \(messagesPerSecond) msgs/sec, \(PerformanceVars.messagesQueued) msgs queued, \(kbPerSecond) KB/sec sent")
                PerformanceVars.messagesSent = 0
                PerformanceVars.lastPublicationOfPerformance = Date()
                PerformanceVars.bytesSent = 0
                PerformanceVars.messagesQueued = 0
            }
        }

        streamerIsBusy = true

        var bytesWritten: NSInteger = 0
        
        if data.count == 0 {
            vgcLogError("Attempt to send an empty buffer, exiting")
            self.lockQueueWriteData.sync {
                self.dataSendQueue =  [Data]()
            }
            return
        }

        while (data.count > bytesWritten) {
            
            let writeResult = toStream.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count) + bytesWritten, maxLength: data.count - bytesWritten)
            if writeResult == -1 {
                vgcLogError("NSOutputStream returned -1")
                return
            } else {
                bytesWritten += writeResult
            }
            
        }
        
        if data.count != bytesWritten {
            vgcLogError("Got data transfer size mismatch")
        } else {
            if data.count > 300 { vgcLogVerbose("Large message sent (\(data.count) bytes, \(data.count / 1000) kb)") }
        }
        
        streamerIsBusy = false
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        
        if dataBuffer.length == 0 {
            dataBuffer = NSMutableData()
        }
        
        switch (eventCode){
            
        case Stream.Event.hasBytesAvailable:
            
            //print("RECEIVED STREAM DATA")

            let inputStream = aStream as! InputStream
            
            var buffer = Array<UInt8>(repeating: 0, count: VgcManager.netServiceBufferSize)
            
            while inputStream.hasBytesAvailable {
                
                let len = inputStream.read(&buffer, maxLength: buffer.count)
                //if len > 500 { vgcLogError("Input buffer loaded: \(len)") }
                dataBuffer.append(Data(bytes: &buffer, count: len))
                
            }
            
            while dataBuffer.length > 0 {
                
                //print("ENTERED DATA BUFFER PROCESS")

                let (element, remainingData) = elements.processMessage(data: self.dataBuffer)

                if let elementUnwrapped = element {
                    delegate.receivedNetServiceMessage(elementUnwrapped.identifier, elementValue: elementUnwrapped.valueAsNSData)
                } else {
                    //vgcLogError("Got non-element from processMessage (remainder: \(remainingData))")
                    return

                }
                
                if let remainingDataUnwrapped = remainingData {
                    //print("Got remainder")
                    dataBuffer = NSMutableData(data: remainingDataUnwrapped)
                } else {
                    dataBuffer = NSMutableData()
                }

            }

            

 /*
        case Stream.Event.hasBytesAvailable:
            
            vgcLogVerbose("Stream status: \(aStream.streamStatus.rawValue)")
            
            var bufferLoops = 0
            
            let inputStream = aStream as! InputStream

            var buffer = Array<UInt8>(repeating: 0, count: VgcManager.netServiceBufferSize)
            
            while inputStream.hasBytesAvailable {
                
                bufferLoops += 1
               
                let len = inputStream.read(&buffer, maxLength: buffer.count)
                
                if len <= 0 { return }
                
                //print("Buffer load: \(len)")
                
                if len > 500 { vgcLogError("Input buffer loaded: \(len)") }

                dataBuffer.append(Data(bytes: &buffer, count: len))
                
                while dataBuffer.length > 0 {
                   // print("Data buffer: \(dataBuffer.length)")
                    let (element, remainingData) = elements.processMessage(data: self.dataBuffer)
                    
                    if let elementUnwrapped = element {
                        delegate.receivedNetServiceMessage(elementUnwrapped.identifier, elementValue: elementUnwrapped.valueAsNSData)
                    } else {
                        vgcLogError("Got non-element from processMessage")
                    }
                    //print("Remaining data: \(remainingData?.count)")
                    dataBuffer = NSMutableData(data: remainingData!)
                }
                
            }
            
*/


            break
        case Stream.Event():
            NSLog("Streamer: All Zeros")
            break
            
        case Stream.Event.openCompleted:
            if aStream is InputStream {
                vgcLogDebug("\(VgcManager.appRole) input stream is now open for \(delegateName)")
            } else {
                vgcLogDebug("\(VgcManager.appRole) output stream is now open for \(delegateName)")
            }
            break
        case Stream.Event.hasSpaceAvailable:
            //vgcLogDebug("HAS SPACE AVAILABLE")
            break
            
        case Stream.Event.errorOccurred:
            vgcLogError("Stream ErrorOccurred: Event Code: \(eventCode) (Delegate Name: \(delegateName))")
            delegate.disconnect!()
            break
            
        case Stream.Event.endEncountered:
            vgcLogDebug("Streamer: EndEncountered (Delegate Name: \(delegateName))")
            delegate.disconnect!()
            
            break
            
        case Stream.Event():
            vgcLogDebug("Streamer: Event None")
            break
        
            
        default:
            NSLog("default")
        }
    }
    
    func processDataMessage(_ dataMessage: NSString) {
        
        
        
    }
   
    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        vgcLogDebug("CENTRAL: netService NetService didUpdateTXTRecordData")
    }
    
    func netServiceDidPublish(_ sender: NetService) {
        if deviceIsTypeOfBridge() {
            vgcLogDebug("Bridge streamer is now published on: \(sender.domain + sender.type + sender.name)")
        } else {
            vgcLogDebug("Central streamer is now published on: \(sender.domain + sender.type + sender.name)")
        }
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        vgcLogDebug("CENTRAL: Net service did not publish, error: \(errorDict)")
    }
    
    func netServiceWillPublish(_ sender: NetService) {
        vgcLogDebug("NetService will be published")
    }
    
    func netServiceWillResolve(_ sender: NetService) {
        vgcLogDebug("CENTRAL: netServiceWillResolve")
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        vgcLogDebug("CENTRAL: netService didNotResolve: \(errorDict)")
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        vgcLogDebug("CENTRAL: netServiceDidResolveAddress")
    }
    
    func netServiceDidStop(_ sender: NetService) {
        vgcLogDebug("CENTRAL: netServiceDidStop")
    }

    
    
}

#endif
