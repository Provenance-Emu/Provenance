//
//  CriticalSectionActor.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

/// actor for adding locks on closures
actor CriticalSectionActor {
    /// executes closure
    /// - Parameter criticalSection: critical section code to execute
    func performWithLock(_ criticalSection: @Sendable @escaping () async -> Void) async {
        await criticalSection()
    }
}
