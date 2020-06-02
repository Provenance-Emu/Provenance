//
//  PVGameLibrary.swift
//  PVLibrary
//
//  Created by Dan Berglund on 2020-05-27.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation

public struct PVGameLibrary {
    private let database: RomDatabase

    public init(database: RomDatabase) {
        self.database = database
    }
}
