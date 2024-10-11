//
//  FileManager+Coordination.swift
//  
//
//  Created by Drew McCormack on 08/06/2022.
//

import Foundation

/// Wrapper for FileManager that offers async methods
/// These methods handle file coordination, which is quite useful
/// An actor will block during file coordination, which means that
/// there is no parallelism in this type. If you want to get parallelism (eg multiple threads)
/// you should make one of these managers for each file operation.
public actor CoordinatedFileManager {
    
    private(set) var presenter: (any NSFilePresenter)?
    
    private let fileManager = FileManager()
    
    public init(presenter: (any NSFilePresenter)? = nil) {
        self.presenter = presenter
    }
            
    public func fileExists(coordinatingAccessAt fileURL: URL) throws -> (exists: Bool, isDirectory: Bool) {
        var isDir: ObjCBool = false
        var exists: Bool = false
        try coordinate(readingItemAt: fileURL) { [self] url in
            exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        }
        return (exists, isDir.boolValue)
    }
    
    public func createDirectory(coordinatingAccessAt dirURL: URL, withIntermediateDirectories: Bool) throws {
        try coordinate(writingItemAt: dirURL, options: .forMerging) { [self] url in
            try fileManager.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
        }
    }
    
    public func removeItem(coordinatingAccessAt dirURL: URL) throws {
        try coordinate(writingItemAt: dirURL, options: .forDeleting) { [self] url in
            try fileManager.removeItem(at: url)
        }
    }
    
    public func copyItem(coordinatingAccessFrom fromURL: URL, to toURL: URL) throws {
        try coordinate(readingItemAt: fromURL, readOptions: [], writingItemAt: toURL, writeOptions: .forReplacing) { readURL, writeURL in
            try fileManager.copyItem(at: readURL, to: writeURL)
        }
    }
    
    public func contentsOfDirectory(coordinatingAccessAt dirURL: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        var contentsURLs: [URL] = []
        try coordinate(readingItemAt: dirURL) { [self] url in
            contentsURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
        }
        return contentsURLs
    }
    
    public func contentsOfFile(coordinatingAccessAt url: URL) throws -> Data {
        var data: Data = .init()
        try coordinate(readingItemAt: url) { url in
            data = try Data(contentsOf: url)
        }
        return data
    }
    
    public func write(_ data: Data, coordinatingAccessTo url: URL) throws {
        try coordinate(writingItemAt: url) { url in
            try data.write(to: url)
        }
    }
    
    public func updateFile(coordinatingAccessTo url: URL, in block: @Sendable @escaping (URL) throws -> Void) throws {
        try coordinate(writingItemAt: url) { url in
            try block(url)
        }
    }

    public func readFile(coordinatingAccessTo url: URL, in block: @Sendable @escaping (URL) throws -> Void) throws {
        try coordinate(readingItemAt: url) { url in
            try block(url)
        }
    }
    
    private var executionBlock: ((URL) throws -> Void)?
    private func execute(onSecurityScopedResource url: URL) throws {
        guard let executionBlock else { fatalError() }
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        try executionBlock(url)
        self.executionBlock = nil
    }
    
    private func coordinate(readingItemAt url: URL, options: NSFileCoordinator.ReadingOptions = [], with block: @escaping (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var managerError: Swift.Error?
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        executionBlock = block
        coordinator.coordinate(readingItemAt: url, options: options, error: &coordinatorError) { url in
            do {
                try execute(onSecurityScopedResource: url)
            } catch {
                managerError = error
            }
        }
        guard coordinatorError == nil else { throw coordinatorError! }
        guard managerError == nil else { throw managerError! }
    }
    
    private func coordinate(writingItemAt url: URL, options: NSFileCoordinator.WritingOptions = [], with block: @escaping (URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var managerError: Swift.Error?
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        executionBlock = block
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinatorError) { url in
            do {
                try execute(onSecurityScopedResource: url)
            } catch {
                managerError = error
            }
        }
        guard coordinatorError == nil else { throw coordinatorError! }
        guard managerError == nil else { throw managerError! }
    }
    
    private func coordinate(readingItemAt readURL: URL, readOptions: NSFileCoordinator.ReadingOptions = [], writingItemAt writeURL: URL, writeOptions: NSFileCoordinator.WritingOptions = [], with block: (_ readURL: URL, _ writeURL: URL) throws -> Void) throws {
        var coordinatorError: NSError?
        var managerError: Swift.Error?
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        coordinator.coordinate(readingItemAt: readURL, options: readOptions, writingItemAt: writeURL, options: writeOptions, error: &coordinatorError) { (read: URL, write: URL) in
            do {
                let shouldStopAccessingRead = read.startAccessingSecurityScopedResource()
                let shouldStopAccessingWrite = write.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessingRead {
                        read.stopAccessingSecurityScopedResource()
                    }
                    if shouldStopAccessingWrite {
                        write.stopAccessingSecurityScopedResource()
                    }
                }
                try block(read, write)
            } catch {
                managerError = error
            }
        }
        guard coordinatorError == nil else { throw coordinatorError! }
        guard managerError == nil else { throw managerError! }
    }
}
