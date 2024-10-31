//
//  DOLJitType.swift
//  
//
//  Created by Joseph Mattiello on 6/1/24.
//

import Foundation

public
enum DOLJitType: UInt, Sendable {
    case none
    case debugger
    case allowUnsigned
    case notRestricted
    case ptrace
}
