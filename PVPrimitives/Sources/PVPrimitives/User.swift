//
//  User.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 11/20/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public struct User: Codable {
    public let uuid: String
    public let name: String

    public let isPatron: Bool
    public let savesAccess: Bool

    public let lastSeen: Date
}
