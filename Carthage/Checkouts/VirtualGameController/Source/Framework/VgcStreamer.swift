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
    var expectedLength: Int = 0
    var elementIdentifier: Int!
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
        
         struct PerformanceVars {
            static var messagesReceived: Float = 0
            static var bytesReceived: Int = 0
            static var lastPublicationOfPerformance = Date()
            static var invalidMessages: Float = 0
            static var totalTransitTimeMeasurements: Double = 0
            static var totalTransitTime: Double = 0
            static var averageTransitTime: Double = 0
            static var totalSessionMessages: Float = 0
            static var bufferLoad: Int = 0
            static var bufferCycles: Int = 0
            static var bufferReads: Int = 0
            static var maxLoad: Int = 0
        }
        
        if dataBuffer.length == 0 {
            dataBuffer = NSMutableData()
        }
        
        switch (eventCode){
 
        case Stream.Event.hasBytesAvailable:
            
            vgcLogVerbose("Stream status: \(aStream.streamStatus.rawValue)")

            var bufferLoops = 0
            
            let headerLength = VgcManager.netServiceHeaderLength
            
            let inputStream = aStream as! InputStream

            var buffer = Array<UInt8>(repeating: 0, count: VgcManager.netServiceBufferSize)
            
            while inputStream.hasBytesAvailable {
                
                bufferLoops += 1
               
                let len = inputStream.read(&buffer, maxLength: buffer.count)
                
                if len <= 0 { return }

                PerformanceVars.bytesReceived += len
                
                //print("Buffer load: \(len)")
                
                //if len > 500 { vgcLogError("Input buffer loaded: \(len)") }
                if VgcManager.performanceSamplingEnabled {
                    PerformanceVars.bufferLoad += len
                    PerformanceVars.bufferCycles += 1
                    if len > PerformanceVars.maxLoad { PerformanceVars.maxLoad = len }
                }
                
                dataBuffer.append(Data(bytes: &buffer, count: len))
                
            }
            
            PerformanceVars.bufferReads += 1
            
            //if VgcManager.netServiceLatencyLogging == true { vgcLogDebug("Buffer size is \(dataBuffer.length) (Cycle count: \(cycleCount)) ((Buffer loops: \(bufferLoops))") }
        
            while dataBuffer.length > 0 {
                
                // This shouldn't happen
                if dataBuffer.length <= headerLength {
                    dataBuffer = NSMutableData()
                    vgcLogError("Streamer received data too short to have a header (\(dataBuffer.length) bytes)")
                    PerformanceVars.invalidMessages += 1
                    return
                }

                let headerIdentifier = dataBuffer.subdata(with: NSRange.init(location: 0, length: 4))
                if headerIdentifier == headerIdentifierAsNSData as Data {
                    
                    var elementIdentifierUInt8: UInt8 = 0
                    let elementIdentifierNSData = dataBuffer.subdata(with: NSRange.init(location: 4, length: 1))
                    (elementIdentifierNSData as NSData).getBytes(&elementIdentifierUInt8, length: MemoryLayout<UInt8>.size)
                    elementIdentifier = Int(elementIdentifierUInt8)
                    
                    var expectedLengthUInt32: UInt32 = 0
                    let valueLengthNSData = dataBuffer.subdata(with: NSRange.init(location: 5, length: 4))
                    (valueLengthNSData as NSData).getBytes(&expectedLengthUInt32, length: MemoryLayout<UInt32>.size)
                    expectedLength = Int(expectedLengthUInt32)
                    
                    if VgcManager.netServiceLatencyLogging {
                        
                       var timestampDouble: Double = 0
                        let timestampNSData = dataBuffer.subdata(with: NSRange.init(location: 9, length: 8))
                        (timestampNSData as NSData).getBytes(&timestampDouble, length: MemoryLayout<Double>.size)
                        
                        let transitTime = round(1000 * (Date().timeIntervalSince1970 - timestampDouble))
                        //if timestampDouble < lastTimeStamp { vgcLogDebug("Time problem") }
                        //lastTimeStamp = timestampDouble
                        PerformanceVars.totalTransitTime += transitTime
                        PerformanceVars.totalTransitTimeMeasurements += 1
                        
                        // Log percentage-based threshold of transit time relative to average
                        let averageTransitTime = PerformanceVars.totalTransitTime / PerformanceVars.totalTransitTimeMeasurements
                        
                        // Do a certain number of measurements before reporting and resetting
                        if PerformanceVars.totalTransitTimeMeasurements > 2000 {
                            print("Latency report: Avg: \(averageTransitTime) based on \(PerformanceVars.totalTransitTimeMeasurements) measures")
                            PerformanceVars.totalTransitTimeMeasurements = 0
                            PerformanceVars.totalTransitTime = 0
                        }


                    }
                    
                } else {
                    
                    // This shouldn't happen
                    dataBuffer = NSMutableData()
                    vgcLogError("Streamer expected header but found no header identifier (\(dataBuffer.length) bytes)")
                    PerformanceVars.invalidMessages += 1
                    return
                }
                
                if expectedLength == 0 {
                    dataBuffer = NSMutableData()
                    vgcLogError("Streamer got expected length of zero")
                    PerformanceVars.invalidMessages += 1
                    return
                }

                var elementValueData = Data()

                if dataBuffer.length < (expectedLength + headerLength) {
                    vgcLogVerbose("Streamer fetching additional data")
                    break
                }

                elementValueData = dataBuffer.subdata(with: NSRange.init(location: headerLength, length: expectedLength))
                let dataRemainingAfterCurrentElement = dataBuffer.subdata(with: NSRange.init(location: headerLength + expectedLength, length: dataBuffer.length - expectedLength - headerLength))
                dataBuffer = NSMutableData(data: dataRemainingAfterCurrentElement)
                
                if elementValueData.count == expectedLength {
                    
                    // Performance testing is about calculating elements received per second
                    // By sending motion data, it can be  compared to expected rates.
                    
                    PerformanceVars.messagesReceived += 1
                    
                    if VgcManager.performanceSamplingEnabled && (VgcManager.appRole == .MultiplayerPeer || VgcManager.appRole == .Central) {
                        
                        if Float(PerformanceVars.lastPublicationOfPerformance.timeIntervalSinceNow) < -(VgcManager.performanceSamplingDisplayFrequency) {
                            let messagesPerSecond: Float = PerformanceVars.messagesReceived / VgcManager.performanceSamplingDisplayFrequency
                            let kbPerSecond: Float = (Float(PerformanceVars.bytesReceived) / VgcManager.performanceSamplingDisplayFrequency) / 1000
                            //let invalidChecksumsPerSec: Float = (PerformanceVars.invalidChecksums / VgcManager.performanceSamplingDisplayFrequency)
                            PerformanceVars.totalSessionMessages += PerformanceVars.messagesReceived
                            if PerformanceVars.bufferCycles > 0 { // Avoid divide by zero crash
                                vgcLogDebug("Central Performance: \(PerformanceVars.messagesReceived) msgs (\(PerformanceVars.totalSessionMessages) total), \(messagesPerSecond) msgs/sec, \(PerformanceVars.invalidMessages) bad msgs, \(kbPerSecond) KB/sec rcvd, Avg Buf Load \(PerformanceVars.bufferLoad / PerformanceVars.bufferCycles), Max Buf Load \(PerformanceVars.maxLoad), Cycles \(PerformanceVars.bufferCycles), Avg Cycles: \((PerformanceVars.bufferCycles) / (PerformanceVars.bufferReads))")
                            }
                            //
                            PerformanceVars.messagesReceived = 0
                            PerformanceVars.invalidMessages = 0
                            PerformanceVars.lastPublicationOfPerformance = Date()
                            PerformanceVars.bytesReceived = 0
                            PerformanceVars.bufferLoad = 0
                            PerformanceVars.bufferCycles = 0
                            PerformanceVars.bufferReads = 0
                            PerformanceVars.maxLoad = 0
                        }
                    }
                    
                    //if logging { vgcLogDebug("Got completed data transfer (\(elementValueData.length) of \(expectedLength))") }
                
                    let element = elements.elementFromIdentifier(elementIdentifier!)
                    
                    if element == nil {
                        
                        vgcLogError("Nil element.")
                        
                    } else {
                        
                        delegate.receivedNetServiceMessage(elementIdentifier!, elementValue: elementValueData)
                        
                    }

                    elementIdentifier = nil
                    expectedLength = 0
                    
                } else {
                    vgcLogVerbose("Streamer fetching additional data")
                }

            }

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
