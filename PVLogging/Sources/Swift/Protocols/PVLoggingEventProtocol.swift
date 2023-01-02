//
//  PVLoggingEventProtocol.swift
//  
//
//  Created by Joseph Mattiello on 1/4/23.
//

import Foundation

public protocol PVLoggingEventProtocol: AnyObject, Equatable, Hashable {
    func updateHistory(sender: PVLogging)
}
