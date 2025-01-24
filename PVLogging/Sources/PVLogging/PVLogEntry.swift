//
// PVLogEntry.swift
// Created by: Joe Mattiello
// Creation Date: 1/4/23
//
import Foundation

nonisolated(unsafe) internal var __PVLogEntryIndexCounter:UInt = 0
// Time of initialization.
// Used to calculate offsets
internal let __PVLoggingStartupTime: Date = Date()

@objc
public final class PVLogEntry: NSObject {
    public let time: Date
    public let entryIndex: UInt
    public let offset: TimeInterval
    public var level: PVLogLevel = .Debug

    /// Storage for both String and StaticString versions
    private var _fileString: String = ""
    private var _functionString: String = ""
    public var lineNumberString = ""
    public var text: String = ""

    /// Properties to access the strings
    public var fileString: String { _fileString }
    public var functionString: String { _functionString }

    override init () {
        self.time = Date()
        self.entryIndex = __PVLogEntryIndexCounter
        self.offset = __PVLoggingStartupTime.timeIntervalSinceNow * -1
        Task { @MainActor in
            __PVLogEntryIndexCounter += 1
        }
    }

    @objc
    public convenience init(message: String) {
        self.init()
        self.text = message
    }

    public convenience init(message: String, level: PVLogLevel = .Debug, file: StaticString, function: StaticString, lineNumber: String) {
        self.init()
        self.text = message
        self.level = level
        self._fileString = "\(file)"
        self._functionString = "\(function)"
        self.lineNumberString = lineNumber
    }

    override public var description: String {
        return "\(offset) [\(functionString):\(lineNumberString):\(level.rawValue)] \(text)"
    }

    public
    lazy var string: String = { "\(offset) [\(level.rawValue)] \(text)" }()

    public
    lazy var stringWithLocation: String = { "\(offset) [\(functionString):\(lineNumberString):\(level.rawValue)] \(text)" }()

    public
    lazy var htmlString: String = {
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
    }()

    /// Objective-C compatible initializer
    @objc
    public convenience init(message: String, level: PVLogLevel, file: String, function: String, lineNumber: String) {
        self.init()
        self.text = message
        self.level = level
        self._fileString = file
        self._functionString = function
        self.lineNumberString = lineNumber
    }
}
