//
//  CoreOptional.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public protocol CoreOptional: AnyObject {
    static var options: [CoreOption] { get }
}
