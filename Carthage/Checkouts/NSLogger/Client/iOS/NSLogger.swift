/*
 * NSLogger.swift
 *
 * version 1.9.0 25-FEB-2018
 *
 * Part of NSLogger (client side)
 * https://github.com/fpillet/NSLogger
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 *
 * Copyright (c) 2010-2018 Florent Pillet All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of  Florent
 * Pillet nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 *
 */

import Foundation

#if os(iOS) || os(tvOS)
import UIKit
public typealias Image = UIImage
#endif

#if os(OSX)
import Cocoa
public typealias Image = NSImage
#endif

/// The main NSLogger class, use `shared` property to obtain an instance
public final class Logger {
    
    /// The current NSLogger
    public static let shared = Logger()
    
    private init() {}
    
    public struct Domain: RawRepresentable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        
        public static let app = Domain(rawValue: "App")
        public static let view = Domain(rawValue: "View")
        public static let layout = Domain(rawValue: "Layout")
        public static let controller = Domain(rawValue: "Controller")
        public static let routing = Domain(rawValue: "Routing")
        public static let service = Domain(rawValue: "Service")
        public static let network = Domain(rawValue: "Network")
        public static let model = Domain(rawValue: "Model")
        public static let cache = Domain(rawValue: "Cache")
        public static let db = Domain(rawValue: "DB")
        public static let io = Domain(rawValue: "IO")
        
        public static func custom(_ value: String) -> Domain {
            return Domain(rawValue: value)
        }
    }

    public struct Level: RawRepresentable {
        
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        
        public static let error = Level(rawValue: 0)
        public static let warning = Level(rawValue: 1)
        public static let important = Level(rawValue: 2)
        public static let info = Level(rawValue: 3)
        public static let debug = Level(rawValue: 4)
        public static let verbose = Level(rawValue: 5)
        public static let noise = Level(rawValue: 6)
        
        public static func custom(_ value: Int) -> Level {
            return Level(rawValue: value)
        }
    }
    
    private func imageData(_ image: Image) -> (data: Data, width: Int, height: Int)? {
        #if os(iOS) || os(tvOS)
            guard let imageData = UIImagePNGRepresentation(image) else { return nil }
            return (imageData, Int(image.size.width), Int(image.size.height))
        #elseif os(OSX)
          guard let tiff = image.tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiff) else { return nil }
        #if swift(>=4.0)
          let imageData = bitmapRep.representation(using: .png, properties: [:])
        #else
          let imageData = bitmapRep.representation(using: .PNG, properties: [:])
        #endif
          guard let data = imageData  else { return nil }
          return (data, Int(image.size.width), Int(image.size.height))
        #else
            "CompilationError: OS not handled !"
        #endif
    }

    private func whenEnabled(then execute: () -> Void) {
        #if !NSLOGGER_DISABLED || NSLOGGER_ENABLED
            execute()
        #endif
    }
    
    public func log(_ domain: Domain,
                    _ level: Level,
                    _ message: @autoclosure () -> String,
                    _ file: String = #file,
                    _ line: Int = #line,
                    _ function: String = #function) {
        whenEnabled {
            LogMessage_noFormat(file, line, function, domain.rawValue, level.rawValue, message())
        }
    }
    
    public func log(_ domain: Domain,
                    _ level: Level,
                    _ image: @autoclosure () -> Image,
                    _ file: String = #file,
                    _ line: Int = #line,
                    _ function: String = #function) {
        whenEnabled {
            guard let rawImage = imageData(image()) else { return }
            LogImage_noFormat(file, line, function, domain.rawValue, level.rawValue, rawImage.width, rawImage.height, rawImage.data)
        }
    }
    
    public func log(_ domain: Domain,
                    _ level: Level,
                    _ data: @autoclosure () -> Data,
                    _ file: String = #file,
                    _ line: Int = #line,
                    _ function: String = #function) {
        whenEnabled {
            LogData_noFormat(file, line, function, domain.rawValue, level.rawValue, data())
        }
    }
}


