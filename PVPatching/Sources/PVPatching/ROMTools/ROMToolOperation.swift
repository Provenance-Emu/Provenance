//
//  ROMToolOperation.swift
//  PVPatching
//
//  Created by Provenance Emu on 2026-10-11.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Extensible foundation for ROM tooling (patch apply today; CHD convert later).
public protocol ROMToolOperation: Sendable {
    /// Stable identifier (e.g. `"apply-patch"`, `"convert-chd"`).
    var id: String { get }
    /// User-visible name.
    var displayName: String { get }
    /// Lowercased file extensions this tool accepts (without dot).
    var supportedInputExtensions: Set<String> { get }

    /// Run the tool on `inputs`, writing outputs under `outputDirectory`.
    func execute(
        inputs: [URL],
        outputDirectory: URL,
        progress: (@Sendable (PatchProgress) -> Void)?
    ) async throws -> [URL]
}

/// Registry of available ROM tools — Patch Applier now; converters later.
public struct ROMToolRegistry: Sendable {
    public var operations: [any ROMToolOperation]

    public init(operations: [any ROMToolOperation] = []) {
        self.operations = operations
    }

    /// Built-in tools. CHD / format converters can be appended without UI rewrites.
    public static let `default` = ROMToolRegistry(operations: [
        ApplyPatchToolOperation()
    ])

    public func operation(id: String) -> (any ROMToolOperation)? {
        operations.first(where: { $0.id == id })
    }

    public func registering(_ operation: any ROMToolOperation) -> ROMToolRegistry {
        var copy = self
        copy.operations.append(operation)
        return copy
    }
}

/// Apply a patch file to a ROM (`inputs` = `[patchURL, romURL]`).
public struct ApplyPatchToolOperation: ROMToolOperation, Sendable {
    public let id = "apply-patch"
    public let displayName = "Apply Patch"
    public let supportedInputExtensions: Set<String> = PatchFormat.implementedFileExtensions

    private let applier: PatchApplier

    public init(applier: PatchApplier = PatchApplier()) {
        self.applier = applier
    }

    public func execute(
        inputs: [URL],
        outputDirectory: URL,
        progress: (@Sendable (PatchProgress) -> Void)?
    ) async throws -> [URL] {
        guard inputs.count >= 2 else {
            throw PatchError.patchApplicationFailed("Apply Patch expects [patchURL, romURL]")
        }
        let patchURL = inputs[0]
        let romURL = inputs[1]
        let exported = try await applier.exportPatchedCopy(
            patchURL: patchURL,
            romURL: romURL,
            to: outputDirectory,
            progress: progress
        )
        return [exported]
    }
}
