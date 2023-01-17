//
//  PVLoggingEntity.swift
//  
//
//  Created by Joseph Mattiello on 1/4/23.
//

import Foundation

@objc
public protocol PVLoggingEntity {
    /**
     *  Obtain paths of any file logs
     *
     *  @return List of file paths, with newest as the first
     */
    var logFilePaths: [String]? { get }
    
    /**
     *  Writes any async logs
     */
    func flushLogs()
    
    /**
     *  Array of info for the log files such as zie and modification date
     *
     *  @return Sorted list of info dicts, newest first
     */
    var logFileInfos: [AnyObject]? { get }
    
    
    func enableExtraLogging()
}
