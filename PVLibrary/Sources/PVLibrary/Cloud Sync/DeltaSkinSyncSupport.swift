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
    static let allowedExtensions: Set<String> = ["deltaskin", "manicskin"]
}
