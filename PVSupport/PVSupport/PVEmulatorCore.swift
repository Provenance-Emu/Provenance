//
//  PVEmulatorCore.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 3/8/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

@objc public protocol DiscSwappable {
    var currentGameSupportsMultipleDiscs : Bool {get}
    var numberOfDiscs : UInt {get}
    func swapDisc(number: UInt)
}

