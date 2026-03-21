//
//  PVLegacyWebServerAdapter.swift
//  PVWebServer
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Thin Swift adapter that makes the legacy Objective-C `PVWebServer` singleton
//  conform to `PVWebServerProtocol`, letting `PVWebServerManager` treat old and
//  new servers uniformly.
//

import Foundation
import PVWebServerObjC

/// Wraps the ObjC `PVWebServer` singleton so it can be used behind the
/// `PVWebServerProtocol` interface managed by `PVWebServerManager`.
public final class PVLegacyWebServerAdapter: @unchecked Sendable {

    private let legacy: PVWebServer

    public init() {
        legacy = .shared
    }
}

// MARK: - PVWebServerProtocol

extension PVLegacyWebServerAdapter: PVWebServerProtocol {

    public var isWWWServerRunning: Bool { legacy.isWWWUploadServerRunning }
    public var isWebDAVServerRunning: Bool { legacy.isWebDavServerRunning }

    public var serverURL: URL? { legacy.url }
    public var webDAVURL: URL? {
        guard let str = legacy.webDavURLString else { return nil }
        return URL(string: str)
    }

    @discardableResult
    public func startServers() async throws -> Bool {
        // Legacy ObjC method is synchronous — call off main actor to avoid blocking.
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let ok = self.legacy.startServers()
                continuation.resume(returning: ok)
            }
        }
    }

    public func stopServers() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                self.legacy.stopServers()
                continuation.resume()
            }
        }
    }
}
