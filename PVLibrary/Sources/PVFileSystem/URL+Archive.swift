//
//  URL+Archive.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

public extension URL {
    var isFileArchive: Bool {
        guard isFileURL else { return false }
        let ext = pathExtension.lowercased()
        return Extensions.archiveExtensions.contains(ext)
    }
}
