//
//  RootRelativePath.swift
//  
//
//  Created by Drew McCormack on 25/06/2022.
//

import Foundation

/// Used as a relative path to the files and directories
/// in the container. Can also be seen as an identifier
/// of files and directoreis.
/// It is convenient to extend this type  and declare static
/// instances for common files or directoeies in your app.
public struct RootRelativePath: Hashable, Sendable {
    
    public var path: String
    
    public init(path: String) {
        self.path = path
    }
    
    public func fileURL(forRoot rootDirURL: URL) throws -> URL {
        guard rootDirURL.isFileURL, rootDirURL.hasDirectoryPath else {
            throw Error.rootDirectoryURLIsNotDirectory
        }
        return rootDirURL.appendingPathComponent(path)
    }
    
    public func directoryURL(forRoot rootDirURL: URL) throws -> URL {
        guard rootDirURL.isFileURL, rootDirURL.hasDirectoryPath else {
            throw Error.rootDirectoryURLIsNotDirectory
        }
        return rootDirURL.appendingPathComponent(path, isDirectory: true)
    }
    
    public func appending(_ addition: String) -> RootRelativePath {
        .init(path: (path as NSString).appendingPathComponent(addition))
    }
    
    /// The root of the container
    public static let root: Self = Self(path: "")
}
