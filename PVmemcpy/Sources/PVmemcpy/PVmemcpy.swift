//
//  PVmemcpyDelegate.swift
//
//
//  Created by Joseph Mattiello on 6/2/24.
//

import Foundation

import Turbo_Base64_swift
import Turbo_Base64

protocol MemCpyer {
    func memcpy(src: UnsafeMutableRawPointer, dest: UnsafeMutableRawPointer, size: UInt)
}
