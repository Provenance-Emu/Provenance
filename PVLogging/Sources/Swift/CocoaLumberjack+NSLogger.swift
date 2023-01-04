//
//  CocoaLumberjack+NSLogger.swift
//  CocoaLumberjack+NSLogger
//
//  Created by Joseph Mattiello on 8/13/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

#if canImport(NSLogger)
import Foundation
@_exported import NSLogger
@_exported import CocoaLumberjackSwift

internal class JMLumberjackNSLogger: DDAbstractLogger {
    var logger: NSLogger.Logger { return NSLogger.Logger.shared }
    var tags = [Int: String]()

    public func set(tag: String, for context: Int) {
        tags[context] = tag
    }

    override public convenience init() {
        self.init(bonjourServiceName: nil)
    }

    public init(bonjourServiceName: String? = nil) {
        super.init()

        withLogger {
            if let bonjourServiceName = bonjourServiceName {
                LoggerSetupBonjour($0, nil, bonjourServiceName as CFString)
            }
            var options = LoggerOption.default
            options.remove(.captureSystemConsole)
            LoggerSetOptions($0, options.rawValue)
        }
    }

    // Convenience function wrapper for unsafe OpaquePonter to current Logger instance for C functions of NSLogger
    @discardableResult
    func withLogger<Result>(_ body: (OpaquePointer) throws -> Result) rethrows -> Result {
        #if true
        let logger = LoggerGetDefaultLogger()!
        return try body(logger)
        #else
        return try withUnsafePointer(to: logger) { unsafe -> Result in
            let ptr = OpaquePointer(unsafe)
            return try body(ptr)
        }
        #endif
    }

    deinit {
        withLogger {
            LoggerStop($0)
        }
    }

    public override var loggerName: DDLoggerName {
        return DDLoggerName("cocoa.lumberjack.NSLogger")
    }

    public override func didAdd() {
        withLogger {
            LoggerStart($0)
        }
    }

    public override func flush() {
        withLogger {
            LoggerFlush($0, false)
        }
    }

    public override func log(message: DDLogMessage) {
        let filename: String = message.fileName
        let lineNumber: Int = Int(message.line)
        let functionName: String? = message.function
        let contextTag: String? = tags[message.context]
        let domain: String? = contextTag ?? message.representedObject as? String ?? filename
//        let level: Int = message.level.nsloggerLevel.rawValue
        let level: Int = message.flag.nsloggerLevel.rawValue

        // Note: Using the logFormatter seem to deadlock - no needed - jm
//        let messageString: String = logFormatter?.format(message: message) ?? message.message
        let messageString: String = message.message

        SetThreadNameWithMessage(message)

        // Send Cocoalumberjack Log struct to NSLogger's C function
        if let data = MessageAsData(message: messageString) {
            #if canImport(UIKit)
            if let image = UIImage(data: data), let cgImage = image.cgImage, let imgData = image.pngData() {
                LogImage_noFormat(filename, lineNumber, functionName, domain, level, cgImage.width, cgImage.height, imgData)
            } else {
                LogData_noFormat(filename, lineNumber, functionName, domain, level, data)
            }
            #else
            LogData_noFormat(filename, lineNumber, functionName, domain, level, data)
            #endif
        } else {
            LogMessage_noFormat(filename, lineNumber, functionName, domain, level, messageString)
        }
    }
}

private func MessageAsData(message: String) -> Data? {
    guard message.hasPrefix("<") && message.hasSuffix(">") else { return nil }
    var message = message
    message.removeFirst()
    message.removeLast()
    message = message.replacingOccurrences(of: " ", with: "")
    guard let data = message.hexadecimal, !data.isEmpty else { return nil }
    return data
}

private let queueLabels: [String: String] = [
    "com.apple.root.user-interactive-qos": "User Interactive QoS" /* QOS_CLASS_USER_INTERACTIVE */,
    "com.apple.root.user-initiated-qos": "User Initiated QoS" /* QOS_CLASS_USER_INITIATED */,
    "com.apple.root.default-qos": "Default QoS" /* QOS_CLASS_DEFAULT */,
    "com.apple.root.utility-qos": "Utility QoS" /* QOS_CLASS_UTILITY */,
    "com.apple.root.background-qos": "Background QoS" /* QOS_CLASS_BACKGROUND */,
    "com.apple.main-thread": "Main Queue"
]

private func SetThreadNameWithMessage(_ logMessage: DDLogMessage) {
    // There is no _thread name_ parameter for LogXXXToF functions, but we can abuse NSLogger’s thread name caching mechanism which uses the current thread dictionary
    let queueLabel: String = queueLabels[logMessage.queueLabel] ?? logMessage.queueLabel
    let threadID = logMessage.threadID
    Thread.current.threadDictionary["__$NSLoggerThreadName$__"] = "\(threadID) [\(queueLabel)]"
}

extension String {

    /// Create `Data` from hexadecimal string representation
    ///
    /// This creates a `Data` object from hex string. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.

    var hexadecimal: Data? {
        var data = Data(capacity: count / 2)

        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }

        guard !data.isEmpty else { return nil }

        return data
    }

}

struct LoggerOption: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    static let logToConsole: LoggerOption = LoggerOption(rawValue: 0x01)
    static let bufferLogsUntilConnection: LoggerOption = LoggerOption(rawValue: 0x02)
    static let browseBonjour: LoggerOption = LoggerOption(rawValue: 0x04)
    static let browseOnlyLocalDomain: LoggerOption = LoggerOption(rawValue: 0x08)
    static let useSSL: LoggerOption = LoggerOption(rawValue: 0x10)
    static let captureSystemConsole: LoggerOption = LoggerOption(rawValue: 0x20)
    static let browsePeerToPeer: LoggerOption = LoggerOption(rawValue: 0x40)

    public static let `default`: LoggerOption = [.bufferLogsUntilConnection,
                                                 .browseBonjour,
                                                 .browsePeerToPeer,
                                                 .browseOnlyLocalDomain,
                                                 .useSSL,
                                                 .captureSystemConsole]
}

extension JMLumberjackNSLogger {
    var debugString: String {
        var debugDescription = ""

        var bonjourServiceName: String?
        var viewerHost: String?
        var options: LoggerOption = LoggerOption()

        withLogger { logger in
            bonjourServiceName = LoggerGetBonjourServiceName(logger)?.takeRetainedValue() as String?
            viewerHost = LoggerGetViewerHostName(logger)?.takeRetainedValue()  as String?
            let o = LoggerGetOptions(logger)
            options = LoggerOption(rawValue: o)
        }

        if let bonjourServiceName = bonjourServiceName {
            debugDescription += "\n\tBonjour Service Name: \(bonjourServiceName)"
        }

        if let viewerHost = viewerHost {
            withLogger { logger in
                let port = LoggerGetViewerPort(logger)
                debugDescription += "\n\tViewer Host: \(viewerHost):\(port)"
            }
        }

        debugDescription += "\n\tOptions:"
        debugDescription += "\n\t\tLog To Console:               \(options.contains(.logToConsole) ? "YES" : "NO")"
        debugDescription += "\n\t\tCapture System Console:       \(options.contains(.captureSystemConsole) ? "YES" : "NO")"
        debugDescription += "\n\t\tBuffer Logs Until Connection: \(options.contains(.bufferLogsUntilConnection) ? "YES" : "NO")"
        debugDescription += "\n\t\tBrowse Bonjour:               \(options.contains(.browseBonjour) ? "YES" : "NO")"
        debugDescription += "\n\t\tBrowse Peer-to-Peer:          \(options.contains(.browsePeerToPeer) ? "YES" : "NO")"
        debugDescription += "\n\t\tBrowse Only Local Domain:     \(options.contains(.browseOnlyLocalDomain) ? "YES" : "NO")"
        debugDescription += "\n\t\tUse SSL:                      \(options.contains(.useSSL) ? "YES" : "NO")"

        if !tags.isEmpty {
            debugDescription += "\n\tTags:"
            let s = tags.map { key, value -> String in
                return  "\t\t\(key) -> \(value)"
                }.joined(separator: "\n")
            debugDescription += s
        }
        return debugDescription
    }
}
#endif
