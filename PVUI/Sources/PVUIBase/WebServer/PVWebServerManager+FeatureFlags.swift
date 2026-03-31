//
//  PVWebServerManager+FeatureFlags.swift
//  PVUI
//
//  Keeps `PVWebServerManager` aligned with `PVFeatureFlags` without adding a
//  `PVFeatureFlags` dependency to the `PVWebServer` Swift package (SwiftPM graph).
//

import Foundation
import PVFeatureFlags
#if canImport(PVWebServer)
import PVWebServer

extension PVWebServerManager {

    /// Updates `useModernServer` from `PVFeatureFlags` (bundled config, remote updates, and `PVFeatureFlagsDebugOverrides`).
    /// Synchronous on the manager actor; callers still use `await` to hop onto the actor.
    public func refreshFeatureFlag() {
        setModernServerEnabled(PVFeatureFlags.shared.isEnabled(.modernWebServer))
    }
}
#endif
