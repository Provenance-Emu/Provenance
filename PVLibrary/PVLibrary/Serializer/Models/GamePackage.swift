//
//  GamePackage.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/26/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public struct GamePackage: Package {
    public var type: SerializerPackageType { return .game }

    public let data: Data
    public let metadata: Game
    public let saves: [SavePackage]
}
