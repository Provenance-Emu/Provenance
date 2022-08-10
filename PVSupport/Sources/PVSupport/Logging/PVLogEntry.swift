//
//  PVLogEntry.h
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

import Foundation

public struct PVLogLevel: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let Undefind = PVLogLevel(rawValue: 1 << 0)
    static let Error = PVLogLevel(rawValue: 1 << 1)
    static let Warn = PVLogLevel(rawValue: 1 << 2)
    static let Info = PVLogLevel(rawValue: 1 << 3)
    static let Debug = PVLogLevel(rawValue: 1 << 4)
    static let File = PVLogLevel(rawValue: 1 << 5)

    var string: String {
        switch self {
        case .Undefind: return "u"
        case .Error: return "**Error**"
        case .Warn: return "*WARN*"
        case .Info: return "I"
        case .Debug: return "D"
        case .File: return "F"
        default:
            return ""
        }
    }
}

let __PVLoggingStartupTime: Date = Date()

@objc
public final class PVLogEntry : NSObject {
    // Logging imprance level. Defaults to PVLogLevelUndefined.
    public var level: PVLogLevel = .Debug
    // The text message of the log entry
    @objc public var text: String = ""

/**
 *  Optional, not all entries need this
 */
    // Class of instance that created the log entry
    @objc public var classString: String?
    // Function string of location of log entry
    @objc public var functionString: String?
    // Line numer in file that entry was made
    @objc public var lineNumberString: String?
    
    
    /**
     *  Auto-generated
     */

    static private var g_entryIndex: UInt = 0

        // Time of entry creation
    @objc public private(set) var time: Date = Date()
        // Unique int int key for entry
    @objc public private(set) var entryIndex: UInt = {
        g_entryIndex = g_entryIndex + 1
        return g_entryIndex
    }()
        // Time since known start of app Here for convenience/performance,
        // spread the calculation out.
    @objc public private(set) var offset: TimeInterval = __PVLoggingStartupTime.timeIntervalSinceNow * -1
    
    static var toggle: Bool = true
    
    @objc public lazy var htmlString: String = {
            // Colors in theme, ligest to darkest
        let color1 = "#ECE9F9"
        let color2 = "#D4D1E0"
        let color3 = "#B0ADB9"
        let color4 = "#414045"
        let color5 = "#37363A"


            // The complimentaries of the first
        let compColor1 = "#F9F7E9"
        let compColor2 = "#FFFFFF"

        let timeColor = color1
        let functionColor = color3
        let lineNumberColor = color2

        let textColor = PVLogEntry.toggle ? compColor2 : compColor1

            //Toggle background color for each line
        let backgroundColor = PVLogEntry.toggle ? color4 : color5
        PVLogEntry.toggle = !PVLogEntry.toggle
 
        let htmlString = """
            <span style=\"background-color: \(backgroundColor);\"> \
            <span id='time' style=\"color:\(timeColor)\">\(offset)</span> \
            <span id='function' style=\"color:\(functionColor)\"\(functionString ?? "")</span> \
            <span style=\"color:\(lineNumberColor)\">\(lineNumberString  ?? "")</span> \
            <span style=\"color:\(textColor)\">\(text)</span> \
            </span>
"""
        return htmlString
    }()
    
    @objc public lazy var string: String = {
        return String(format: "%4.2f [%s] %@", offset, level.string, text)
    }()
    
    @objc public lazy var stringWithLocation: String = {
        return description
    }()
    
    @objc public override var description: String {
        return String(format:"%4.2f [%@:%@:%s] %@", offset, functionString ?? "", lineNumberString ?? "", level.string, text)
    }
}
