//
//  PVHostedWebServer+Dashboard.swift
//  PVWebServerHost
//
//  The file-manager page's live parts: `/stats`, the `/events` stream and `/qr.png`.
//

import Foundation
import PVWebServer
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS) && canImport(AppKit)
import AppKit
#endif
#if canImport(CoreImage)
import CoreImage
#endif

// MARK: - Routes

extension PVHostedWebServer {

    private static let eventKeepAliveNanoseconds: UInt64 = 15_000_000_000
    private static let qrPixelsPerModule: CGFloat = 8

    func registerDashboardRoutes() {
        route("GET", "/stats") { server, _ in Self.json(server.dashboardStats()) }
        route("GET", "/events") { server, _ in server.eventStream() }
        route("GET", "/qr.png") { server, request in
            let text = request.query["text"] ?? server.serverURL?.absoluteString ?? "http://provenance.local/"
            guard let png = Self.qrCodePNG(text: text, scale: Self.qrPixelsPerModule) else {
                return .error(status: 500, message: "QR generation unavailable")
            }
            return WebRouteResponse(status: 200, contentType: "image/png", body: .data(png))
        }
    }

    /// Browsers connect with `new EventSource('/events')`. The keep-alive also finds clients
    /// that left without a word, since only a failed write reveals them.
    private func eventStream() -> WebRouteResponse {
        let hub = events
        return WebRouteResponse(
            status: 200,
            contentType: "text/event-stream; charset=utf-8",
            headers: ["Cache-Control": "no-cache, no-transform"],
            body: .stream { writer in
                let subscription = hub.subscribe()
                defer { hub.unsubscribe(subscription.id) }
                let keepAlive = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: Self.eventKeepAliveNanoseconds)
                        if !Task.isCancelled { subscription.send(Data(": ping\n\n".utf8)) }
                    }
                }
                defer { keepAlive.cancel() }

                let greeting = "retry: 5000\n\nevent: hello\ndata: {\"ok\":true}\n\n"
                guard await writer.write(Data(greeting.utf8)) else { return }
                for await frame in subscription.frames {
                    guard await writer.write(frame) else { return }
                }
            }
        )
    }

    /// Sends a file event to every open page. `path` is absolute; the page compares the
    /// browse-relative form against its current folder to decide whether to refresh.
    func broadcast(type: String, path: String, extra: [String: String] = [:]) {
        var payload = ["type": type, "path": relativeBrowsePath(for: path), "name": (path as NSString).lastPathComponent]
        payload.merge(extra) { _, new in new }
        let json = (try? JSONSerialization.data(withJSONObject: payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        events.broadcast(Data("event: \(type)\ndata: \(json)\n\n".utf8))
    }

    func relativeBrowsePath(for path: String) -> String {
        let root = browseRoot.standardized.path
        if path == root { return "" }
        return path.hasPrefix(root + "/") ? String(path.dropFirst(root.count + 1)) : path
    }
}

// MARK: - Stats

private extension PVHostedWebServer {

    /// The folders the page's Quick Access tabs show, in the same order.
    static let quickAccessFolders = ["Imports", "ROMs", "BIOS", "Save States", "Screenshots", "Cheats"]

    func dashboardStats() -> [String: Any] {
        let directories = Self.quickAccessFolders.map { folder -> [String: Any] in
            let (count, size) = Self.recursiveFileStats(at: browseRoot.appendingPathComponent(folder))
            return ["name": folder, "path": folder, "fileCount": count, "sizeBytes": size]
        }
        let disk = try? FileManager.default.attributesOfFileSystem(forPath: browseRoot.path)
        let totalDisk = (disk?[.systemSize] as? NSNumber)?.int64Value ?? 0
        let freeDisk = (disk?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        let port = boundPort ?? PVWebServerPorts.upload
        let url = serverURL?.absoluteString ?? ""
        return [
            "appVersion": (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?",
            "buildNumber": (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?",
            "hostname": ProcessInfo.processInfo.hostName,
            "ipAddress": engine.ipAddress ?? "",
            "httpPort": port,
            "webDAVPort": port,
            "serverURL": url,
            "webDAVURL": url,
            "uptimeSeconds": Int(Date().timeIntervalSince(startedAt)),
            "totalDiskBytes": totalDisk,
            "freeDiskBytes": freeDisk,
            "usedDiskBytes": max(totalDisk - freeDisk, 0),
            "directories": directories
        ]
    }

    /// Symlinks are not followed and hidden files are skipped.
    static func recursiveFileStats(at url: URL) -> (count: Int, size: Int64) {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard FileManager.default.fileExists(atPath: url.path),
              let files = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else {
            return (0, 0)
        }
        var count = 0
        var size: Int64 = 0
        for case let file as URL in files {
            let values = try? file.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                count += 1
                size += Int64(values?.fileSize ?? 0)
            }
        }
        return (count, size)
    }
}

// MARK: - QR code

private extension PVHostedWebServer {

    #if canImport(CoreImage) && (canImport(UIKit) || canImport(AppKit))
    static func qrCodeImage(text: String, scale: CGFloat) -> CIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        return filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
    #endif

    #if canImport(CoreImage) && canImport(UIKit)
    static func qrCodePNG(text: String, scale: CGFloat) -> Data? {
        guard let image = qrCodeImage(text: text, scale: scale),
              let bitmap = CIContext(options: [.useSoftwareRenderer: true]).createCGImage(image, from: image.extent) else {
            return nil
        }
        return UIImage(cgImage: bitmap).pngData()
    }
    #elseif canImport(CoreImage) && canImport(AppKit)
    static func qrCodePNG(text: String, scale: CGFloat) -> Data? {
        guard let image = qrCodeImage(text: text, scale: scale) else { return nil }
        return NSBitmapImageRep(ciImage: image).representation(using: .png, properties: [:])
    }
    #else
    static func qrCodePNG(text: String, scale: CGFloat) -> Data? { nil }
    #endif
}

// MARK: - Event hub

/// Hands each event to every open `/events` stream. A slow client drops old events rather
/// than growing a queue, which at worst costs it one listing refresh.
final class WebEventHub: @unchecked Sendable {
    struct Subscription {
        let id: UUID
        let frames: AsyncStream<Data>
        let send: @Sendable (Data) -> Void
    }

    private static let framesKeptPerClient = 64

    private let lock = NSLock()
    private var subscribers: [UUID: AsyncStream<Data>.Continuation] = [:]

    func subscribe() -> Subscription {
        let (frames, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(Self.framesKeptPerClient))
        let id = UUID()
        lock.withLock { subscribers[id] = continuation }
        return Subscription(id: id, frames: frames, send: { continuation.yield($0) })
    }

    func unsubscribe(_ id: UUID) {
        lock.withLock { subscribers.removeValue(forKey: id) }?.finish()
    }

    func broadcast(_ frame: Data) {
        lock.withLock { Array(subscribers.values) }.forEach { $0.yield(frame) }
    }

    /// Ends every stream, for when the server stops.
    func finishAll() {
        let ended = lock.withLock {
            defer { subscribers.removeAll() }
            return Array(subscribers.values)
        }
        ended.forEach { $0.finish() }
    }

    var subscriberCount: Int { lock.withLock { subscribers.count } }
}
