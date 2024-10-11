//
//  Paths+iCloud.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/8/24.
//

import Foundation
import Defaults
import PVSettings
import PVLogging

// MARK - iCloud
public extension URL {
    
    private
    static let iCloudContainerDirectoryCached: URL? = {
        if Thread.isMainThread {
            var container: URL?
            DispatchQueue.global(qos: .background).sync {
                container = FileManager.default.url(forUbiquityContainerIdentifier: Constants.iCloud.containerIdentifier)
            }
            return container
        } else {
            let container = FileManager.default.url(forUbiquityContainerIdentifier: Constants.iCloud.containerIdentifier)
            return container
        }
    }()

    /// This should be called on a background thread
    static var iCloudContainerDirectory: URL? {
        get {
            return iCloudContainerDirectoryCached
        }
    }

    /// This should be called on a background thread
    static var iCloudDocumentsDirectory: URL? { get {
        let iCloudSync = Defaults[.iCloudSync]
        
        guard iCloudSync else {
            return nil
        }

        let documentsURL = iCloudContainerDirectory?.appendingPathComponent("Documents")
        if let documentsURL = documentsURL {
            if !FileManager.default.fileExists(atPath: documentsURL.path, isDirectory: nil) {
                do {
                    try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    ELOG("Failed creating dir on iCloud: \(error)")
                }
            }
        }

        return documentsURL
    }}

    static var supportsICloud: Bool {
        return iCloudContainerDirectory != nil
    }

    /// This should be called on a background thread
    static var documentsiCloudOrLocalPath: URL { get {
        return iCloudDocumentsDirectory ?? documentsPath
    }}
}
