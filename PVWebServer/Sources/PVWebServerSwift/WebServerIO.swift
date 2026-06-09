//
//  WebServerIO.swift
//  PVWebServer
//
//  Shared I/O constants for the modern HTTP/WebDAV server.
//

import Foundation

/// Tunables shared by HTTP upload, WebDAV PUT, and multipart streaming.
enum WebServerIO {
    /// Unified read/coalesce size for streaming request bodies to disk.
    static let readChunkSize = 1_048_576

    /// Upper bound for a single upload via HTTP POST or WebDAV PUT (8 GB).
    static let maxUploadBytes: Int64 = 8 * 1024 * 1_024 * 1_024
}
