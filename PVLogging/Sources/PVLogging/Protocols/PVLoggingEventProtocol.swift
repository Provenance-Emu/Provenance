//
//  PVLoggingEventProtocol.swift
//  
//
//  Created by Joseph Mattiello on 1/4/23.
//

import Foundation

@objc
public protocol PVLoggingEventProtocol: AnyObject {
    func updateHistory(sender: PVLogging)
}

//@nonobjc
//extension PVLoggingEventProtocol: Equatable, Hashable { }
