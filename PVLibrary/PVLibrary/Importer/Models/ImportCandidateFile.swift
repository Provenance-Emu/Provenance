//
//  ImportCandidateFile.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 7/23/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

public struct ImportCandidateFile: Codable {
    public let filePath: URL
    public var md5: String? {
        if let cached = cache.md5 {
            return cached
        } else {
            let computed = try? FileManager.default.digestsForFile(atPath: filePath, fromOffset: 0).md5
            cache.md5 = computed
            return computed
        }
    }

    // TODO: Add CRC and SHA-1
    public init(filePath: URL) {
        self.filePath = filePath
    }

    // Store a cache in a nested class.
    // The struct only contains a reference to the class, not the class itself,
    // so the struct cannot prevent the class from mutating.
    private final class Cache: Codable {
        var md5: String?
    }

    private var cache = Cache()
}
