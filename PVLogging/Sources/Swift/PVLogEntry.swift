//
// PVLogEntry.swift
// Created by: Joe Mattiello
// Creation Date: 1/4/23
//

internal var __PVLogEntryIndexCounter:UInt = 0
// Time of initialization.
// Used to calculate offsets
internal var __PVLoggingStartupTime: Date = Date()

public final class PVLogEntry: NSObject {
    public let time: Date
    public let entryIndex: UInt
    public let offset: TimeInterval
    public var level: Int = 0
    
    public var functionString = ""
    public var lineNumberString = ""
    public var text: String = ""
    
    let levelStrings = ["U", "**Error**", "**WARN**", "I", "D"]
    
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
    
    override public var description: String {
        return "\(offset) [\(functionString):\(lineNumberString):\(levelStrings[level])] \(text)"
    }
    
    var string: String {
        return "\(offset) [\(levelStrings[level])] \(text)"
    }
    
    var stringWithLocation: String {
        return "\(offset) [\(functionString):\(lineNumberString):\(levelStrings[level])] \(text)"
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
