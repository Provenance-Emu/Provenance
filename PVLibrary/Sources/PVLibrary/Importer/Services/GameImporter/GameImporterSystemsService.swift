//
//  GameImporterSystemsService.swift
//  PVLibrary
//
//  Created by David Proskin on 11/7/24.
//

import Foundation
import PVLookup

actor GameImporterSystemsService {
    private let lookup: PVLookup

    init(lookup: PVLookup = .shared) {
        self.lookup = lookup
    }

    func system(forRomAt url: URL, md5: String) async throws -> Int? {
        let filename = url.lastPathComponent
        return try await lookup.system(forRomMD5: md5, or: filename)
    }
}
