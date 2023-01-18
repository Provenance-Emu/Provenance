//
// PVLogEntry.swift
// Created by: Joe Mattiello
// Creation Date: 1/4/23
//
import Foundation

internal var __PVLogEntryIndexCounter:UInt = 0
// Time of initialization.
// Used to calculate offsets
internal var __PVLoggingStartupTime: Date = Date()

@objc
public final class PVLogEntry: NSObject {
    public let time: Date
    public let entryIndex: UInt
    public let offset: TimeInterval
    public var level: PVLogLevel = .Debug

    public var fileString: StaticString = ""
    public var functionString: StaticString = ""
    public var lineNumberString = ""
    public var text: String = ""

    override init () {
        self.time = Date()
        self.entryIndex = __PVLogEntryIndexCounter
        self.offset = __PVLoggingStartupTime.timeIntervalSinceNow * -1
        __PVLogEntryIndexCounter += 1
    }
    
    public convenience init(message: String) {
        self.init()
        self.text = message
    }

    public convenience init(message: String, level: PVLogLevel = .Debug, file: StaticString, function: StaticString, lineNumber: String) {
        self.init()
        self.text = message
        self.level = level
        self.fileString = file
        self.functionString = function
        self.lineNumberString = lineNumber
    }
    
    override public var description: String {
        return "\(offset) [\(functionString):\(lineNumberString):\(level.rawValue)] \(text)"
    }
    
    var string: String {
        return "\(offset) [\(level.rawValue)] \(text)"
    }
    
    var stringWithLocation: String {
        return "\(offset) [\(functionString):\(lineNumberString):\(level.rawValue)] \(text)"
    }
    
    var htmlString: String {
        let toggle = entryIndex % 2 == 0
        let color1 = "#ECE9F9"
        let color2 = "#D4D1E0"
        let color3 = "#B0ADB9"
        let color4 = "#414045"
        let color5 = "#37363A"
        
        let compColor1 = "#F9F7E9"
        let compColor2 = "#FFFFFF"
        
        let timeColor = color1
        let functionColor = color3
        let lineNumberColor = color2
        
        let textColor = toggle ? compColor2 : compColor1
        
        let backgroundColor = toggle ? color4 : color5
        
        return """
        <span style="background-color: \(backgroundColor);">
        <span id='time' style="color:\(timeColor)";>\(offset)</span>
        <span id='function' style="color:\(functionColor)";>\(functionString)</span>
        <span style="color:\(lineNumberColor)";>\(lineNumberString)</span>
        <span style="color:\(textColor)";>\(text)</span>
        </span>
        """
    }
}
