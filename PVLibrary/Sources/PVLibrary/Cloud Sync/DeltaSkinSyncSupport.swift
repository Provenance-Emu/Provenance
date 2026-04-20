//
//  DeltaSkinSyncSupport.swift
//  PVLibrary
//
//  Created by ChatGPT on 12/2/25.
//

import Foundation

enum DeltaSkinSyncSupport {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    static let isEnabled = true
    #else
    static let isEnabled = false
    #endif

    static let directoryName = "DeltaSkins"
    /// File extensions that the CloudKit / iCloud Drive non-database syncers
    /// will replicate from `Documents/DeltaSkins/`.
    ///
    /// `skinmeta` covers the catalog override sidecars written next to each
    /// `.deltaskin` / `.manicskin` so user devices stay in sync about which
    /// installed skin maps to which catalog system family — see
    /// ``SkinSystemOverrideRegistry`` in PVUIBase.
    static let allowedExtensions: Set<String> = ["deltaskin", "manicskin", "skinmeta"]
}
