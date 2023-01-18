//
//  LogViewable.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/13/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import PVLogging
import Foundation

#if os(iOS)
    @objc
    public protocol LogDisplayer: AnyObject {
        func displayLogViewer()
    }

    extension UIWindow: LogDisplayer {
        @objc public func displayLogViewer() {
            let logViewController = PVLogViewController(nibName: "PVLogViewController", bundle: Bundle(for: PVLogViewController.self))

            // Window incase the mainNav never displays
            var controller: UIViewController? = rootViewController

            if let presentedViewController = controller?.presentedViewController {
                controller = presentedViewController
            }
            controller!.present(logViewController, animated: true, completion: nil)
        }
    }

    extension UIViewController: LogDisplayer {
        func addLogViewerGesture() {
            let secretTap = UITapGestureRecognizer(target: self, action: #selector(displayLogViewer))
            secretTap.numberOfTapsRequired = 3
            #if targetEnvironment(simulator)
                secretTap.numberOfTouchesRequired = 2
            #else
                secretTap.numberOfTouchesRequired = 3
            #endif
            view.addGestureRecognizer(secretTap)
        }

        @objc public func displayLogViewer() {
            let logViewController = PVLogViewController(nibName: "PVLogViewController", bundle: Bundle(for: PVLogViewController.self))
            present(logViewController, animated: true, completion: nil)
        }
    }

    public extension LogDisplayer where Self: UIView {
        func addLogViewerGesture() {
            let secretTap = UITapGestureRecognizer(target: self, action: #selector(displayLogViewer))
            secretTap.numberOfTapsRequired = 3
            #if targetEnvironment(simulator)
                secretTap.numberOfTouchesRequired = 2
            #else
                secretTap.numberOfTouchesRequired = 3
            #endif
            addGestureRecognizer(secretTap)
        }
    }
#endif

public final class PVTTYFormatter: NSObject, DDLogFormatter {
    public struct LogOptions: OptionSet {
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public let rawValue: Int

        public static let printLevel = LogOptions(rawValue: 1 << 0)
        public static let useEmojis = LogOptions(rawValue: 1 << 1)
    }

    public struct EmojiTheme {
        let verbose: String
        let info: String
        let debug: String
        let warning: String
        let error: String

        internal func emoji(for level: DDLogLevel) -> String {
            switch level {
            case .verbose:
                return verbose
            case .debug:
                return debug
            case .info:
                return info
            case .warning:
                return warning
            case .error:
                return error
            default:
                // case .off, .all:
                return ""
            }
        }
    }

    private func secondsToHoursMinutesSeconds(_ timeInterval: Double) -> (Int, Int, Double) {
        let seconds: Double = timeInterval.remainder(dividingBy: 3600)
        let minutes: Double = (timeInterval.remainder(dividingBy: 3600)) / 60
        let hours: Double = timeInterval / 3600
        return (Int(hours), Int(minutes), seconds)
    }

    public struct Themes {
        static let HeartTheme = EmojiTheme(verbose: "💜", info: "💙:", debug: "💚", warning: "💛", error: "❤️")
        static let RecycleTheme = EmojiTheme(verbose: "♳", info: "♴:", debug: "♵", warning: "♶", error: "♷")
        static let BookTheme = EmojiTheme(verbose: "📓", info: "📘:", debug: "📗", warning: "📙", error: "📕")
        static let DiamondTheme = EmojiTheme(verbose: "🔀", info: "🔹:", debug: "🔸", warning: "⚠️", error: "❗")
    }

    static let startTime = Date()

    public var theme: EmojiTheme = PVTTYFormatter.Themes.DiamondTheme
    public var options: LogOptions = [.printLevel, .useEmojis]

    public func format(message logMessage: DDLogMessage) -> String? {
        let emoji = options.contains(.useEmojis) ? theme.emoji(for: logMessage.level) + " " : ""
        let level: String

        switch logMessage.level {
        case .verbose:
            level = "VERBOSE "
        case .debug:
            level = "DEBUG "
        case .info:
            level = "INFO "
        case .warning:
            level = "WARNING "
        case .error:
            level = "ERROR "
        default:
            //        case .off, .all:
            level = ""
        }

        let timeInterval = PVTTYFormatter.startTime.timeIntervalSinceNow * -1
        let (hours, minutes, seconds) = secondsToHoursMinutesSeconds(timeInterval)

        var timeStampBuilder = ""
        if hours > 0 {
            timeStampBuilder += "\(hours):"
        }

        if minutes > 0 {
            timeStampBuilder += "\(minutes):"
        }

        if seconds > 0 {
            timeStampBuilder += String(format: "%02.1fs", arguments: [seconds])
        }

        if timeStampBuilder.count < 8, timeStampBuilder.count > 1 {
            timeStampBuilder = timeStampBuilder.padding(toLength: 8, withPad: " ", startingAt: 0)
        }

        //        let queue = logMessage.queueLabel != "com.apple.main-thread" ? "(\(logMessage.queueLabel))" : ""
        let text = logMessage.message

        return "🕐\(timeStampBuilder) \(emoji)\(level) \(logMessage.fileName):\(logMessage.line).\(logMessage.function ?? "") ↩\n\t☞ \(text)"
    }
}
