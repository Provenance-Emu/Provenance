//
//  RelativeRoot.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

import Foundation

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
        let urlPath = url.path
        let dirPath = directoryURL.path

        // If the URL path starts with the directory path, extract the relative portion
        if urlPath.hasPrefix(dirPath) {
            let relativePath = String(urlPath.dropFirst(dirPath.count))
            // Remove leading slash if present
            return relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        }

        // If URL doesn't match current directory, try to extract relative path from common patterns
        // Look for common path components that indicate where the relative portion starts
        let commonPatterns = ["/Documents/", "/Caches/", "/Save States/", "Save States/", "Documents/", "Caches/"]

        for pattern in commonPatterns {
            if let range = urlPath.range(of: pattern) {
                let relativeStart = urlPath.index(range.upperBound, offsetBy: 0)
                let relativePath = String(urlPath[relativeStart...])
                // Remove leading slash if present
                return relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
            }
        }

        // Check if this contains an app bundle path (with or without leading slash, anywhere in string)
        let containsAppBundlePath = urlPath.contains("/var/mobile/") ||
                                   urlPath.contains("var/mobile/") ||
                                   urlPath.contains("/private/var/mobile/") ||
                                   urlPath.contains("private/var/mobile/") ||
                                   urlPath.contains("/Containers/Data/Application/") ||
                                   urlPath.contains("Containers/Data/Application/")

        if containsAppBundlePath {
            // Extract relative path from app bundle path
            // Extract starting from "Documents" or "Caches" to preserve "Save States" folder
            let pathComponents = (urlPath as NSString).pathComponents
            if pathComponents.count >= 2 {
                if let documentsIndex = pathComponents.firstIndex(where: { $0 == "Documents" || $0 == "Caches" }) {
                    // Extract everything after "Documents" or "Caches" (includes "Save States" if present)
                    let relativeComponents = Array(pathComponents[(documentsIndex + 1)...])
                    return relativeComponents.joined(separator: "/")
                }
                // Otherwise, take the last two components (directory + filename)
                let relativeComponents = Array(pathComponents.suffix(2))
                return relativeComponents.joined(separator: "/")
            }
        }

        // If we can't find a pattern, check if it's already a relative path (doesn't start with /var/, /private/, etc.)
        if !urlPath.hasPrefix("/var/") && !urlPath.hasPrefix("/private/") && !urlPath.hasPrefix("/Users/") {
            // Might already be relative, but remove leading slash if present
            return urlPath.hasPrefix("/") ? String(urlPath.dropFirst()) : urlPath
        }

        // Last resort: try to extract just the filename and last directory component
        // This handles cases where we have a full absolute path from a different app bundle
        let pathComponents = (urlPath as NSString).pathComponents
        if pathComponents.count >= 2 {
            // Try to find "Documents" or "Caches" to preserve "Save States" folder
            if let documentsIndex = pathComponents.firstIndex(where: { $0 == "Documents" || $0 == "Caches" }) {
                // Extract everything after "Documents" or "Caches" (includes "Save States" if present)
                let relativeComponents = Array(pathComponents[(documentsIndex + 1)...])
                return relativeComponents.joined(separator: "/")
            }
            // Otherwise, take the last two components (directory + filename)
            let relativeComponents = Array(pathComponents.suffix(2))
            return relativeComponents.joined(separator: "/")
        }

        // Fallback: return just the filename
        return url.lastPathComponent
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
