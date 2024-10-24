//
//  DecompressedEntry.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import SWCompression

struct DecompressedEntry: Sendable {
    let data: Data?
    let info: ContainerEntryInfo & Sendable & Codable
}
