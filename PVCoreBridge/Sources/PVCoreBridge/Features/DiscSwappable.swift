//
//  DiscSwappable.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
@objc public protocol DiscSwappable {
    @MainActor
    var currentGameSupportsMultipleDiscs: Bool { get }
    @MainActor
    var numberOfDiscs: UInt { get }
    @MainActor
    func swapDisc(number: UInt)
}
