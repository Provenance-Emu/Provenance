//
//  URL+Extensions.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

/// Extension to provide pathDecoded property for URL
extension URL {
    /// Returns the path of the URL with percent encoding removed
    /// This is useful when working with file paths that may contain special characters
    var pathDecoded: String {
        /// Decode the path component of the URL to handle special characters
        return path(percentEncoded: false)
    }
}

extension URL {
    var system : SystemIdentifier? {
        return SystemIdentifier(rawValue: parentPathComponent)
    }
    var parentPathComponent: String {
        deletingLastPathComponent().lastPathComponent
    }
    
    var fileName: String {
        lastPathComponent.removingPercentEncoding ?? lastPathComponent
    }
    
    var multiFileNameKey: String? {
        guard "cue".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "bin".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "ccd".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "img".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "sub".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "m3u".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "mds".caseInsensitiveCompare(pathExtension) == .orderedSame
                || "mdf".caseInsensitiveCompare(pathExtension) == .orderedSame
        else {
            return nil
        }
        let key = PVEmulatorConfiguration.stripDiscNames(fromFilename: deletingPathExtension().pathDecoded)
        DLOG("key: \(key)")
        return key
    }
}
