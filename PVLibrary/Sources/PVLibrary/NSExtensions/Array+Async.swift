//
//  Array+Async.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/3/24.
//

import Foundation

extension Array {
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
}

extension Array {
    func concurrentForEach(
        priority: TaskPriority = .default,
        _ operation: @escaping (Element) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask(priority: priority) {
                    await operation(element)
                }
            }
        }
    }
}
