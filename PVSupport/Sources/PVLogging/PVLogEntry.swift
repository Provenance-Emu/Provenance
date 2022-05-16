//
//  PVLogEntry.swift
//  
//
//  Created by Joseph Mattiello on 5/15/22.
//

import Foundation

public struct PVLogLevel: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public var hashValue: Int {
        return rawValue
    }

    
    
    static let undefined = PVLogLevel([])
    static let error = PVLogLevel(rawValue: 1 << 0)
    static let warn = PVLogLevel(rawValue: 1 << 1)
    static let info = PVLogLevel(rawValue: 1 << 2)
    static let debug = PVLogLevel(rawValue: 1 << 3)
    static let file = PVLogLevel(rawValue: 1 << 4)
}

fileprivate var __PVLogEntryIndexCounter: UInt = 1
fileprivate let __PVLoggingStartupTime: Date = Date()

@objc
public class PVLogEntry: NSObject {
    private static var toggle = true

    var level: PVLogLevel = .undefined
    var text: String = ""
    
    var classString: String?
    var functionString: String?
    var lineNumberString: String?
    
    // Private
    var time: Date
    var entryIndex: UInt
    var offset: TimeInterval
    
    override init() {
        time = Date()
        entryIndex = __PVLogEntryIndexCounter
        __PVLogEntryIndexCounter += 1
        offset = __PVLoggingStartupTime.timeIntervalSinceNow * -1
    }
    
    var htmlString: String {

            // Colors in theme, ligest to darkest
        let color1: String = "#ECE9F9"
        let color2: String = "#D4D1E0"
        let color3: String = "#B0ADB9"
        let color4: String = "#414045"
        let color5: String = "#37363A"


            // The complimentaries of the first
        let compColor1: String = "#F9F7E9"
        let compColor2: String = "#FFFFFF"

        let timeColor: String = color1
        let functionColor: String = color3
        let lineNumberColor: String = color2

        let textColor: String = PVLogEntry.toggle ? compColor2 : compColor1

            //Toggle background color for each line
        let backgroundColor: String = PVLogEntry.toggle ? color4 : color5
        PVLogEntry.toggle = !PVLogEntry.toggle
        
        return
"""
            <span style="background-color: \(backgroundColor);"> \
            <span id='time' style="color:\(timeColor)">\(offset)</span> \
            <span id='function' style="color:\(functionColor)">\(String(describing: functionString))</span> \
            <span style="color:\(lineNumberColor)">\(lineNumberString)</span> \
            <span style="color:\(textColor)">\(text)</span> \
            </span>
"""
    }
    
    public override var description: String {
        //     return [NSString stringWithFormat:@"%4.2f [%@:%@:%s] %@",offset, functionString, lineNumberString, levelStrings[level], text];
        return ""
    }
    
    var string: String {
//        return [NSString stringWithFormat:@"%4.2f [%s] %@",offset, levelStrings[level], text];
        return ""
    }

    var stringWithLocation: String {
        //     return [self description];

        return ""
    }

}
