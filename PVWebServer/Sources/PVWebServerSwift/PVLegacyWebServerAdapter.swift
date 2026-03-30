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
import PVLogging
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

    /// Runs `PVWebServer` on the main **queue** (UIKit / `NSUserActivity` / GCDWebServer expectations).
    /// Uses `DispatchQueue.main.async` instead of `MainActor.run` so callers on `@MainActor` that
    /// `await PVWebServerManager.shared.start()` do not deadlock (actor waits for MainActor while MainActor waits for the actor).
    @discardableResult
    public func startServers() async throws -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.main.async { [legacy] in
                let ok = legacy.startServers()
                ILOG("[LegacyWebServerAdapter] startServers on main queue → \(ok)")
                continuation.resume(returning: ok)
            }
        }
    }

    /// Stops legacy servers asynchronously on the main queue (pairs with `startServers()` threading).
    public func stopServers() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { [legacy] in
                legacy.stopServers()
                continuation.resume()
            }
        }
    }
}
