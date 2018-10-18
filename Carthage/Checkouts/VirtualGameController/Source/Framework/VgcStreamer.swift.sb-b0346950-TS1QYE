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
    
    func receivedNetServiceMessage(elementIdentifier: Int, elementValue: NSData)
    optional func disconnect()
    optional var deviceInfo: DeviceInfo! {get set}
    optional var centralPublisher: VgcCentralPublisher! {get set}
    optional func sendInvalidMessageSystemMessage()
    
}

class VgcStreamer: NSObject, NSNetServiceDelegate, NSStreamDelegate {

    private var elements: Elements!
    var delegate: VgcStreamerDelegate!
    var delegateName: String
    var malformedMessageCount: Int = 0
    var totalMessageCount: Int = 0
    var startTime: NSDate = NSDate()
    var dataBuffer: NSMutableData = NSMutableData()
    var expectedLength: Int = 0
    var elementIdentifier: Int!
    var nsStringBuffer: NSString = ""
    var cycleCount: Int = 0
    let logging = false
    var lastTimeStamp = 0.0
    
    init(delegate: VgcStreamerDelegate, delegateName: String) {
        
        self.delegate = delegate
        self.delegateName = delegateName
        elements = VgcManager.elements
        
    }
    
    deinit {
        vgcLogDebug("Streamer deinitalized")
    }
    
    
    func writeElement(element: Element, toStream:NSOutputStream) {
        
        let messageData = element.dataMessage
        
        if logging { vgcLogDebug("Sending Data for \(element.name):\(messageData.length) bytes") }
        
        writeData(messageData, toStream: toStream)
        
        if element.clearValueAfterTransfer {
            element.clearValue()
        }
 
    }
    
    func delayedWriteData(timer: NSTimer) {
        let userInfo = timer.userInfo as! Dictionary<String, AnyObject>
        let outputStream = (userInfo["stream"] as! NSOutputStream)
        queueRetryTimer[outputStream]!.invalidate()
        vgcLogDebug("Timer triggered to process data send queue (\(self.dataSendQueue.length) bytes) to stream \(outputStream) [\(NSDate().timeIntervalSince1970)]")
        self.writeData(NSData(), toStream: outputStream)
    }
    
    // Two indicators for handling a busy send queue, both of which result in the message being appended
    // to an NSMutableData var
    var dataSendQueue = NSMutableData()
    let lockQueueWriteData = dispatch_queue_create("net.simplyformed.lockQueueWriteData", nil)
    var streamerIsBusy: Bool = false
    var queueRetryTimer: [NSOutputStream: NSTimer] = [:]
    
    func writeData(var data: NSData, toStream: NSOutputStream) {

        if VgcManager.appRole == .Peripheral && VgcManager.peripheral == nil {
            vgcLogDebug("Attempt to write without peripheral object setup, exiting")
            return
        }
        
        // If no connection, clean-up queue and exit
        if VgcManager.appRole == .Peripheral && VgcManager.peripheral.haveOpenStreamsToCentral == false {
            vgcLogDebug("No connection so clearing write queue (\(self.dataSendQueue.length) bytes)")
            dataSendQueue = NSMutableData()
            return
        }
        
        struct PerformanceVars {
            static var messagesSent: Float = 0
            static var bytesSent: Int = 0
            static var messagesQueued: Int = 0
            static var lastPublicationOfPerformance = NSDate()
        }

        if !toStream.hasSpaceAvailable {
            if logging { vgcLogDebug("OutputStream has no space/streamer is busy (Status: \(toStream.streamStatus.rawValue))") }
            if data.length > 0 {
                dispatch_sync(self.lockQueueWriteData) {
                    PerformanceVars.messagesQueued++
                    self.dataSendQueue.appendData(data)
                }
                
                if logging { vgcLogDebug("Appended data queue (\(self.dataSendQueue.length) bytes)") }
            }
            if self.dataSendQueue.length > 0 {

                if queueRetryTimer[toStream] == nil || !queueRetryTimer[toStream]!.valid {
                    vgcLogDebug("Setting data queue retry timer (Stream: \(toStream))")
                    queueRetryTimer[toStream] = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: "delayedWriteData:", userInfo: ["stream": toStream], repeats: false)
                }

            }
            return
       }

        if self.dataSendQueue.length > 0 {
            if logging { vgcLogDebug("Processing data queue (\(self.dataSendQueue.length) bytes)") }

            dispatch_sync(self.lockQueueWriteData) {
                self.dataSendQueue.appendData(data)
                data = self.dataSendQueue
                self.dataSendQueue = NSMutableData()
            }
            if queueRetryTimer[toStream] != nil { queueRetryTimer[toStream]!.invalidate() }

        }
        
        if data.length > 0 { PerformanceVars.messagesSent = PerformanceVars.messagesSent + 1.0 }
        
        if VgcManager.performanceSamplingEnabled {
            
            PerformanceVars.bytesSent += data.length
            
            if Float(PerformanceVars.lastPublicationOfPerformance.timeIntervalSinceNow) < -(VgcManager.performanceSamplingDisplayFrequency) {
                let messagesPerSecond: Float = PerformanceVars.messagesSent / VgcManager.performanceSamplingDisplayFrequency
                let kbPerSecond: Float = (Float(PerformanceVars.bytesSent) / VgcManager.performanceSamplingDisplayFrequency) / 1000
                vgcLogDebug("\(messagesPerSecond) msgs/sec, \(PerformanceVars.messagesQueued) msgs queued, \(kbPerSecond) kb/sec sent")
                PerformanceVars.messagesSent = 0
                PerformanceVars.lastPublicationOfPerformance = NSDate()
                PerformanceVars.bytesSent = 0
                PerformanceVars.messagesQueued = 0
            }
        }
        
        streamerIsBusy = true

        var bytesWritten: NSInteger = 0
        
        if data.length == 0 {
            vgcLogError("Attempt to send an empty buffer, exiting")
            dispatch_sync(self.lockQueueWriteData) {
                self.dataSendQueue = NSMutableData()
            }
            return
        }

        while (data.length > bytesWritten) {
            
            let writeResult = toStream.write(UnsafePointer<UInt8>(data.bytes) + bytesWritten, maxLength: data.length - bytesWritten)
            if writeResult == -1 {
                vgcLogError("NSOutputStream returned -1")
                return
            } else {
                bytesWritten += writeResult
            }
            
        }
        
        if data.length != bytesWritten {
            vgcLogError("Got data transfer size mismatch")
        } else {
            if data.length > 300 { vgcLogDebug("Large message sent (\(data.length) bytes, \(data.length / 1000) kb)") }
        }
        
        streamerIsBusy = false
    }

    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        
         struct PerformanceVars {
            static var messagesReceived: Float = 0
            static var bytesReceived: Int = 0
            static var lastPublicationOfPerformance = NSDate()
            static var invalidMessages: Float = 0
            static var totalTransitTimeMeasurements: Double = 0
            static var totalTransitTime: Double = 0
            static var averageTransitTime: Double = 0
        }
        
        switch (eventCode){
 
        case NSStreamEvent.HasBytesAvailable:
            
            if logging { vgcLogDebug("Stream status: \(aStream.streamStatus.rawValue)") }

            var bufferLoops = 0
            
            let headerLength = VgcManager.netServiceHeaderLength
            
            let inputStream = aStream as! NSInputStream
            
            var buffer = Array<UInt8>(count: VgcManager.netServiceBufferSize, repeatedValue: 0)
            
            while inputStream.hasBytesAvailable {
                
                bufferLoops++
               
                let len = inputStream.read(&buffer, maxLength: buffer.count)
                
                if len <= 0 { return }

                PerformanceVars.bytesReceived += len
               
                if logging { vgcLogDebug("Length of buffer: \(len)") }
                
                dataBuffer.appendData(NSData(bytes: &buffer, length: len))
                
            }
            
            if logging == true { vgcLogDebug("Buffer size is \(dataBuffer.length) (Cycle count: \(cycleCount)) ((Buffer loops: \(bufferLoops))") }
        
            while dataBuffer.length > 0 {
                
                // This shouldn't happen
                if dataBuffer.length <= headerLength {
                    dataBuffer = NSMutableData()
                    vgcLogError("Streamer received data too short to have a header (\(dataBuffer.length) bytes)")
                    PerformanceVars.invalidMessages++
                    return
                }

                let headerIdentifier = dataBuffer.subdataWithRange(NSRange.init(location: 0, length: 4))
                if headerIdentifier == headerIdentifierAsNSData {
                    
                    var elementIdentifierUInt8: UInt8 = 0
                    let elementIdentifierNSData = dataBuffer.subdataWithRange(NSRange.init(location: 4, length: 1))
                    elementIdentifierNSData.getBytes(&elementIdentifierUInt8, length: sizeof(UInt8))
                    elementIdentifier = Int(elementIdentifierUInt8)
                    
                    var expectedLengthUInt32: UInt32 = 0
                    let valueLengthNSData = dataBuffer.subdataWithRange(NSRange.init(location: 5, length: 4))
                    valueLengthNSData.getBytes(&expectedLengthUInt32, length: sizeof(UInt32))
                    expectedLength = Int(expectedLengthUInt32)
                    
                    if VgcManager.netServiceLatencyLogging {

                        var timestampDouble: Double = 0
                        let timestampNSData = dataBuffer.subdataWithRange(NSRange.init(location: 9, length: 8))
                        timestampNSData.getBytes(&timestampDouble, length: sizeof(Double))
                        
                        let transitTime = round(1000 * (NSDate().timeIntervalSince1970 - timestampDouble))
                        //if timestampDouble < lastTimeStamp { vgcLogDebug("Time problem") }
                        //lastTimeStamp = timestampDouble
                        PerformanceVars.totalTransitTime += transitTime
                        PerformanceVars.totalTransitTimeMeasurements++
                        let averageTransitTime = PerformanceVars.totalTransitTime / PerformanceVars.totalTransitTimeMeasurements
                        let aboveAverageTransitTime = transitTime - averageTransitTime
                        let percentageAboveAverage = (averageTransitTime / transitTime) * 100
                        //if percentageAboveAverage > 40 { vgcLogDebug("Above average transit time: \(transitTime)ms by \(aboveAverageTransitTime), \(percentageAboveAverage)% above avg (Avg: \(averageTransitTime))") }
                    }
                    
                } else {
                    
                    // This shouldn't happen
                    dataBuffer = NSMutableData()
                    vgcLogError("Streamer expected header but found no header identifier (\(dataBuffer.length) bytes)")
                    PerformanceVars.invalidMessages++
                    return
                }
                
                if expectedLength == 0 {
                    dataBuffer = NSMutableData()
                    vgcLogError("Streamer got expected length of zero")
                    PerformanceVars.invalidMessages++
                    return
                }

                var elementValueData = NSData()

                if dataBuffer.length < (expectedLength + headerLength) {
                    if logging { vgcLogDebug("Streamer fetching additional data") }
                    break
                }

                elementValueData = dataBuffer.subdataWithRange(NSRange.init(location: headerLength, length: expectedLength))

                let dataRemainingAfterCurrentElement = dataBuffer.subdataWithRange(NSRange.init(location: headerLength + expectedLength, length: dataBuffer.length - expectedLength - headerLength))
                dataBuffer = NSMutableData(data: dataRemainingAfterCurrentElement)
                
                if elementValueData.length == expectedLength {
                    
                    // Performance testing is about calculating elements received per second
                    // By sending motion data, it can be  compared to expected rates.
                    
                    PerformanceVars.messagesReceived++
                    
                    if VgcManager.performanceSamplingEnabled {
                        
                        if Float(PerformanceVars.lastPublicationOfPerformance.timeIntervalSinceNow) < -(VgcManager.performanceSamplingDisplayFrequency) {
                            let messagesPerSecond: Float = PerformanceVars.messagesReceived / VgcManager.performanceSamplingDisplayFrequency
                            let kbPerSecond: Float = (Float(PerformanceVars.bytesReceived) / VgcManager.performanceSamplingDisplayFrequency) / 1000
                            //let invalidChecksumsPerSec: Float = (PerformanceVars.invalidChecksums / VgcManager.performanceSamplingDisplayFrequency)
                            
                            vgcLogDebug("\(messagesPerSecond) msgs/sec, \(PerformanceVars.invalidMessages) invalid messages, \(kbPerSecond) kb/sec received")
                            PerformanceVars.messagesReceived = 0
                            PerformanceVars.invalidMessages = 0
                            PerformanceVars.lastPublicationOfPerformance = NSDate()
                            PerformanceVars.bytesReceived = 0
                        }
                    }
                    
                    //if logging { vgcLogDebug("Got completed data transfer (\(elementValueData.length) of \(expectedLength))") }
                
                    let element = elements.elementFromIdentifier(elementIdentifier!)
                    
                    if element == nil {
                        vgcLogError("Unrecognized element")
                    } else {
                        
                        delegate.receivedNetServiceMessage(elementIdentifier!, elementValue: elementValueData)
                        
                    }

                    elementIdentifier = nil
                    expectedLength = 0
                    
                } else {
                    if logging { vgcLogDebug("Streamer fetching additional data") }
                }

            }

            break
        case NSStreamEvent():
            NSLog("Streamer: All Zeros")
            break
            
        case NSStreamEvent.OpenCompleted:
            if aStream is NSInputStream {
                vgcLogDebug("\(VgcManager.appRole) input stream is now open for \(delegateName)")
            } else {
                vgcLogDebug("\(VgcManager.appRole) output stream is now open for \(delegateName)")
            }
            break
        case NSStreamEvent.HasSpaceAvailable:
            //vgcLogDebug("HAS SPACE AVAILABLE")
            break
            
        case NSStreamEvent.ErrorOccurred:
            vgcLogError("Stream ErrorOccurred: Event Code: \(eventCode) (Delegate Name: \(delegateName))")
            delegate.disconnect!()
            break
            
        case NSStreamEvent.EndEncountered:
            vgcLogDebug("Streamer: EndEncountered (Delegate Name: \(delegateName))")
            delegate.disconnect!()
            
            break
            
        case NSStreamEvent.None:
            vgcLogDebug("Streamer: Event None")
            break
        
            
        default:
            NSLog("default")
        }
    }
    
    func processDataMessage(dataMessage: NSString) {
        
        
        
    }
   
    func netService(sender: NSNetService, didUpdateTXTRecordData data: NSData) {
        vgcLogDebug("CENTRAL: netService NetService didUpdateTXTRecordData")
    }
    
    func netServiceDidPublish(sender: NSNetService) {
        if deviceIsTypeOfBridge() {
            vgcLogDebug("Bridge streamer is now published on: \(sender.domain + sender.type + sender.name)")
        } else {
            vgcLogDebug("Central streamer is now published on: \(sender.domain + sender.type + sender.name)")
        }
    }
    
    func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        vgcLogDebug("CENTRAL: Net service did not publish, error: \(errorDict)")
    }
    
    func netServiceWillPublish(sender: NSNetService) {
        vgcLogDebug("NetService will be published")
    }
    
    func netServiceWillResolve(sender: NSNetService) {
        vgcLogDebug("CENTRAL: netServiceWillResolve")
    }
    
    func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        vgcLogDebug("CENTRAL: netService didNotResolve: \(errorDict)")
    }
    
    func netServiceDidResolveAddress(sender: NSNetService) {
        vgcLogDebug("CENTRAL: netServiceDidResolveAddress")
    }
    
    func netServiceDidStop(sender: NSNetService) {
        vgcLogDebug("CENTRAL: netServiceDidStop")
    }

    
    
}

#endif
