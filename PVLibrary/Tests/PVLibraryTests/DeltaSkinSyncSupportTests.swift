//
//  DeltaSkinSyncSupportTests.swift
//  PVLibraryTests
//
//  Pinning-style tests for the file-extension allowlist consumed by the
//  CloudKit and iCloud Drive non-database syncers when replicating
//  `Documents/DeltaSkins/`.  The `skinmeta` sidecar files (written by
//  `SkinSystemOverrideRegistry`) MUST stay in this allowlist or the SG-1000
//  catalog override fix will silently regress on multi-device installs.
//

import Foundation
import Testing
@testable import PVLibrary

@Suite("DeltaSkinSyncSupport allowed extensions")
struct DeltaSkinSyncSupportTests {

    @Test("Includes the deltaskin and manicskin package extensions")
    func includesPackageExtensions() {
        #expect(DeltaSkinSyncSupport.allowedExtensions.contains("deltaskin"))
        #expect(DeltaSkinSyncSupport.allowedExtensions.contains("manicskin"))
    }

    @Test("Includes the skinmeta sidecar extension for catalog overrides")
    func includesSkinmetaSidecar() {
        #expect(DeltaSkinSyncSupport.allowedExtensions.contains("skinmeta"))
    }

    @Test("Does not accidentally allow generic .json (would broadly match)")
    func excludesBareJSON() {
        #expect(!DeltaSkinSyncSupport.allowedExtensions.contains("json"))
    }

    @Test("Directory name remains DeltaSkins")
    func directoryNameIsStable() {
        #expect(DeltaSkinSyncSupport.directoryName == "DeltaSkins")
    }
}
