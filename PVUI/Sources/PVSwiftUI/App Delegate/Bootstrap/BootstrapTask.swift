//
//  BootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// A single app-startup task with declared dependency and provision keys.
///
/// Implement this protocol for each logical startup component. The
/// ``BootstrapOrchestrator`` uses `dependencies` and `provisions` to build a
/// directed acyclic graph and run independent tasks concurrently.
public protocol BootstrapTask: Sendable {
    /// Human-readable name used for logging and diagnostics.
    var name: String { get }

    /// Dependency keys that must be provided before this task can run.
    var dependencies: [String] { get }

    /// Provision keys this task satisfies after successful completion.
    var provisions: [String] { get }

    /// Execute the startup task.
    ///
    /// Throwing from this method marks the task as failed. The orchestrator
    /// logs the error but continues with remaining tasks so the app can still
    /// launch.
    func execute() async throws
}

/// Well-known provision key constants shared across bootstrap tasks.
public enum BootstrapKey {
    public static let logging       = "logging"
    public static let firebase      = "firebase"
    public static let crashReporting = "crashReporting"
    public static let analytics     = "analytics"
    public static let settings      = "settings"
    public static let theme         = "theme"
    public static let iCloud        = "icloud"
    public static let webServer     = "webserver"
}
