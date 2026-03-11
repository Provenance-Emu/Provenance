//
//  PVLoggingEventProtocol.swift
//  
//
//  Created by Joseph Mattiello on 1/4/23.
//

import Foundation

#if canImport(ObjectiveC)
@objc
public protocol PVLoggingEventProtocol: AnyObject {
    func updateHistory(sender: PVLogging)
}
#else
public protocol PVLoggingEventProtocol: AnyObject {
    func updateHistory(sender: PVLogging)
}
#endif

//@nonobjc
//extension PVLoggingEventProtocol: Equatable, Hashable { }
