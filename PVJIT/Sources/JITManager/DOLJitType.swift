//
//  DOLJitType.swift
//  
//
//  Created by Joseph Mattiello on 6/1/24.
//

import Foundation

public
enum DOLJitType: UInt, Sendable {
    case none
    case debugger
    case allowUnsigned
    case notRestricted
    case ptrace
    /// JIT via StikDebug VPN-tunnel debugger (similar to JitStreamer).
    case stikDebug
    /// JIT via TrollStore-installed build (`get-task-allow` entitlement granted at install time).
    case trollStore
    /// JIT via the iOS 26+ formal `com.apple.developer.kernel.allow-jit` entitlement / JITAuthorizer API.
    case nativeEntitlement
}
