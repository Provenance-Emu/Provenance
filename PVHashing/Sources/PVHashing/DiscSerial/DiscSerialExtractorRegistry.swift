//
//  DiscSerialExtractorRegistry.swift
//  PVHashing
//
//  Central registry for disc-serial-extractor plugins.
//

import Foundation
import PVLogging

/// Actor-isolated storage for the plugin registry.
///
/// Using a private actor prevents the `NSLock` in async context warnings
/// (NSLock is unsafe to hold across await points in Swift 6 strict concurrency).
private actor DiscSerialPluginStore {
    var plugins: [any DiscSerialExtractorPlugin] = []
    var defaultsRegistered = false

    func append(_ plugin: any DiscSerialExtractorPlugin) {
        plugins.append(plugin)
    }

    func candidates(forExtension ext: String) -> [any DiscSerialExtractorPlugin] {
        plugins.filter { $0.supportedExtensions.contains(ext) }
    }

    func markDefaultsRegistered() -> Bool {
        if defaultsRegistered { return false }
        defaultsRegistered = true
        return true
    }
}

/// Thread-safe registry that dispatches disc-serial extraction to registered
/// ``DiscSerialExtractorPlugin`` instances.
///
/// ## Registering plugins
/// Call ``registerDefaults()`` once at app start (e.g. in `GameImporter.init`)
/// to install all built-in extractors:
/// ```swift
/// await DiscSerialExtractorRegistry.shared.registerDefaults()
/// ```
/// Or use the synchronous variant from a non-async context:
/// ```swift
/// DiscSerialExtractorRegistry.shared.registerDefaultsSync()
/// ```
///
/// ## Extracting a serial
/// ```swift
/// if let result = await DiscSerialExtractorRegistry.shared
///         .extractSerial(from: fileURL, systemHint: system.rawValue) {
///     // result.serial, result.systemIdentifierHint
/// }
/// ```
///
/// ## Adding custom plugins
/// ```swift
/// await DiscSerialExtractorRegistry.shared.register(MyCustomPlugin())
/// ```
/// Earlier registrations take higher priority; the first plugin that both
/// matches the extension AND whose `matchesMagicBytes` returns `true` will
/// be tried first.
public final class DiscSerialExtractorRegistry: Sendable {

    /// The shared singleton.
    public static let shared = DiscSerialExtractorRegistry()

    private let store = DiscSerialPluginStore()

    private init() {}

    // MARK: - Registration

    /// Registers a plugin asynchronously.
    public func register(_ plugin: any DiscSerialExtractorPlugin) async {
        await store.append(plugin)
    }

    /// Registers all built-in plugins in priority order (idempotent).
    ///
    /// Order (highest to lowest priority):
    /// 1. ``M3UDiscSerialPlugin``    — Multi-disc playlist dispatcher
    /// 2. ``BinCueDiscSerialPlugin`` — CUE sheet dispatcher
    /// 3. ``GdiDiscSerialPlugin``    — Dreamcast GDI format
    /// 4. ``ChdDiscSerialPlugin``    — MAME CHD archive
    /// 5. ``SegaDiscSerialPlugin``   — Saturn / SegaCD / Dreamcast header
    /// 6. ``GameCubeDiscSerialPlugin`` — GameCube / Wii disc ID
    /// 7. ``ISODiscSerialPlugin``    — ISO 9660 + PSX/PS2 SYSTEM.CNF
    /// 8. ``NDSDiscSerialPlugin``    — Nintendo DS ROM header
    public func registerDefaults() async {
        guard await store.markDefaultsRegistered() else { return }
        await store.append(M3UDiscSerialPlugin())
        await store.append(BinCueDiscSerialPlugin())
        await store.append(GdiDiscSerialPlugin())
        await store.append(ChdDiscSerialPlugin())
        await store.append(SegaDiscSerialPlugin())
        await store.append(GameCubeDiscSerialPlugin())
        await store.append(ISODiscSerialPlugin())
        await store.append(NDSDiscSerialPlugin())
    }

    /// Synchronous convenience wrapper for call sites that cannot be async
    /// (e.g. `init` methods). Schedules registration in a detached task.
    public func registerDefaultsSync() {
        Task.detached(priority: .userInitiated) { [self] in
            await self.registerDefaults()
        }
    }

    // MARK: - Extraction

    /// Attempts to extract a disc serial from the file at `url`.
    ///
    /// The registry dispatches to the first registered plugin whose
    /// `supportedExtensions` contains the file's lowercased extension AND
    /// whose `matchesMagicBytes(_:)` returns `true`.
    ///
    /// - Parameters:
    ///   - url: The disc image file.
    ///   - systemHint: Optional raw `SystemIdentifier.rawValue` to help
    ///     plugins that handle multiple systems with the same extension.
    /// - Returns: The first successful ``DiscSerialResult``, or `nil`.
    public func extractSerial(from url: URL, systemHint: String? = nil) async -> DiscSerialResult? {
        let ext = url.pathExtension.lowercased()
        let candidates = await store.candidates(forExtension: ext)

        guard !candidates.isEmpty else {
            VLOG("DiscSerialRegistry: no plugin for extension '\(ext)' (\(url.lastPathComponent))")
            return nil
        }

        // Read header bytes once; each plugin only needs a prefix of this data.
        let maxMagic = candidates.map(\.magicByteCount).max() ?? 0
        let headerData = readHeader(from: url, maxBytes: maxMagic)

        for plugin in candidates {
            let pluginHeader = Data(headerData.prefix(plugin.magicByteCount))
            guard plugin.matchesMagicBytes(pluginHeader) else {
                VLOG("DiscSerialRegistry: \(type(of: plugin)) magic-byte check failed for \(url.lastPathComponent)")
                continue
            }

            if let result = await plugin.extractSerial(from: url, systemHint: systemHint) {
                ILOG("DiscSerialRegistry: extracted '\(result.serial)' via \(type(of: plugin)) from \(url.lastPathComponent)")
                return result
            }
        }

        VLOG("DiscSerialRegistry: no plugin could extract serial from '\(url.lastPathComponent)'")
        return nil
    }

    // MARK: - Helpers

    private func readHeader(from url: URL, maxBytes: Int) -> Data {
        guard maxBytes > 0 else { return Data() }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return Data() }
        defer { try? handle.close() }
        do {
            return try handle.read(upToCount: maxBytes) ?? Data()
        } catch {
            return Data()
        }
    }
}
