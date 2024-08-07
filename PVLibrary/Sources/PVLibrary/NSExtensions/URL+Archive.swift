//
//  URL+Archive.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

extension URL {
    var isFileArchive: Bool {
        guard isFileURL else { return false }
        let ext = pathExtension.lowercased()
        return PVEmulatorConfiguration.archiveExtensions.contains(ext)
    }
}
