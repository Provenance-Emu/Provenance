//
//  RelativeRoot.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

import Foundation
import PViCloud

public enum RelativeRoot: Int, Sendable {
    case documents
    case caches
    case iCloud
    
#if os(tvOS)
    public static let platformDefault = RelativeRoot.caches
#else
    public static let platformDefault = RelativeRoot.documents
#endif
}

public extension RelativeRoot {
    
    static var documentsDirectory: URL { URL.documentsPath }
    static var cachesDirectory: URL { URL.cachesPath }
    static var iCloudDocumentsDirectory: URL? { URL.iCloudDocumentsDirectory }
    
    func createRelativePath(fromURL url: URL) -> String {
        // We need the dropFirst to remove the leading /
        return String(url.path.replacingOccurrences(of: directoryURL.path, with: "").dropFirst())
    }
    
    var directoryURL: URL {
        switch self {
        case .documents:
            return RelativeRoot.documentsDirectory
        case .caches:
            return RelativeRoot.cachesDirectory
        case .iCloud:
            if let iCloudDocumentsDirectory = RelativeRoot.iCloudDocumentsDirectory { return iCloudDocumentsDirectory }
            else { return Self.platformDefault.directoryURL }
        }
    }
    
    func appendingPath(_ path: String) -> URL {
        let directoryURL = self.directoryURL
        let url = directoryURL.appendingPathComponent(path)
        //        let url = URL(fileURLWithPath: path, relativeTo: directoryURL)
        return url
    }
}
