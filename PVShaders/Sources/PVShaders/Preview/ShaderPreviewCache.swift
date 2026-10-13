//
//  ShaderPreviewCache.swift
//  PVShaders
//
//  Memory and disk cache plus scheduling in front of a preview renderer.
//

import CoreGraphics
import Foundation
import ImageIO
import PVLogging
import UniformTypeIdentifiers

/// Identifies one rendered preview. Two requests with equal keys produce the same pixels.
public struct ShaderPreviewKey: Hashable, Sendable {
    public let shader: ShaderID
    /// `ShaderPreviewSource.cacheIdentity`.
    public let source: String
    public let width: Int
    public let height: Int
    /// Stable hash of the parameter values the preview is rendered with. Native filters
    /// render with the values in `Defaults`, so those are hashed whatever `parameterValue` says.
    public let parameterHash: UInt64
    /// Whether the source is a game frame (kept out of the disk tier).
    let isGameFrame: Bool

    public init(entry: ShaderCatalogEntry,
                source: ShaderPreviewSource,
                size: CGSize,
                parameterValue: (ShaderParameterDescriptor) -> Float) {
        shader = entry.id
        self.source = source.cacheIdentity
        width = Int(size.width.rounded())
        height = Int(size.height.rounded())
        isGameFrame = source.isGameFrame
        var hash = FNV1a()
        for parameter in entry.parameters where !parameter.isHeading {
            hash.add(parameter.name)
            let value = entry.id.kind == .native ? NativeShaderParameters.value(of: parameter) : parameterValue(parameter)
            hash.add(value.bitPattern)
        }
        parameterHash = hash.value
    }

    /// Process-independent file name stem (`Hashable` is seeded per launch).
    func fileStem(version: String) -> String {
        var hash = FNV1a()
        hash.add(version)
        hash.add(shader.rawValue)
        hash.add(source)
        hash.add(UInt32(truncatingIfNeeded: width))
        hash.add(UInt32(truncatingIfNeeded: height))
        hash.add(parameterHash)
        return String(hash.value, radix: 16)
    }
}

/// 64-bit FNV-1a, for hashes that must be identical across launches.
private struct FNV1a {
    private(set) var value: UInt64 = 0xcbf2_9ce4_8422_2325
    private static let prime: UInt64 = 0x0000_0100_0000_01b3

    mutating func add(_ byte: UInt8) {
        value = (value ^ UInt64(byte)) &* Self.prime
    }

    mutating func add(_ string: String) {
        string.utf8.forEach { add($0) }
        add(0)
    }

    mutating func add<T: FixedWidthInteger>(_ integer: T) {
        withUnsafeBytes(of: integer.littleEndian) { $0.forEach { add($0) } }
    }
}

/// Produces one preview image; `ShaderPreviewCache` calls it for every cache miss.
public typealias ShaderPreviewRenderFunction = @Sendable (
    _ entry: ShaderCatalogEntry,
    _ source: ShaderPreviewSource,
    _ size: CGSize,
    _ parameterValue: @Sendable (ShaderParameterDescriptor) -> Float
) async throws -> CGImage

/// Caches filter previews and schedules the renders behind them.
///
/// - A small in-memory LRU, plus optional PNG files on disk (never for game frames).
/// - Concurrent requests for the same key share one render.
/// - At most `maxConcurrentRenders` renders run at once; the rest wait their turn.
/// - A request gives up after `timeout` of actual rendering and returns `nil`.
///   The render keeps going (and keeps its slot) until it finishes, then fills the
///   cache for the next request.
/// - A request whose callers all went away (task cancelled) before its render
///   started never renders.
public actor ShaderPreviewCache {
    /// Images kept in memory by default.
    public static let defaultMemoryLimit = 64
    /// Renders allowed at once by default.
    public static let defaultMaxConcurrentRenders = 2
    /// Rendering time after which a request returns `nil` by default.
    public static let defaultTimeout = Duration.seconds(2)

    /// One render in progress or queued.
    private struct Flight {
        /// Resolves with the image, or `nil` on failure, timeout or abandonment.
        let outcome: Task<CGImage?, Never>
        /// Callers still waiting for it.
        var waiters: Set<UUID>
        /// Whether it holds a render slot.
        var started = false
    }

    private struct SlotRequest {
        let key: ShaderPreviewKey
        let continuation: CheckedContinuation<Bool, Never>
    }

    private let render: ShaderPreviewRenderFunction
    private let diskDirectory: URL?
    private let diskVersion: String
    private let memoryLimit: Int
    private let maxConcurrentRenders: Int
    private let timeout: Duration

    private var images: [ShaderPreviewKey: CGImage] = [:]
    /// Keys in `images`, least recently used first.
    private var usage: [ShaderPreviewKey] = []
    private var flights: [ShaderPreviewKey: Flight] = [:]
    private var activeRenders = 0
    private var slotQueue: [SlotRequest] = []

    /// - Parameters:
    ///   - diskDirectory: where to keep PNG files (for example `Caches/ShaderPreviews`); `nil` for memory only.
    ///   - diskVersion: bump to invalidate every file on disk (library or renderer changes).
    ///   - render: how to produce an image on a cache miss.
    public init(diskDirectory: URL? = nil,
                diskVersion: String = "1",
                memoryLimit: Int = ShaderPreviewCache.defaultMemoryLimit,
                maxConcurrentRenders: Int = ShaderPreviewCache.defaultMaxConcurrentRenders,
                timeout: Duration = ShaderPreviewCache.defaultTimeout,
                render: @escaping ShaderPreviewRenderFunction) {
        self.diskDirectory = diskDirectory
        self.diskVersion = diskVersion
        self.memoryLimit = max(1, memoryLimit)
        self.maxConcurrentRenders = max(1, maxConcurrentRenders)
        self.timeout = timeout
        self.render = render
    }

    /// A cache that renders with `renderer`.
    public init(renderer: ShaderPreviewRenderer,
                            diskDirectory: URL? = nil,
                            diskVersion: String = "1",
                            memoryLimit: Int = ShaderPreviewCache.defaultMemoryLimit,
                            maxConcurrentRenders: Int = ShaderPreviewCache.defaultMaxConcurrentRenders,
                            timeout: Duration = ShaderPreviewCache.defaultTimeout) {
        self.init(diskDirectory: diskDirectory, diskVersion: diskVersion, memoryLimit: memoryLimit,
                  maxConcurrentRenders: maxConcurrentRenders, timeout: timeout) { entry, source, size, parameterValue in
            try await renderer.render(entry: entry, source: source, size: size, parameterValue: parameterValue)
        }
    }

    // MARK: - Requests

    /// The preview image, from cache when possible. Returns `nil` when rendering
    /// failed, took longer than the timeout, or the calling task was cancelled
    /// before the render started.
    public func preview(for entry: ShaderCatalogEntry,
                        source: ShaderPreviewSource,
                        size: CGSize,
                        parameterValue: @escaping @Sendable (ShaderParameterDescriptor) -> Float) async -> CGImage? {
        let key = ShaderPreviewKey(entry: entry, source: source, size: size, parameterValue: parameterValue)
        if let hit = cachedImage(for: key) { return hit }
        if let stored = await readFromDisk(key) {
            remember(stored, for: key)
            return stored
        }
        guard !Task.isCancelled else { return nil }

        let caller = UUID()
        if flights[key] == nil {
            flights[key] = makeFlight(key: key, entry: entry, source: source, size: size, parameterValue: parameterValue)
        }
        flights[key]?.waiters.insert(caller)
        guard let outcome = flights[key]?.outcome else { return nil }
        return await withTaskCancellationHandler {
            await outcome.value
        } onCancel: {
            Task { await self.leave(key, caller: caller) }
        }
    }

    /// The in-memory image for `key`, if present, marking it recently used.
    public func cachedImage(for key: ShaderPreviewKey) -> CGImage? {
        guard let image = images[key] else { return nil }
        touch(key)
        return image
    }

    /// Drops every cached image, in memory and on disk. Renders in progress still finish.
    public func removeAll() {
        images.removeAll()
        usage.removeAll()
        if let diskDirectory {
            try? FileManager.default.removeItem(at: diskDirectory)
        }
    }

    // MARK: - Flights

    private func makeFlight(key: ShaderPreviewKey,
                            entry: ShaderCatalogEntry,
                            source: ShaderPreviewSource,
                            size: CGSize,
                            parameterValue: @escaping @Sendable (ShaderParameterDescriptor) -> Float) -> Flight {
        let outcome = Task { () -> CGImage? in
            guard await acquireSlot(for: key) else { return nil }
            let work = Task { () -> CGImage? in
                let image = await renderAndStore(key: key, entry: entry, source: source, size: size,
                                                 parameterValue: parameterValue)
                flights[key] = nil
                releaseSlot()
                return image
            }
            return await Self.firstResult(of: work, timeout: timeout)
        }
        return Flight(outcome: outcome, waiters: [])
    }

    private func renderAndStore(key: ShaderPreviewKey,
                                entry: ShaderCatalogEntry,
                                source: ShaderPreviewSource,
                                size: CGSize,
                                parameterValue: @Sendable (ShaderParameterDescriptor) -> Float) async -> CGImage? {
        do {
            let image = try await render(entry, source, size, parameterValue)
            remember(image, for: key)
            await writeToDisk(image, for: key)
            return image
        } catch {
            WLOG("Shader preview: \(key.shader) failed to render: \(error)")
            return nil
        }
    }

    /// A caller stopped waiting. When none are left and the render has not started, it never will.
    private func leave(_ key: ShaderPreviewKey, caller: UUID) {
        guard var flight = flights[key] else { return }
        flight.waiters.remove(caller)
        flights[key] = flight
        guard flight.waiters.isEmpty, !flight.started,
              let index = slotQueue.firstIndex(where: { $0.key == key }) else { return }
        flights[key] = nil
        slotQueue.remove(at: index).continuation.resume(returning: false)
    }

    // MARK: - Render slots

    /// Waits for a free render slot. `false` means every caller left while queued.
    private func acquireSlot(for key: ShaderPreviewKey) async -> Bool {
        if activeRenders < maxConcurrentRenders {
            return grantSlot(to: key)
        }
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            slotQueue.append(SlotRequest(key: key, continuation: continuation))
        }
        return granted
    }

    private func grantSlot(to key: ShaderPreviewKey) -> Bool {
        guard flights[key]?.waiters.isEmpty == false else {
            flights[key] = nil
            return false
        }
        flights[key]?.started = true
        activeRenders += 1
        return true
    }

    private func releaseSlot() {
        activeRenders -= 1
        while !slotQueue.isEmpty, activeRenders < maxConcurrentRenders {
            let next = slotQueue.removeFirst()
            next.continuation.resume(returning: grantSlot(to: next.key))
        }
    }

    // MARK: - Memory tier

    private func remember(_ image: CGImage, for key: ShaderPreviewKey) {
        images[key] = image
        touch(key)
        while usage.count > memoryLimit {
            images[usage.removeFirst()] = nil
        }
    }

    private func touch(_ key: ShaderPreviewKey) {
        if let index = usage.firstIndex(of: key) { usage.remove(at: index) }
        usage.append(key)
    }

    // MARK: - Disk tier

    private func fileURL(for key: ShaderPreviewKey) -> URL? {
        guard let diskDirectory, !key.isGameFrame else { return nil }
        return diskDirectory.appendingPathComponent(key.fileStem(version: diskVersion)).appendingPathExtension("png")
    }

    private func readFromDisk(_ key: ShaderPreviewKey) async -> CGImage? {
        guard let url = fileURL(for: key) else { return nil }
        return await Task.detached(priority: .utility) { Self.readPNG(at: url) }.value
    }

    private func writeToDisk(_ image: CGImage, for key: ShaderPreviewKey) async {
        guard let url = fileURL(for: key) else { return }
        await Task.detached(priority: .utility) { Self.writePNG(image, to: url) }.value
    }

    private nonisolated static func readPNG(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private nonisolated static func writePNG(_ image: CGImage, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString,
                                                                    1, nil) else { return }
            CGImageDestinationAddImage(destination, image, nil)
            if !CGImageDestinationFinalize(destination) {
                WLOG("Shader preview: could not encode \(url.lastPathComponent)")
            }
        } catch {
            WLOG("Shader preview: could not write \(url.lastPathComponent): \(error)")
        }
    }

    // MARK: - Timeout

    /// Resolves with `task`'s result, or `nil` once `timeout` has passed, whichever
    /// comes first. Unlike a task group this returns while `task` is still running,
    /// and it leaves `task` running.
    private nonisolated static func firstResult(of task: Task<CGImage?, Never>, timeout: Duration) async -> CGImage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CGImage?, Never>) in
            let once = OneShot(continuation)
            let timer = Task {
                try? await Task.sleep(for: timeout)
                once.resume(nil)
            }
            Task {
                let image = await task.value
                timer.cancel()
                once.resume(image)
            }
        }
    }
}

/// Resumes a continuation at most once, from any thread.
private final class OneShot<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Value) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
