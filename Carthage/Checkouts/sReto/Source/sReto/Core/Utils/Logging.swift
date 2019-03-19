//
//  File.swift
//  sReto
//
//  Created by Julian Asamer on 13/11/14.
//  Copyright (c) 2014 - 2016 Chair for Applied Software Engineering
//
//  Licensed under the MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness
//  for a particular purpose and noninfringement. in no event shall the authors or copyright holders be liable for any claim, damages or other liability, 
//  whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
//

import Foundation

/**
* Some Logging functionality used within the framework.
*/

// Set the verbosity setting to control the amount of output given by Reto.
let verbositySetting: LogOutputLevel = .verbose

/** The available output levels */
enum LogOutputLevel: Int {
    /** Print everything */
    case verbose = 4
    /** Print medium + high priority */
    case normal = 3
    /** Print high priority messages only */
    case low = 2
    /** Do not print messages */
    case silent = 1
}

/** Output priority options */
enum LogPriority: Int {
    /** Printed only in the "Verbose" setting */
    case low = 4
    /** Printed in "Nomal" and "Verbose" setting */
    case medium = 3
    /** Printed in all settings except "Silent" */
    case high = 2
}

/** Available message types */
enum LogType {
    /** Used for error messages */
    case error
    /** Used for warning messages*/
    case warning
    /** Used for information messages*/
    case info
}

/**
* Logs a message of given type and priority.
* All messages are prefixed with "Reto", the type and the date of the message.
*
* @param type The type of the message.
* @param priority The priority of the message.
* @param message The message to print.
*/
func log(_ type: LogType, priority: LogPriority, message: String) {
    if priority.rawValue > verbositySetting.rawValue { return }

    switch type {
        case .info: print("Reto[Info] \(Date()): \(message)")
        case .warning: print("Reto[Warn] \(Date()): \(message)")
        case .error: print("Reto[Error] \(Date()): \(message)")
    }
}

/** Convenice method, prints a information message with a given priority. */
func log(_ priority: LogPriority, info: String) {
    log(.info, priority: priority, message: info)
}
/** Convenice method, prints a warning message with a given priority. */
func log(_ priority: LogPriority, warning: String) {
    log(.warning, priority: priority, message: warning)
}
/** Convenice method, prints a error message with a given priority. */
func log(_ priority: LogPriority, error: String) {
    log(.error, priority: priority, message: error)
}
