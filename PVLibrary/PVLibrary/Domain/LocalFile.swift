//
//  LocalFile.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public struct LocalFile: LocalFileProvider, Codable, Equatable {
    public let url: URL
    public var data: Data? {
        return try? Data(contentsOf: url)
    }

    private var md5Cache: String?

    public var md5: String? {
        mutating get {
            guard online else {
                return nil
            }

            if let md5Cache = md5Cache {
                return md5Cache.uppercased()
            } else {
                let md5 = FileManager.default.md5ForFile(atPath: url.path, fromOffset: 0)
                md5Cache = md5
                return md5
            }
        }
    }

    public var size: UInt64 {
        guard let s = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return 0
        }

        return UInt64(s ?? 0)
    }

    public init?(url: URL) {
        guard url.isFileURL else {
            return nil
        }

        self.url = url
    }
}
