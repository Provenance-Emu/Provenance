//
//  DiscSwappable.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
@objc public protocol DiscSwappable {
    var currentGameSupportsMultipleDiscs: Bool { get }
    var numberOfDiscs: UInt { get }
    func swapDisc(number: UInt)
}
