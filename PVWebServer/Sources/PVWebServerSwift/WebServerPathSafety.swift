//
//  WebServerPathSafety.swift
//  PVWebServer
//
//  Path sandbox checks shared by HTTP/WebDAV handlers.
//

import Foundation

enum WebServerPathSafety {

    /// Returns the resolved URL only if it remains within `baseDir`.
    static func resolvedPath(_ rawPath: String, withinDirectory baseDir: URL) -> URL? {
        let resolved = baseDir.appendingPathComponent(rawPath).standardized
        let basePath = baseDir.standardized.path
        guard resolved.path == basePath || resolved.path.hasPrefix(basePath + "/") else {
            return nil
        }
        return resolved
    }
}
