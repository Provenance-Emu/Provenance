//
//  DiscSerialExtractorPlugin.swift
//  PVHashing
//
//  Plugin protocol for disc serial / product-code extraction.
//

import Foundation

/// The result of a successful serial extraction.
public struct DiscSerialResult: Sendable {
    /// The normalised serial string, e.g. "SLUS-01234", "T-12345H", "GALE01".
    public let serial: String
    /// Raw `SystemIdentifier.rawValue` string hinting which system this disc
    /// belongs to, e.g. `"com.provenance.psx"`.
    /// Consumers should call `SystemIdentifier(rawValue:)` to convert this.
    public let systemIdentifierHint: String?

    public init(serial: String, systemIdentifierHint: String? = nil) {
        self.serial = serial
        self.systemIdentifierHint = systemIdentifierHint
    }
}

/// A plugin that can extract a disc serial / product code from one or more
/// file formats.
///
/// Plugins register with ``DiscSerialExtractorRegistry`` and are dispatched
/// based on file-extension matching and optional magic-byte screening.
///
/// ## Implementing a plugin
/// ```swift
/// public struct MyDiscPlugin: DiscSerialExtractorPlugin {
///     public let supportedExtensions: Set<String> = ["iso"]
///     public let magicByteCount = 16
///     public func matchesMagicBytes(_ header: Data) -> Bool { ... }
///     public func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult? { ... }
/// }
/// ```
///
/// - Important: Implementations must be `Sendable`, must not import UIKit,
///   and must compile on Linux (Foundation only). File I/O should be wrapped
///   in `Task.detached(priority: .utility)` to avoid blocking cooperative threads.
public protocol DiscSerialExtractorPlugin: Sendable {

    /// Lowercase file extensions handled by this plugin, e.g. `["iso", "img"]`.
    var supportedExtensions: Set<String> { get }

    /// How many bytes from the start of the file the registry should read
    /// before calling ``matchesMagicBytes(_:)``.
    /// Return `0` if no magic-byte check is needed.
    var magicByteCount: Int { get }

    /// Returns `true` when the first `magicByteCount` bytes of a file indicate
    /// that this plugin is likely able to decode it.
    ///
    /// Returning `false` causes the registry to skip this plugin without
    /// attempting extraction. Returning `true` when there are no magic bytes
    /// (i.e. `magicByteCount == 0`) is always correct.
    func matchesMagicBytes(_ headerBytes: Data) -> Bool

    /// Attempts to extract the disc serial from the file at `url`.
    ///
    /// - Parameters:
    ///   - url: File to inspect (`.iso`, `.bin`, `.cue`, etc.)
    ///   - systemHint: Optional raw `SystemIdentifier.rawValue` to help
    ///     disambiguate formats with identical magic bytes. May be `nil`.
    /// - Returns: A ``DiscSerialResult`` on success, `nil` if extraction fails.
    func extractSerial(from url: URL, systemHint: String?) async -> DiscSerialResult?
}

// MARK: - Default implementations

public extension DiscSerialExtractorPlugin {
    var magicByteCount: Int { 0 }
    func matchesMagicBytes(_ headerBytes: Data) -> Bool { true }
}
