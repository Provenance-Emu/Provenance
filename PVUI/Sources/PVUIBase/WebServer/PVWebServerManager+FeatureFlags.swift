//
//  PVWebServerManager+FeatureFlags.swift
//  PVUI
//
//  Bridges `PVWebServerManager` to `Defaults[.useModernWebServer]` without
//  pulling `PVSettings` into the `PVWebServer` Swift package graph.
//
//  Filename retained for source-stability; the implementation now reads the
//  user-facing Advanced setting rather than a remote feature flag.
//

import Foundation
import PVSettings
#if canImport(PVWebServer)
import PVWebServer

extension PVWebServerManager {

    /// Aligns `useModernServer` with `Defaults[.useModernWebServer]`.
    /// Synchronous on the manager actor; callers still use `await` to hop onto the actor.
    public func refreshFeatureFlag() {
        setModernServerEnabled(Defaults[.useModernWebServer])
    }
}
#endif
