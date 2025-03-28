//
//  FileSystemActor.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 3/28/25.
//

import Foundation
import PVSupport
import Combine
import PVLogging
import Perception

/// A dedicated actor for file system operations to keep them off the main thread
@globalActor actor FileSystemActor {
    static let shared = FileSystemActor()
    private init() {}
}

/// Actor to prevent crash when mutating and another thread is accessing
actor FileOperationTasks {
    private var fileOperationTasks = Set<Task<Void, Never>>()

    /// inserts item into set
    /// - Parameter item: item to insert
    func insert(_ item: Task<Void, Never>) {
        fileOperationTasks.insert(item)
    }

    /// removes item from set
    /// - Parameter item: item to remove
    func remove(_ item: Task<Void, Never>) {
        fileOperationTasks.remove(item)
    }

    /// clears set
    func removeAll() {
        fileOperationTasks.removeAll()
    }

    /// Cancels all ongoing file operation tasks and clears set after
    func cancelAllFileOperations() {
        for task in fileOperationTasks {
            task.cancel()
        }
        fileOperationTasks.removeAll()
    }
}
