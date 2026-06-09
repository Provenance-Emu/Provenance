//
//  PVModernWebServer.swift
//  PVWebServer
//
//  Created by Agent on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Swift-native HTTP/WebDAV server built on Hummingbird 2 + Swift NIO.
//  Replaces the vendored 2015 ObjC GCDWebServer when the `modernWebServer`
//  feature flag is enabled.
//
//  Phase 1 (this PR) — Epic #2758, Task A #2760:
//    • Basic HTTP file listing + single-file upload (POST /upload)
//    • WebDAV stub (PROPFIND/PUT/DELETE route placeholders)
//    • Fires the same PVWebServer*Notification constants as the legacy server
//    • Bonjour advertisement via Network.framework
//
//  Phase 2 follow-ups:
//    • Full WebDAV (Task A)
//    • Delete/Move → Realm (Task B #2759)
//    • Upload routing to Imports/ (Task C #2761)
//    • Modern web UI with SSE progress (Task D #2762)
//

import Foundation
import HTTPTypes
import Network
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS) && canImport(AppKit)
import AppKit
#endif
#if canImport(CoreImage)
import CoreImage
#endif
import Hummingbird
import PVLogging
import PVPrimitives

// MARK: - PVModernWebServer

/// Swift-native HTTP + WebDAV server using Hummingbird 2 / Swift NIO.
/// Conforms to `PVWebServerProtocol` so `PVWebServerManager` can swap it
/// for the legacy adapter without changing any call sites.
// FIXME: @unchecked Sendable — mutable state (_isHTTPRunning, httpServerTask, cachedIPAddress,
// netService) can be accessed from multiple concurrent contexts if callers bypass
// PVWebServerManager. Phase 2 should convert this to an `actor` or confine all
// mutation behind a single executor. Until then, callers must route all access
// through the PVWebServerManager actor which serialises calls.
public final class PVModernWebServer: @unchecked Sendable {

    // MARK: Configuration

    /// HTTP file-uploader port (80 on-device, 8080 in simulator / Catalyst).
    public let httpPort: Int
    /// WebDAV port (81 on-device, 8081 in simulator / Catalyst).
    public let webDAVPort: Int
    /// Default destination for `POST /upload` when no `path` query parameter
    /// is supplied. Defaults to `<browseRoot>/Imports`.
    public let uploadDirectory: URL
    /// Root folder that the HTTP browser is allowed to navigate. All `path`
    /// query parameters are resolved relative to this URL. Defaults to the
    /// Documents directory on iOS / macOS and Caches on tvOS (where Documents
    /// is unwritable). Matches GCDWebUploader's behaviour.
    public let browseRoot: URL

    // MARK: State

    private var httpServerTask: Task<Void, Error>?
    private var webDAVServerTask: Task<Void, Error>?
    private var netService: NetService?
    private var cachedIPAddress: String?
    /// Stamped on init so `/stats` can report process uptime to the dashboard.
    private let serverStartTime: Date = Date()
    /// Subscriber hub for the `GET /events` Server-Sent-Events stream.
    /// Mutating route handlers `sseBroadcast(...)` after every successful op
    /// so connected browsers refresh in real time without polling.
    private let sseHub = SSEHub()

    private var _isHTTPRunning: Bool = false
    private var _isWebDAVRunning: Bool = false

    // MARK: Init

    public init(uploadDirectory: URL? = nil,
                browseRoot: URL? = nil,
                httpPort: Int? = nil,
                webDAVPort: Int? = nil) {
        // Match the legacy GCDWebServer defaults: pretty 80/81 on real
        // hardware (iOS/tvOS device) so the URL is just `http://<ip>/`,
        // and 8080/8081 on Simulator + macOS Catalyst where binding
        // privileged-style low ports causes friction with the host OS.
        let isSimulatorOrCatalyst: Bool = {
#if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
            return true
#else
            return false
#endif
        }()

        self.httpPort   = httpPort   ?? (isSimulatorOrCatalyst ? 8080 : 80)
        self.webDAVPort = webDAVPort ?? (isSimulatorOrCatalyst ? 8081 : 81)

        let resolvedBrowseRoot: URL = {
            if let browseRoot { return browseRoot }
            let dir: FileManager.SearchPathDirectory
#if os(tvOS)
            dir = .cachesDirectory
#else
            dir = .documentDirectory
#endif
            return FileManager.default.urls(for: dir, in: .userDomainMask)[0]
        }()
        self.browseRoot = resolvedBrowseRoot

        self.uploadDirectory = uploadDirectory ?? resolvedBrowseRoot.appendingPathComponent("Imports")

        // Ensure upload directory exists
        try? FileManager.default.createDirectory(at: self.uploadDirectory,
                                                  withIntermediateDirectories: true)
    }
}

// MARK: - PVWebServerProtocol

extension PVModernWebServer: PVWebServerProtocol {

    public var isWWWServerRunning: Bool  { _isHTTPRunning }
    public var isWebDAVServerRunning: Bool { _isWebDAVRunning }

    public var serverURL: URL? {
        guard _isHTTPRunning, let ip = currentIPAddress() else { return nil }
        let portSuffix = httpPort == 80 ? "" : ":\(httpPort)"
        return URL(string: "http://\(ip)\(portSuffix)/")
    }

    public var webDAVURL: URL? {
        guard _isWebDAVRunning, let ip = currentIPAddress() else { return nil }
        return URL(string: "http://\(ip):\(webDAVPort)/")
    }

    @discardableResult
    public func startServers() async throws -> Bool {
        async let httpOK = startHTTPServer()
        async let davOK = startWebDAVServer()
        let results: (Bool, Bool)
        do {
            results = try await (httpOK, davOK)
        } catch {
            await stopServers()
            throw error
        }

        guard results.0 && results.1 else {
            await stopServers()
            WLOG("[PVModernWebServer] start aborted (HTTP ok: \(results.0), WebDAV ok: \(results.1)); listeners torn down.")
            return false
        }

        startBonjourAdvertisement()

        postStatusNotification(isRunning: true, type: "WebUploader", port: httpPort, url: serverURL)
        postStatusNotification(isRunning: true, type: "WebDAV", port: webDAVPort, url: webDAVURL)

#if canImport(UIKit) && !os(watchOS)
        /// Use the main GCD queue instead of `MainActor.run` so `@MainActor` callers awaiting `PVWebServerManager.start()` cannot deadlock with this type’s isolation.
        await setIdleTimerDisabledOnMainQueue(true)
#endif
        return true
    }

    public func stopServers() async {
        httpServerTask?.cancel()
        webDAVServerTask?.cancel()
        httpServerTask = nil
        webDAVServerTask = nil
        netService?.stop()
        netService = nil
        _isHTTPRunning = false
        _isWebDAVRunning = false

        postStatusNotification(isRunning: false, type: "WebUploader", port: httpPort, url: nil)
        postStatusNotification(isRunning: false, type: "WebDAV", port: webDAVPort, url: nil)

#if canImport(UIKit) && !os(watchOS)
        await setIdleTimerDisabledOnMainQueue(false)
#endif
    }
}

// MARK: - HTTP Server

private extension PVModernWebServer {

#if canImport(UIKit) && !os(watchOS)
    /// UIKit idle-timer updates must run on the main thread; use GCD async instead of `MainActor.run` to avoid the same
    /// `@MainActor` / `PVWebServerManager.start()` ordering deadlock as the legacy server path.
    func setIdleTimerDisabledOnMainQueue(_ disabled: Bool) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = disabled
                continuation.resume()
            }
        }
    }
#endif

    func startHTTPServer() async throws -> Bool {
        return try await spawnAndConfirmBind(
            label: "HTTP",
            port: self.httpPort,
            router: buildHTTPRouter(),
            taskAssign: { [weak self] task in self?.httpServerTask = task },
            runningFlag: { [weak self] running in self?._isHTTPRunning = running }
        )
    }

    func buildHTTPRouter() -> Router<BasicRequestContext> {
        let router = Router()
        let browse = self.browseRoot
        let defaultUploadSubpath = self.uploadDirectory
            .path
            .replacingOccurrences(of: browse.path, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // GET / — serve built-in file-manager HTML
        router.get("/") { _, _ -> Response in
            let html = PVModernWebServer.fileManagerHTML(defaultUploadPath: defaultUploadSubpath)
            return Response(
                status: .ok,
                headers: [.contentType: "text/html; charset=utf-8"],
                body: .init(byteBuffer: ByteBuffer(string: html))
            )
        }

        // GET /files?path=Foo/Bar — JSON listing of a subdirectory
        // Returns: { "path": "Foo/Bar", "items": [{ name, size, modified, isDirectory }] }
        router.get("/files") { [weak self] request, _ -> Response in
            let rawPath = Self.queryParameter("path", from: request) ?? ""
            guard let self,
                  let target = self.resolvedPath(rawPath, withinDirectory: browse) else {
                return Self.jsonError(status: .forbidden, message: "Path escapes root")
            }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDir), isDir.boolValue else {
                return Self.jsonError(status: .notFound, message: "Not a directory")
            }
            let listing = (try? FileManager.default.contentsOfDirectory(
                at: target,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
            )) ?? []
            let items = listing
                .filter { !$0.lastPathComponent.hasPrefix(".") }
                .map { url -> [String: Any] in
                    let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                    let isDirectory = attrs?.isDirectory ?? false
                    return [
                        "name": url.lastPathComponent,
                        "size": isDirectory ? 0 : (attrs?.fileSize ?? 0),
                        "modified": attrs?.contentModificationDate.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                        "isDirectory": isDirectory
                    ]
                }
                .sorted { lhs, rhs in
                    // Directories first, then alphabetical (case-insensitive).
                    let lhsDir = (lhs["isDirectory"] as? Bool) ?? false
                    let rhsDir = (rhs["isDirectory"] as? Bool) ?? false
                    if lhsDir != rhsDir { return lhsDir && !rhsDir }
                    let lhsName = (lhs["name"] as? String) ?? ""
                    let rhsName = (rhs["name"] as? String) ?? ""
                    return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
                }
            let payload: [String: Any] = ["path": rawPath, "items": items]
            let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: ByteBuffer(bytes: data))
            )
        }

        // POST /upload?path=Foo/Bar — multipart upload routed to <browseRoot>/<path>
        router.post("/upload") { [weak self] request, context -> Response in
            guard let self else {
                return Response(status: .internalServerError)
            }
            let rawPath = Self.queryParameter("path", from: request) ?? defaultUploadSubpath
            guard let dest = self.resolvedPath(rawPath, withinDirectory: browse) else {
                return Self.jsonError(status: .forbidden, message: "Upload path escapes root")
            }
            try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            return try await self.handleUpload(request: request, context: context, uploadDirectory: dest)
        }

        // GET /download?path=Foo/Bar/file.bin — file download
        // FIXME (Phase 2): buffers entire file; replace with streaming response.
        router.get("/download") { [weak self] request, _ -> Response in
            let rawPath = Self.queryParameter("path", from: request) ?? ""
            guard let self,
                  !rawPath.isEmpty,
                  let target = self.resolvedPath(rawPath, withinDirectory: browse),
                  let data = try? Data(contentsOf: target) else {
                return Response(status: .notFound)
            }
            let filename = target.lastPathComponent
            let dispositionField: HTTPField.Name? = HTTPField.Name("Content-Disposition")
            var headers: HTTPFields = [.contentType: "application/octet-stream"]
            if let dispositionField {
                headers[dispositionField] = "attachment; filename=\"\(filename.replacingOccurrences(of: "\"", with: ""))\""
            }
            return Response(
                status: .ok,
                headers: headers,
                body: .init(byteBuffer: ByteBuffer(bytes: data))
            )
        }

        // POST /folders — body { "path": "<parent>", "name": "<newdir>" }
        router.post("/folders") { [weak self] request, _ -> Response in
            guard let self else { return Response(status: .internalServerError) }
            let body = try await request.body.collect(upTo: 64 * 1024)
            let data = body.withUnsafeReadableBytes { ptr in Data(ptr) }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = (json["name"] as? String)?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty,
                  !name.contains("/"),
                  !name.hasPrefix(".") else {
                return Self.jsonError(status: .badRequest, message: "Invalid folder name")
            }
            let parentRaw = (json["path"] as? String) ?? ""
            guard let parent = self.resolvedPath(parentRaw, withinDirectory: browse),
                  let target = self.resolvedPath((parentRaw as NSString).appendingPathComponent(name), withinDirectory: browse) else {
                return Self.jsonError(status: .forbidden, message: "Path escapes root")
            }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDir), isDir.boolValue else {
                return Self.jsonError(status: .notFound, message: "Parent not found")
            }
            do {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
                self.sseBroadcast(type: "folder", path: target.path)
                return Response(status: .created)
            } catch {
                return Self.jsonError(status: .conflict, message: "Already exists or unwritable")
            }
        }

        // PATCH /files — body { "from": "<path>", "to": "<path>" }  rename / move
        guard let patchMethod = HTTPRequest.Method("PATCH") else {
            preconditionFailure("PATCH must be a valid HTTP method token")
        }
        router.on("/files", method: patchMethod) { [weak self] request, _ -> Response in
            guard let self else { return Response(status: .internalServerError) }
            let body = try await request.body.collect(upTo: 64 * 1024)
            let data = body.withUnsafeReadableBytes { ptr in Data(ptr) }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let from = json["from"] as? String, !from.isEmpty,
                  let to   = json["to"]   as? String, !to.isEmpty,
                  let src  = self.resolvedPath(from, withinDirectory: browse),
                  let dst  = self.resolvedPath(to,   withinDirectory: browse) else {
                return Self.jsonError(status: .badRequest, message: "Invalid move payload")
            }
            try? FileManager.default.createDirectory(at: dst.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            do {
                try FileManager.default.moveItem(at: src, to: dst)
                NotificationCenter.default.post(
                    name: .pvWebServerFileMoved,
                    object: self,
                    userInfo: ["fromPath": src.path, "toPath": dst.path]
                )
                self.sseBroadcast(
                    type: "rename",
                    path: dst.path,
                    extra: ["from": self.relativeBrowsePath(for: src.path)]
                )
                return Response(status: .noContent)
            } catch {
                return Self.jsonError(status: .conflict, message: "Move failed")
            }
        }

        // DELETE /files?path=Foo/Bar — delete a file or directory (recursive)
        router.delete("/files") { [weak self] request, _ -> Response in
            let rawPath = Self.queryParameter("path", from: request) ?? ""
            guard let self,
                  !rawPath.isEmpty,
                  let target = self.resolvedPath(rawPath, withinDirectory: browse),
                  target.standardized.path != browse.standardized.path else {
                return Self.jsonError(status: .forbidden, message: "Refusing to delete root")
            }
            do {
                try FileManager.default.removeItem(at: target)
                NotificationCenter.default.post(
                    name: .pvWebServerFileDeleted,
                    object: self,
                    userInfo: ["filePath": target.path]
                )
                self.sseBroadcast(type: "delete", path: target.path)
                return Response(status: .noContent)
            } catch {
                return Self.jsonError(status: .notFound, message: "Delete failed")
            }
        }

        // POST /files/batch-delete — body { "paths": ["Imports/a.zip", ...] }
        // Deletes each path with the same safety rules as single delete.
        // Response: { "deleted": N, "failed": [{ path, error }] }
        router.post("/files/batch-delete") { [weak self] request, _ -> Response in
            guard let self else { return Response(status: .internalServerError) }
            let body = try await request.body.collect(upTo: 128 * 1024)
            let data = body.withUnsafeReadableBytes { ptr in Data(ptr) }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let paths = json["paths"] as? [String], !paths.isEmpty else {
                return Self.jsonError(status: .badRequest, message: "Missing paths array")
            }
            var deleted = 0
            var failed: [[String: String]] = []
            for raw in paths {
                guard !raw.isEmpty,
                      let target = self.resolvedPath(raw, withinDirectory: browse),
                      target.standardized.path != browse.standardized.path else {
                    failed.append(["path": raw, "error": "forbidden"])
                    continue
                }
                do {
                    try FileManager.default.removeItem(at: target)
                    deleted += 1
                    NotificationCenter.default.post(
                        name: .pvWebServerFileDeleted,
                        object: self,
                        userInfo: ["filePath": target.path]
                    )
                    self.sseBroadcast(type: "delete", path: target.path)
                } catch {
                    failed.append(["path": raw, "error": error.localizedDescription])
                }
            }
            let payload: [String: Any] = ["deleted": deleted, "failed": failed]
            let respData = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: ByteBuffer(bytes: respData))
            )
        }

        // GET /stats — JSON dashboard payload for the file-manager UI.
        router.get("/stats") { [weak self] _, _ -> Response in
            guard let self else { return Response(status: .internalServerError) }
            let payload = self.computeDashboardStats(browseRoot: browse)
            let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: ByteBuffer(bytes: data))
            )
        }

        // GET /events — Server-Sent Events stream of file activity.
        // Browsers connect via `new EventSource('/events')`; each mutating
        // route below broadcasts a typed event after its filesystem op
        // succeeds so every connected client refreshes in real time.
        router.get("/events") { [weak self] _, _ -> Response in
            guard let self else { return Response(status: .internalServerError) }
            let hub = self.sseHub
            let body = ResponseBody { writer in
                let (stream, continuation) = AsyncStream<ByteBuffer>.makeStream(bufferingPolicy: .bufferingNewest(64))
                let id = hub.subscribe(continuation)

                // Initial preamble: hint reconnect delay + a hello event.
                try await writer.write(ByteBuffer(string: "retry: 5000\n\n"))
                try await writer.write(ByteBuffer(string:
                    "event: hello\ndata: {\"ok\":true}\n\n"))

                // Periodic keep-alive so middleboxes don't reap the connection.
                let keepAlive = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 15_000_000_000)
                        if Task.isCancelled { break }
                        continuation.yield(ByteBuffer(string: ": ping\n\n"))
                    }
                }

                do {
                    for await chunk in stream {
                        try await writer.write(chunk)
                    }
                } catch {
                    // Client disconnected (writer.write threw) — fall through to cleanup.
                }
                keepAlive.cancel()
                hub.unsubscribe(id)
                try? await writer.finish(nil)
            }
            var headers: HTTPFields = [
                .contentType: "text/event-stream; charset=utf-8",
                .cacheControl: "no-cache, no-transform"
            ]
            if let connectionHeader = HTTPField.Name("Connection") {
                headers[connectionHeader] = "keep-alive"
            }
            return Response(status: .ok, headers: headers, body: body)
        }

        // GET /qr.png?text=... — PNG QR code for the server URL.
        // Defaults to the current serverURL so the dashboard can `<img src="/qr.png">`.
        router.get("/qr.png") { [weak self] request, _ -> Response in
            guard let self else { return Response(status: .internalServerError) }
            let text = Self.queryParameter("text", from: request)
                ?? self.serverURL?.absoluteString
                ?? "http://provenance.local/"
            guard let png = self.generateQRCodePNG(text: text, scale: 8) else {
                return Self.jsonError(status: .internalServerError, message: "QR generation unavailable")
            }
            return Response(
                status: .ok,
                headers: [.contentType: "image/png"],
                body: .init(byteBuffer: ByteBuffer(bytes: png))
            )
        }

        return router
    }

    // MARK: - SSE broadcast

    /// Broadcasts a typed file event to every connected `/events` subscriber.
    /// `type` examples: "upload", "delete", "rename", "folder". `path` is the
    /// resolved on-disk path; the JS client compares it against its current
    /// directory to decide whether to refresh the visible listing.
    func sseBroadcast(type: String, path: String, extra: [String: String] = [:]) {
        let relPath = relativeBrowsePath(for: path)
        var payload: [String: String] = [
            "type": type,
            "path": relPath,
            "name": (path as NSString).lastPathComponent
        ]
        for (k, v) in extra { payload[k] = v }
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        let dataString = String(data: data, encoding: .utf8) ?? "{}"
        let frame = "event: \(type)\ndata: \(dataString)\n\n"
        if let bytes = frame.data(using: .utf8) {
            sseHub.broadcast(ByteBuffer(bytes: bytes))
        }
    }

    /// Strips the browseRoot prefix from a fully-resolved disk path so the
    /// SSE event carries the same UI-relative path the rest of the API uses.
    func relativeBrowsePath(for fullPath: String) -> String {
        let basePath = browseRoot.standardized.path
        if fullPath.hasPrefix(basePath + "/") {
            return String(fullPath.dropFirst(basePath.count + 1))
        }
        if fullPath == basePath { return "" }
        return fullPath
    }

    // MARK: - Dashboard stats

    /// Builds the JSON payload returned by `GET /stats`. Lives next to the
    /// router so all the path lookups stay co-located with the routes that
    /// expose them.
    func computeDashboardStats(browseRoot: URL) -> [String: Any] {
        // Quick-access subdirectories the dashboard highlights — same order
        // as the UI's Quick Access tabs.
        let quickAccess: [(name: String, sub: String)] = [
            ("Imports",     "Imports"),
            ("ROMs",        "ROMs"),
            ("BIOS",        "BIOS"),
            ("Save States", "Save States"),
            ("Screenshots", "Screenshots"),
            ("Cheats",      "Cheats")
        ]
        let directories = quickAccess.map { entry -> [String: Any] in
            let url = browseRoot.appendingPathComponent(entry.sub)
            let (count, size) = Self.recursiveFileStats(at: url)
            return [
                "name": entry.name,
                "path": entry.sub,
                "fileCount": count,
                "sizeBytes": size
            ]
        }

        var totalDisk: Int64 = 0
        var freeDisk: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: browseRoot.path) {
            totalDisk = (attrs[.systemSize]     as? NSNumber)?.int64Value ?? 0
            freeDisk  = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        }
        let usedDisk = max(totalDisk - freeDisk, 0)

        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let buildNumber = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        let uptime = Date().timeIntervalSince(serverStartTime)
        let hostname = ProcessInfo.processInfo.hostName

        return [
            "appVersion":      appVersion,
            "buildNumber":     buildNumber,
            "hostname":        hostname,
            "ipAddress":       currentIPAddress() ?? "",
            "httpPort":        httpPort,
            "webDAVPort":      webDAVPort,
            "serverURL":       serverURL?.absoluteString ?? "",
            "webDAVURL":       webDAVURL?.absoluteString ?? "",
            "uptimeSeconds":   Int(uptime),
            "totalDiskBytes":  totalDisk,
            "freeDiskBytes":   freeDisk,
            "usedDiskBytes":   usedDisk,
            "directories":     directories
        ]
    }

    /// Recursively walks `url`, returning (fileCount, totalSizeBytes).
    /// Symlinks are NOT followed; hidden files are skipped.
    static func recursiveFileStats(at url: URL) -> (count: Int, size: Int64) {
        guard FileManager.default.fileExists(atPath: url.path) else { return (0, 0) }
        var count = 0
        var size: Int64 = 0
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return (0, 0)
        }
        for case let file as URL in enumerator {
            let attrs = try? file.resourceValues(forKeys: Set(keys))
            if attrs?.isRegularFile == true {
                count += 1
                size += Int64(attrs?.fileSize ?? 0)
            }
        }
        return (count, size)
    }

    // MARK: - QR code

#if canImport(CoreImage) && canImport(UIKit)
    /// CoreImage-backed QR generator. Returns PNG bytes for a 1-bit QR
    /// scaled up by `scale` pixels per module. Returns nil if CIFilter
    /// fails or the bitmap conversion drops the image.
    func generateQRCodePNG(text: String, scale: CGFloat) -> Data? {
        guard let data = text.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let raw = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaled = raw.transformed(by: transform)
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        let image = UIImage(cgImage: cg)
        return image.pngData()
    }
#elseif canImport(CoreImage) && canImport(AppKit)
    func generateQRCodePNG(text: String, scale: CGFloat) -> Data? {
        guard let data = text.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let raw = filter.outputImage else { return nil }
        let scaled = raw.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
#else
    func generateQRCodePNG(text: String, scale: CGFloat) -> Data? { nil }
#endif

    // MARK: - Router helpers

    /// Extract a single query-parameter value across Hummingbird URI shapes.
    static func queryParameter(_ name: String, from request: Request) -> String? {
        // Hummingbird exposes parsed query items via `request.uri.queryParameters`,
        // but the API surface differs slightly between Hummingbird 2 minor
        // versions. Fall back to a manual URLComponents parse so this works
        // regardless of the SPM-pinned version.
        if let value = request.uri.queryParameters[Substring(name)] {
            let decoded = String(value).removingPercentEncoding ?? String(value)
            return decoded.isEmpty ? nil : decoded
        }
        let uriString = String(describing: request.uri)
        guard
            let components = URLComponents(string: uriString.hasPrefix("http") ? uriString : "http://x" + uriString),
            let items = components.queryItems,
            let match = items.first(where: { $0.name == name })
        else {
            return nil
        }
        return match.value
    }

    static func jsonError(status: HTTPResponse.Status, message: String) -> Response {
        let payload: [String: Any] = ["error": message]
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        return Response(
            status: status,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(bytes: data))
        )
    }

    func handleUpload(
        request: Request,
        context: some RequestContext,
        uploadDirectory: URL
    ) async throws -> Response {
        guard let contentType = request.headers[.contentType] else {
            return Response(status: .unsupportedMediaType)
        }
        if exceedsMaxUploadContentLength(request) {
            return Self.jsonError(status: .contentTooLarge, message: "Upload exceeds maximum size")
        }

        if let streamed = try? await StreamingMultipartUpload.streamSingleFilePart(
            body: request.body,
            contentType: String(contentType),
            uploadDirectory: uploadDirectory,
            resolvePath: { [weak self] name, dir in
                self?.resolvedPath(name, withinDirectory: dir)
            },
            onStarted: { [weak self] destination, _ in
                guard let self else { return }
                NotificationCenter.default.post(
                    name: .pvWebServerFileUploadStarted,
                    object: self,
                    userInfo: ["path": destination.path, "fileSize": 0]
                )
            }
        ) {
            return completeUploadedFile(
                destination: streamed.destination,
                sanitizedName: streamed.sanitizedFilename,
                fileSize: Int(streamed.bytesWritten)
            )
        }

        return try await handleUploadBuffered(
            request: request,
            uploadDirectory: uploadDirectory,
            contentType: String(contentType)
        )
    }

    /// Fallback path: buffer up to 256 MB then parse multipart (legacy single-request compatibility).
    func handleUploadBuffered(
        request: Request,
        uploadDirectory: URL,
        contentType: String
    ) async throws -> Response {
        let body = try await request.body.collect(upTo: 256 * 1_024 * 1_024)
        guard let bodyData = body.withUnsafeReadableBytes({ ptr -> Data? in
            guard !ptr.isEmpty else { return nil }
            return Data(ptr)
        }) else {
            return Response(status: .badRequest)
        }

        guard let boundary = multipartBoundary(from: contentType) else {
            return Response(status: .unsupportedMediaType)
        }

        let parts = parseMultipart(data: bodyData, boundary: boundary)
        var savedFiles: [String] = []

        for part in parts {
            guard let filename = part.filename, !filename.isEmpty else { continue }
            let sanitizedName = URL(fileURLWithPath: filename).lastPathComponent
            guard !sanitizedName.isEmpty, !sanitizedName.hasPrefix(".") else { continue }
            guard let dest = resolvedPath(sanitizedName, withinDirectory: uploadDirectory) else { continue }

            let fileData = part.data
            let fileSize = fileData.count

            NotificationCenter.default.post(
                name: .pvWebServerFileUploadStarted,
                object: self,
                userInfo: ["path": dest.path, "fileSize": fileSize]
            )

            do {
                try fileData.write(to: dest)
                savedFiles.append(sanitizedName)
                postUploadCompletedNotifications(path: dest.path, fileSize: fileSize)
                sseBroadcast(
                    type: "upload",
                    path: dest.path,
                    extra: ["size": String(fileSize)]
                )
            } catch {
                NotificationCenter.default.post(
                    name: .pvWebServerFileUploadFailed,
                    object: self,
                    userInfo: ["filePath": dest.path, "error": error]
                )
            }
        }

        if savedFiles.isEmpty {
            return Response(status: .badRequest)
        }

        let responseBody: String
        if let jsonData = try? JSONSerialization.data(withJSONObject: ["uploaded": savedFiles.count]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            responseBody = jsonString
        } else {
            responseBody = "{\"uploaded\":\(savedFiles.count)}"
        }

        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(string: responseBody))
        )
    }

    func completeUploadedFile(destination: URL, sanitizedName: String, fileSize: Int) -> Response {
        postUploadCompletedNotifications(path: destination.path, fileSize: fileSize)
        sseBroadcast(
            type: "upload",
            path: destination.path,
            extra: ["size": String(fileSize)]
        )

        let responseBody: String
        if let jsonData = try? JSONSerialization.data(withJSONObject: ["uploaded": 1]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            responseBody = jsonString
        } else {
            responseBody = "{\"uploaded\":1}"
        }

        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(string: responseBody))
        )
    }

    func postUploadCompletedNotifications(path: String, fileSize: Int) {
        NotificationCenter.default.post(
            name: .pvWebServerFileUploadCompleted,
            object: self,
            userInfo: ["filePath": path, "fileSize": fileSize]
        )
        NotificationCenter.default.post(
            name: .pvWebServerUploadCompleted,
            object: self,
            userInfo: ["fileName": path, "fileSize": fileSize]
        )
    }

    func exceedsMaxUploadContentLength(_ request: Request) -> Bool {
        guard let lengthHeader = request.headers[.contentLength],
              let length = Int64(lengthHeader) else {
            return false
        }
        return length > WebServerIO.maxUploadBytes
    }

    /// Streams a raw HTTP body to `destination` using a serial disk writer (WebDAV PUT).
    func streamRequestBodyToFile(_ request: Request, destination: URL) async throws -> Int64 {
        let writer = try SerialFileWriter(destination: destination)
        var coalesced = Data()
        coalesced.reserveCapacity(WebServerIO.readChunkSize)

        for try await buffer in request.body {
            let chunk = buffer.withUnsafeReadableBytes { Data($0) }
            guard !chunk.isEmpty else { continue }
            coalesced.append(chunk)
            if coalesced.count >= WebServerIO.readChunkSize {
                await writer.append(coalesced)
                coalesced.removeAll(keepingCapacity: true)
            }
        }
        if !coalesced.isEmpty {
            await writer.append(coalesced)
        }
        return try await writer.finalize()
    }
}

// MARK: - WebDAV HTTP field/method constants
// Pre-validated at compile time — these are known RFC-compliant token strings.
// Defining them once at module scope avoids per-request force-unwraps and makes
// any future breakage visible immediately at startup rather than at request time.

/// Custom "DAV" WebDAV capability header. Valid HTTP token — init always succeeds.
private let kWebDAVFieldNameDAV: HTTPField.Name? = HTTPField.Name("DAV")
/// Standard "Allow" HTTP header. Valid HTTP token — init always succeeds.
private let kWebDAVFieldNameAllow: HTTPField.Name? = HTTPField.Name("Allow")
/// WebDAV `Destination` header for COPY/MOVE.
private let kWebDAVFieldNameDestination: HTTPField.Name? = HTTPField.Name("Destination")
/// WebDAV `Overwrite` header for COPY/MOVE.
private let kWebDAVFieldNameOverwrite: HTTPField.Name? = HTTPField.Name("Overwrite")

// MARK: - WebDAV Server

private extension PVModernWebServer {

    func startWebDAVServer() async throws -> Bool {
        // WebDAV exposes the full browse root so Finder etc. can navigate
        // ROMs / BIOS / Save States subdirectories, matching the HTTP UI.
        let dir = self.browseRoot
        return try await spawnAndConfirmBind(
            label: "WebDAV",
            port: self.webDAVPort,
            router: buildWebDAVRouter(uploadDirectory: dir),
            taskAssign: { [weak self] task in self?.webDAVServerTask = task },
            runningFlag: { [weak self] running in self?._isWebDAVRunning = running }
        )
    }

    /// Boot one Hummingbird Application and only return `true` once it has
    /// either signalled "bind succeeded" or the Task threw an early error.
    /// Previously both startHTTPServer / startWebDAVServer set their running
    /// flag optimistically before the NIO bind completed, so a port collision
    /// silently presented as "server running" with a URL that nothing was
    /// actually listening on.
    func spawnAndConfirmBind(
        label: String,
        port: Int,
        router: Router<BasicRequestContext>,
        taskAssign: @escaping (Task<Void, Error>) -> Void,
        runningFlag: @escaping (Bool) -> Void
    ) async throws -> Bool {
        let app = Application(
            router: router,
            server: .http1(configuration: .init(additionalChannelHandlers: TCPNoDelayChannelHandler.make())),
            configuration: .init(
                address: .hostname("0.0.0.0", port: port),
                serverName: "Provenance"
            )
        )

        // Track early failure via a shared box: the Hummingbird Task writes
        // any thrown error into it; the probe loop reads it each tick.
        // Swift's standard `Task` has no non-blocking "is it done?" API.
        let earlyError = EarlyErrorBox()
        let task = Task<Void, Error> {
            do {
                try await app.run()
            } catch {
                earlyError.set(error)
                throw error
            }
        }
        taskAssign(task)

        let probeDeadline = Date().addingTimeInterval(2.0)
        while Date() < probeDeadline {
            if let error = earlyError.get() {
                ELOG("[PVModernWebServer] \(label) bind failed on port \(port): \(error.localizedDescription)")
                runningFlag(false)
                return false
            }
            if probePort(port) {
                ILOG("[PVModernWebServer] \(label) bound on 0.0.0.0:\(port)")
                runningFlag(true)
                return true
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        WLOG("[PVModernWebServer] \(label) bind not confirmed within 2s on port \(port); aborting.")
        task.cancel()
        runningFlag(false)
        return false
    }

    /// Thread-safe box for surfacing an early Hummingbird Task error to the
    /// `spawnAndConfirmBind` probe loop without blocking on `task.value`.
    final class EarlyErrorBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Error?
        func set(_ error: Error) {
            lock.lock(); defer { lock.unlock() }
            stored = error
        }
        func get() -> Error? {
            lock.lock(); defer { lock.unlock() }
            return stored
        }
    }

    /// Cheap TCP-probe: returns true if a local connect to `127.0.0.1:port`
    /// succeeds. Used to confirm Hummingbird has actually bound before the
    /// manager reports the server as running.
    func probePort(_ port: Int) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, addrLen)
            }
        }
        return result == 0
    }

    func buildWebDAVRouter(uploadDirectory: URL) -> Router<BasicRequestContext> {
        let router = Router()

        // OPTIONS — advertise WebDAV class 1 support (anonymous/guest writes allowed)
        router.on("/**", method: .options) { _, _ -> Response in
            var headers = HTTPFields()
            if let dav = kWebDAVFieldNameDAV   { headers[dav]   = "1" }
            if let allow = kWebDAVFieldNameAllow {
                headers[allow] = "OPTIONS, GET, HEAD, PUT, DELETE, PROPFIND, MKCOL, COPY, MOVE"
            }
            return Response(status: .ok, headers: headers)
        }

        // PROPFIND — directory/file property listing (WebDAV class 1)
        // `HTTPRequest.Method(_:)` is failable for arbitrary strings; PROPFIND is a valid token.
        guard let propfindMethod = HTTPRequest.Method("PROPFIND") else {
            preconditionFailure("PROPFIND must be a valid HTTP method token")
        }
        router.on("/**", method: propfindMethod) { [weak self] request, context -> Response in
            guard let self else { return Response(status: .internalServerError) }
            return self.handlePROPFIND(request: request, context: context, uploadDirectory: uploadDirectory)
        }

        // GET — file download
        // FIXME (Phase 2): `Data(contentsOf:)` buffers the entire file before sending.
        // Large ROMs/ISOs can cause memory pressure or OOM. Replace with a streaming/
        // sendfile response once Hummingbird's file-serving middleware is integrated.
        router.get("/**") { [weak self] _, context -> Response in
            let path = context.parameters.get("**") ?? ""
            guard let self else { return Response(status: .internalServerError) }
            return self.fileDownloadResponse(path: path, uploadDirectory: uploadDirectory)
        }

        // HEAD — metadata only (Finder compatibility)
        router.on("/**", method: .head) { [weak self] _, context -> Response in
            let path = context.parameters.get("**") ?? ""
            guard let self else { return Response(status: .internalServerError) }
            return self.fileHeadResponse(path: path, uploadDirectory: uploadDirectory)
        }

        // PUT — streaming file upload
        router.put("/**") { [weak self] request, context -> Response in
            let path = context.parameters.get("**") ?? ""
            guard let self,
                  let target = self.resolvedPath(path, withinDirectory: uploadDirectory) else {
                return Response(status: .forbidden)
            }
            if self.exceedsMaxUploadContentLength(request) {
                return Response(status: .contentTooLarge)
            }

            NotificationCenter.default.post(
                name: .pvWebServerFileUploadStarted,
                object: self,
                userInfo: ["path": target.path, "fileSize": 0]
            )

            do {
                let bytesWritten = try await self.streamRequestBodyToFile(request, destination: target)
                let fileSize = Int(bytesWritten)
                self.postUploadCompletedNotifications(path: target.path, fileSize: fileSize)
                self.sseBroadcast(
                    type: "upload",
                    path: target.path,
                    extra: ["size": String(fileSize)]
                )
                return Response(status: .created)
            } catch {
                NotificationCenter.default.post(
                    name: .pvWebServerFileUploadFailed,
                    object: self,
                    userInfo: ["filePath": target.path, "error": error]
                )
                return Response(status: .internalServerError)
            }
        }

        // DELETE — remove file
        router.delete("/**") { [weak self] _, context -> Response in
            let path = context.parameters.get("**") ?? ""
            guard let self,
                  let target = self.resolvedPath(path, withinDirectory: uploadDirectory) else {
                return Response(status: .forbidden)
            }
            do {
                try FileManager.default.removeItem(at: target)
                NotificationCenter.default.post(
                    name: .pvWebServerFileDeleted,
                    object: self,
                    userInfo: ["filePath": target.path]
                )
                self.sseBroadcast(type: "delete", path: target.path)
                return Response(status: .noContent)
            } catch {
                return Response(status: .notFound)
            }
        }

        // MKCOL — create directory
        guard let mkcolMethod = HTTPRequest.Method("MKCOL") else {
            preconditionFailure("MKCOL must be a valid HTTP method token")
        }
        router.on("/**", method: mkcolMethod) { [weak self] _, context -> Response in
            let path = context.parameters.get("**") ?? ""
            guard let self,
                  let target = self.resolvedPath(path, withinDirectory: uploadDirectory) else {
                return Response(status: .forbidden)
            }
            do {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                self.sseBroadcast(type: "folder", path: target.path)
                return Response(status: .created)
            } catch {
                return Response(status: .methodNotAllowed)
            }
        }

        // COPY — duplicate item (Finder / macOS WebDAV clients)
        guard let copyMethod = HTTPRequest.Method("COPY") else {
            preconditionFailure("COPY must be a valid HTTP method token")
        }
        router.on("/**", method: copyMethod) { [weak self] request, context -> Response in
            guard let self else { return Response(status: .internalServerError) }
            return self.handleWebDAVCopy(request: request, context: context, uploadDirectory: uploadDirectory, isMove: false)
        }

        // MOVE — rename/move item
        guard let moveMethod = HTTPRequest.Method("MOVE") else {
            preconditionFailure("MOVE must be a valid HTTP method token")
        }
        router.on("/**", method: moveMethod) { [weak self] request, context -> Response in
            guard let self else { return Response(status: .internalServerError) }
            return self.handleWebDAVCopy(request: request, context: context, uploadDirectory: uploadDirectory, isMove: true)
        }

        return router
    }

    func fileDownloadResponse(path: String, uploadDirectory: URL) -> Response {
        guard let target = resolvedPath(path, withinDirectory: uploadDirectory),
              let data = try? Data(contentsOf: target) else {
            return Response(status: .notFound)
        }
        return Response(
            status: .ok,
            headers: [.contentType: "application/octet-stream"],
            body: .init(byteBuffer: ByteBuffer(bytes: data))
        )
    }

    func fileHeadResponse(path: String, uploadDirectory: URL) -> Response {
        guard let target = resolvedPath(path, withinDirectory: uploadDirectory) else {
            return Response(status: .forbidden)
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDir) else {
            return Response(status: .notFound)
        }
        let attrs = try? target.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        var headers: HTTPFields = [.contentType: "application/octet-stream"]
        if let size = attrs?.fileSize {
            headers[.contentLength] = String(size)
        }
        if let modified = attrs?.contentModificationDate,
           let lastModified = HTTPField.Name("Last-Modified") {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            fmt.timeZone = TimeZone(abbreviation: "GMT")
            headers[lastModified] = fmt.string(from: modified)
        }
        return Response(status: .ok, headers: headers, body: .init())
    }

    func handleWebDAVCopy(
        request: Request,
        context: some RequestContext,
        uploadDirectory: URL,
        isMove: Bool
    ) -> Response {
        let srcRelative = context.parameters.get("**") ?? ""
        guard let src = resolvedPath(srcRelative, withinDirectory: uploadDirectory) else {
            return Response(status: .forbidden)
        }
        guard FileManager.default.fileExists(atPath: src.path) else {
            return Response(status: .notFound)
        }

        guard let destinationField = kWebDAVFieldNameDestination,
              let destinationHeader = request.headers[destinationField] else {
            return Response(status: .badRequest)
        }
        guard let dstRelative = webDAVRelativeDestination(from: String(destinationHeader), request: request) else {
            return Response(status: .badRequest)
        }
        guard let dst = resolvedPath(dstRelative, withinDirectory: uploadDirectory) else {
            return Response(status: .forbidden)
        }

        let dstName = dst.lastPathComponent
        if dstName.hasPrefix(".") {
            return Response(status: .forbidden)
        }

        let parent = dst.deletingLastPathComponent()
        var parentIsDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &parentIsDir), parentIsDir.boolValue else {
            return Response(status: .conflict)
        }

        let overwriteRaw: String = {
            guard let field = kWebDAVFieldNameOverwrite,
                  let value = request.headers[field] else {
                return "T"
            }
            return String(value)
        }()
        let exists = FileManager.default.fileExists(atPath: dst.path)
        if exists {
            let overwrite = overwriteRaw.uppercased()
            if isMove {
                if overwrite != "T" { return Response(status: .preconditionFailed) }
            } else if overwrite == "F" {
                return Response(status: .preconditionFailed)
            }
        }

        do {
            if exists {
                try FileManager.default.removeItem(at: dst)
            }
            if isMove {
                try FileManager.default.moveItem(at: src, to: dst)
                NotificationCenter.default.post(
                    name: .pvWebServerFileMoved,
                    object: self,
                    userInfo: ["fromPath": src.path, "toPath": dst.path]
                )
                sseBroadcast(
                    type: "rename",
                    path: dst.path,
                    extra: ["from": relativeBrowsePath(for: src.path)]
                )
            } else {
                try FileManager.default.copyItem(at: src, to: dst)
                sseBroadcast(type: "upload", path: dst.path)
            }
            return Response(status: isMove ? .noContent : .created)
        } catch {
            return Response(status: .forbidden)
        }
    }

    /// Parses the WebDAV `Destination` header into a path relative to the upload root.
    func webDAVRelativeDestination(from header: String, request: Request) -> String? {
        var value = header.trimmingCharacters(in: .whitespaces)
        if let authority = request.head.authority, let range = value.range(of: authority) {
            value = String(value[range.upperBound...])
        } else if let hostField = HTTPField.Name("Host"),
                  let host = request.headers[hostField],
                  let range = value.range(of: String(host)) {
            value = String(value[range.upperBound...])
        }
        if let url = URL(string: value), url.scheme != nil {
            value = url.path
        }
        value = value.removingPercentEncoding ?? value
        while value.hasPrefix("/") { value.removeFirst() }
        return value.isEmpty ? nil : value
    }

    func handlePROPFIND(request: Request, context: some RequestContext, uploadDirectory: URL) -> Response {
        let path = context.parameters.get("**") ?? ""
        guard let target = resolvedPath(path, withinDirectory: uploadDirectory) else {
            return Response(status: .forbidden)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) else {
            return Response(status: .notFound)
        }

        let responses: [String]
        if isDirectory.boolValue {
            let contents = (try? FileManager.default.contentsOfDirectory(at: target,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
            responses = ([target] + contents).map { url in
                propfindResponse(for: url, baseURL: uploadDirectory)
            }
        } else {
            responses = [propfindResponse(for: target, baseURL: uploadDirectory)]
        }

        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:multistatus xmlns:D="DAV:">
        \(responses.joined(separator: "\n"))
        </D:multistatus>
        """

        return Response(
            status: .init(code: 207),
            headers: [.contentType: "application/xml; charset=utf-8"],
            body: .init(byteBuffer: ByteBuffer(string: xml))
        )
    }

    func propfindResponse(for url: URL, baseURL: URL) -> String {
        let attrs = try? url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isDirectoryKey
        ])
        let isDir = attrs?.isDirectory ?? false
        let size = attrs?.fileSize ?? 0
        let modified = attrs?.contentModificationDate
        let created = attrs?.creationDate
        let href = "/" + (url.path.hasPrefix(baseURL.path)
            ? String(url.path.dropFirst(baseURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            : url.lastPathComponent)
        return WebDAVPropertyBuilder.propfindResponseBlock(
            href: href,
            isDirectory: isDir,
            size: size,
            modified: modified,
            created: created
        )
    }
}

// MARK: - Bonjour Advertisement

private extension PVModernWebServer {

    func startBonjourAdvertisement() {
        // NetService advertises an existing port via mDNS without binding a new socket,
        // so it does not conflict with the Hummingbird listener already bound to httpPort.
        let service = NetService(domain: "local.", type: "_http._tcp.", name: "Provenance", port: Int32(httpPort))
        service.publish()
        netService = service
        ILOG("[PVModernWebServer] Bonjour advertising 'Provenance' on port \(httpPort)")
    }
}

// MARK: - Utilities

private extension PVModernWebServer {

    /// Returns the resolved URL only if it remains within `baseDir`.
    /// Returns `nil` if the path would escape the base directory (path traversal).
    func resolvedPath(_ rawPath: String, withinDirectory baseDir: URL) -> URL? {
        WebServerPathSafety.resolvedPath(rawPath, withinDirectory: baseDir)
    }

    func currentIPAddress() -> String? {
        if let cached = cachedIPAddress { return cached }
        var address: String?
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0 else { return nil }
        defer { freeifaddrs(ifaddrs) }
        var ptr = ifaddrs
        while let current = ptr {
            guard let ifaAddr = current.pointee.ifa_addr else {
                ptr = current.pointee.ifa_next
                continue
            }
            if ifaAddr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: current.pointee.ifa_name)
                if name == "en0" || name == "en1" {
                    var addr = ifaAddr.pointee
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(ifaAddr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                    address = String(cString: host)
                }
            }
            ptr = current.pointee.ifa_next
        }
        cachedIPAddress = address
        return address
    }

    func postStatusNotification(isRunning: Bool, type: String, port: Int, url: URL?) {
        var info: [String: Any] = ["isRunning": isRunning, "type": type, "port": port]
        if let url { info["url"] = url.absoluteString }
        NotificationCenter.default.post(name: .pvWebServerStatusChanged, object: self, userInfo: info)
    }

    // MARK: Multipart parsing (minimal, single-pass)

    struct MultipartPart {
        let filename: String?
        let data: Data
    }

    func multipartBoundary(from contentType: String) -> String? {
        let parts = contentType.components(separatedBy: ";")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("boundary=") {
                return String(trimmed.dropFirst("boundary=".count))
            }
        }
        return nil
    }

    func parseMultipart(data: Data, boundary: String) -> [MultipartPart] {
        guard let boundaryData = "--\(boundary)".data(using: .utf8) else { return [] }

        var parts: [MultipartPart] = []
        var searchRange = data.startIndex..<data.endIndex

        while let boundaryRange = data.range(of: boundaryData, in: searchRange) {
            let afterBoundary = boundaryRange.upperBound
            guard afterBoundary < data.endIndex else { break }

            // Check for end boundary
            if data[afterBoundary...].starts(with: "--".data(using: .utf8)!) { break }

            // Skip CRLF after boundary
            let headerStart = afterBoundary + (data[afterBoundary] == UInt8(ascii: "\r") ? 2 : 1)

            // Find the end of headers (double CRLF)
            guard let doubleCRLF = data.range(of: "\r\n\r\n".data(using: .utf8)!, in: headerStart..<data.endIndex) else { break }

            let headersData = data[headerStart..<doubleCRLF.lowerBound]
            let bodyStart   = doubleCRLF.upperBound

            // Find next boundary for body end
            guard let nextBoundary = data.range(of: boundaryData, in: bodyStart..<data.endIndex) else { break }
            let bodyEnd = nextBoundary.lowerBound - 2 // strip trailing CRLF

            let headers = String(data: headersData, encoding: .utf8) ?? ""
            let filename = extractFilename(from: headers)
            let bodyData = bodyEnd > bodyStart ? Data(data[bodyStart..<bodyEnd]) : Data()

            if let filename, !filename.isEmpty {
                parts.append(MultipartPart(filename: filename, data: bodyData))
            }

            searchRange = nextBoundary.lowerBound..<data.endIndex
        }

        return parts
    }

    func extractFilename(from headers: String) -> String? {
        for line in headers.components(separatedBy: "\r\n") {
            guard line.lowercased().contains("content-disposition") else { continue }
            let components = line.components(separatedBy: ";")
            for component in components {
                let trimmed = component.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("filename=") {
                    var name = String(trimmed.dropFirst("filename=".count))
                    name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    return name.isEmpty ? nil : name
                }
            }
        }
        return nil
    }

    // MARK: HTML UI

    static func fileManagerHTML(defaultUploadPath: String) -> String {
        // Inject the default upload subpath as a JS constant so client-side
        // navigation can target it before any user interaction.
        let jsDefaultPath = defaultUploadPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Provenance — Web File Manager</title>
          <style>
            :root {
              color-scheme: dark;
              --pv-bg: #1a1a2e;
              --pv-surface: #16213e;
              --pv-surface-hover: #1f2f52;
              --pv-border: #2a3a5c;
              --pv-text: #e0e0e0;
              --pv-text-muted: #8899aa;
              --pv-accent: #4a90d9;
              --pv-accent-hover: #5ba3ec;
              --pv-success: #27ae60;
              --pv-danger: #c0392b;
              --pv-warning: #f39c12;
            }
            * { box-sizing: border-box; }
            body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
                   max-width: 1100px; margin: 0 auto; padding: 20px;
                   background: var(--pv-bg); color: var(--pv-text);
                   -webkit-font-smoothing: antialiased; }
            header { display: flex; align-items: center; gap: 16px; padding: 8px 0 16px;
                     border-bottom: 2px solid var(--pv-accent); margin-bottom: 20px; }
            header .logo { font-size: 32px; line-height: 1; }
            header h1 { margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px; }
            header .sub { margin: 2px 0 0; color: var(--pv-text-muted); font-size: 13px; }

            .card { background: var(--pv-surface); border: 1px solid var(--pv-border);
                    border-radius: 10px; padding: 16px; margin-bottom: 16px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.25); }
            .card h2 { margin: 0 0 12px; font-size: 13px; font-weight: 600;
                       color: var(--pv-text-muted); text-transform: uppercase; letter-spacing: 0.5px; }

            .drop-zone { border: 2px dashed var(--pv-border); border-radius: 10px;
                         padding: 28px 20px; text-align: center; transition: all 0.2s;
                         background-color: rgba(74, 144, 217, 0.03); cursor: pointer; }
            .drop-zone.hover { border-color: var(--pv-accent);
                               background-color: rgba(74, 144, 217, 0.12);
                               box-shadow: 0 0 18px rgba(74, 144, 217, 0.18); }
            .drop-zone p { margin: 6px 0; color: var(--pv-text-muted); font-size: 13px; }
            .drop-zone .lead { color: var(--pv-text); font-weight: 600; font-size: 15px; }
            .btn { display: inline-block; padding: 8px 16px; border-radius: 6px;
                   font-size: 14px; font-weight: 500; cursor: pointer;
                   border: 1px solid transparent; transition: all 0.15s; }
            .btn-primary { background: var(--pv-accent); color: #fff; border-color: var(--pv-accent); }
            .btn-primary:hover { background: var(--pv-accent-hover); border-color: var(--pv-accent-hover); }
            .btn-success { background: var(--pv-success); color: #fff; border-color: var(--pv-success); }
            .btn-success:hover { filter: brightness(1.1); }
            .btn-default { background: var(--pv-surface); color: var(--pv-text); border-color: var(--pv-border); }
            .btn-default:hover { background: var(--pv-surface-hover); border-color: var(--pv-accent); color: #fff; }
            .btn-sm { padding: 4px 10px; font-size: 13px; }
            .btn-icon { padding: 4px 8px; background: none; border: none; color: var(--pv-text-muted);
                        cursor: pointer; border-radius: 4px; font-size: 14px; }
            .btn-icon:hover { background: rgba(255,255,255,0.06); color: #fff; }
            .btn-icon.danger:hover { background: rgba(192,57,43,0.18); color: #e74c3c; }

            .toolbar { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; margin-top: 12px; }
            #progress-bar { width: 100%; height: 6px; background: var(--pv-bg); border-radius: 3px;
                            margin-top: 12px; display: none; overflow: hidden; }
            #progress-fill { height: 100%; background: var(--pv-accent); width: 0%; transition: width 0.2s; }
            #status { margin-top: 8px; font-size: 13px; color: var(--pv-text-muted); }

            .quick-nav { display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
                         margin-bottom: 12px; }
            .quick-nav-label { font-size: 13px; color: var(--pv-text-muted); font-weight: 500; }
            .quick-nav .btn { background: var(--pv-surface); color: var(--pv-text);
                              border: 1px solid var(--pv-border); padding: 4px 12px; font-size: 13px; }
            .quick-nav .btn:hover { background: var(--pv-surface-hover); border-color: var(--pv-accent); color: #fff; }
            .quick-nav .btn.active { background: var(--pv-accent); border-color: var(--pv-accent); color: #fff; }

            .breadcrumb { display: flex; flex-wrap: wrap; gap: 4px; align-items: center;
                          font-size: 13px; color: var(--pv-text-muted); margin-bottom: 10px; }
            .breadcrumb a { color: var(--pv-accent); cursor: pointer; text-decoration: none; }
            .breadcrumb a:hover { text-decoration: underline; color: var(--pv-accent-hover); }
            .breadcrumb .sep { color: var(--pv-text-muted); }

            table { width: 100%; border-collapse: collapse; }
            thead th { text-align: left; padding: 8px 10px; font-size: 12px; font-weight: 600;
                       color: var(--pv-text-muted); text-transform: uppercase; letter-spacing: 0.5px;
                       border-bottom: 1px solid var(--pv-border); }
            tbody tr { border-bottom: 1px solid var(--pv-border); transition: background 0.15s; }
            tbody tr:hover { background: rgba(74,144,217,0.08); }
            tbody td { padding: 10px; font-size: 14px; vertical-align: middle; color: var(--pv-text); }
            .col-name { width: auto; }
            .col-name .clickable { color: var(--pv-text); cursor: pointer; }
            .col-name .clickable:hover { color: #fff; text-decoration: underline; }
            .col-name .dir-icon { color: var(--pv-warning); margin-right: 6px; }
            .col-name .file-icon { color: var(--pv-text-muted); margin-right: 6px; }
            .col-size { width: 110px; text-align: right; color: var(--pv-text-muted);
                        font-variant-numeric: tabular-nums; font-size: 13px; }
            .col-mod { width: 200px; color: var(--pv-text-muted); font-size: 13px; }
            .col-actions { width: 130px; text-align: right; white-space: nowrap; }
            .empty { color: var(--pv-text-muted); text-align: center; padding: 32px 16px; font-size: 14px; }

            .modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.6);
                              display: none; align-items: center; justify-content: center;
                              z-index: 1000; }
            .modal-backdrop.active { display: flex; }
            .modal { background: var(--pv-surface); border: 1px solid var(--pv-border);
                     border-radius: 10px; padding: 20px; min-width: 320px;
                     box-shadow: 0 8px 24px rgba(0,0,0,0.4); }
            .modal h3 { margin: 0 0 12px; font-size: 16px; }
            .modal input { width: 100%; padding: 8px 12px; background: var(--pv-bg);
                           border: 1px solid var(--pv-border); border-radius: 6px;
                           color: var(--pv-text); font-size: 14px; }
            .modal input:focus { border-color: var(--pv-accent); outline: none;
                                 box-shadow: 0 0 0 2px rgba(74,144,217,0.25); }
            .modal-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 16px; }

            /* ---------- Dashboard ---------- */
            .dashboard { display: grid; grid-template-columns: 1fr 168px; gap: 20px; align-items: stretch; }
            .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; }
            .stat { background: var(--pv-bg); border: 1px solid var(--pv-border); border-radius: 8px;
                    padding: 12px; }
            .stat .label { font-size: 11px; color: var(--pv-text-muted); text-transform: uppercase;
                           letter-spacing: 0.5px; margin-bottom: 4px; }
            .stat .value { font-size: 20px; font-weight: 700; color: #ffffff; font-variant-numeric: tabular-nums; }
            .stat .sub { font-size: 12px; color: var(--pv-text-muted); margin-top: 2px; }
            .disk-bar { margin-top: 10px; height: 6px; background: var(--pv-bg);
                        border: 1px solid var(--pv-border); border-radius: 3px; overflow: hidden; }
            .disk-fill { height: 100%; background: linear-gradient(90deg, var(--pv-accent), var(--pv-success));
                         transition: width 0.4s ease; }
            .qr-block { display: flex; flex-direction: column; align-items: center; gap: 6px;
                        padding: 8px; background: #ffffff; border-radius: 8px; }
            .qr-block img { width: 152px; height: 152px; display: block; image-rendering: pixelated; }
            .qr-block .caption { color: #111; font-size: 11px; font-weight: 600; }
            .server-url-row { display: flex; gap: 8px; align-items: center; flex-wrap: wrap;
                              margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--pv-border);
                              font-size: 13px; }
            .server-url-row code { background: var(--pv-bg); border: 1px solid var(--pv-border);
                                   padding: 4px 8px; border-radius: 4px; color: var(--pv-accent); }
            .copy-btn { padding: 4px 10px; font-size: 12px; }

            /* ---------- Search + select toolbar ---------- */
            .list-toolbar { display: flex; gap: 8px; align-items: center; flex-wrap: wrap;
                            margin-bottom: 10px; }
            .search-input { flex: 1 1 220px; min-width: 160px; padding: 6px 10px;
                            background: var(--pv-bg); border: 1px solid var(--pv-border);
                            border-radius: 6px; color: var(--pv-text); font-size: 13px; }
            .search-input:focus { border-color: var(--pv-accent); outline: none;
                                  box-shadow: 0 0 0 2px rgba(74,144,217,0.25); }
            .selection-pill { display: none; padding: 4px 10px; border-radius: 12px;
                              background: rgba(74,144,217,0.18); color: var(--pv-accent);
                              font-size: 12px; font-weight: 600; }
            .selection-pill.active { display: inline-block; }

            .col-check { width: 32px; text-align: center; }
            .col-check input[type="checkbox"] { accent-color: var(--pv-accent); cursor: pointer;
                                                 width: 14px; height: 14px; }

            /* ---------- Toast notifications ---------- */
            #toast-stack { position: fixed; top: 20px; right: 20px; z-index: 2000;
                           display: flex; flex-direction: column; gap: 8px; max-width: 320px; }
            .toast { background: var(--pv-surface); border: 1px solid var(--pv-border);
                     border-radius: 8px; padding: 10px 14px; font-size: 13px;
                     box-shadow: 0 6px 20px rgba(0,0,0,0.45);
                     animation: toastIn 0.18s ease-out; }
            .toast.success { border-color: var(--pv-success); color: #ffffff; }
            .toast.error   { border-color: var(--pv-danger);  color: #ffffff; }
            .toast.info    { border-color: var(--pv-accent);  color: var(--pv-text); }
            @keyframes toastIn { from { transform: translateY(-8px); opacity: 0; }
                                 to   { transform: translateY(0);    opacity: 1; } }
            .toast.leaving { animation: toastOut 0.18s ease-in forwards; }
            @keyframes toastOut { to { transform: translateY(-8px); opacity: 0; } }

            @media (max-width: 700px) {
              .dashboard { grid-template-columns: 1fr; }
              .qr-block  { align-self: center; }
            }
            @media (max-width: 600px) {
              .col-mod { display: none; }
              .col-size { width: 80px; }
              .col-actions { width: 96px; }
              .col-check { width: 28px; }
            }
          </style>
        </head>
        <body>
          <div id="toast-stack" aria-live="polite"></div>

          <header>
            <div class="logo">🎮</div>
            <div>
              <h1>Provenance Web Uploader</h1>
              <p class="sub">Drag &amp; drop ROMs, BIOS, and save files from any device on your network.</p>
            </div>
          </header>

          <!-- Dashboard: disk stats, uptime, server URL, QR code -->
          <div class="card">
            <h2>Dashboard</h2>
            <div class="dashboard">
              <div>
                <div class="stats-grid">
                  <div class="stat">
                    <div class="label">Disk Used</div>
                    <div class="value" id="stat-disk-used">—</div>
                    <div class="sub" id="stat-disk-sub">of — total</div>
                    <div class="disk-bar"><div class="disk-fill" id="stat-disk-fill" style="width:0%"></div></div>
                  </div>
                  <div class="stat">
                    <div class="label">Library Size</div>
                    <div class="value" id="stat-library-size">—</div>
                    <div class="sub" id="stat-library-count">— files across categories</div>
                  </div>
                  <div class="stat">
                    <div class="label">Server Uptime</div>
                    <div class="value" id="stat-uptime">—</div>
                    <div class="sub" id="stat-version">Provenance —</div>
                  </div>
                </div>
                <div class="server-url-row">
                  <span class="quick-nav-label">Connect via:</span>
                  <code id="server-url">—</code>
                  <button class="btn btn-default copy-btn" id="copy-url-btn">📋 Copy</button>
                  <span class="quick-nav-label">WebDAV:</span>
                  <code id="webdav-url">—</code>
                </div>
              </div>
              <div class="qr-block" id="qr-block" title="Scan to open from your phone">
                <img id="qr-img" alt="QR code for server URL" src="/qr.png">
                <div class="caption">Scan to open</div>
              </div>
            </div>
          </div>

          <div class="card">
            <div class="drop-zone" id="drop-zone">
              <p class="lead">Drop files here to upload</p>
              <p>or</p>
              <div class="toolbar">
                <button class="btn btn-primary" id="upload-btn">⬆ Upload Files</button>
                <button class="btn btn-success" id="newfolder-btn">📁 New Folder</button>
                <button class="btn btn-default" id="refresh-btn">↻ Refresh</button>
                <input type="file" id="file-input" multiple style="display:none">
              </div>
              <div id="progress-bar"><div id="progress-fill"></div></div>
              <div id="status"></div>
            </div>
          </div>

          <div class="card">
            <div class="quick-nav">
              <span class="quick-nav-label">Quick Access:</span>
              <button class="btn btn-sm" data-quick="Imports">Imports</button>
              <button class="btn btn-sm" data-quick="ROMs">ROMs</button>
              <button class="btn btn-sm" data-quick="BIOS">BIOS</button>
              <button class="btn btn-sm" data-quick="Save States">Save States</button>
              <button class="btn btn-sm" data-quick="">All Files</button>
            </div>
            <nav class="breadcrumb" id="breadcrumb"></nav>
            <div class="list-toolbar">
              <input type="search" class="search-input" id="search-input"
                     placeholder="🔍 Filter files in this folder…" autocomplete="off">
              <span class="selection-pill" id="selection-pill">0 selected</span>
              <button class="btn btn-default btn-sm" id="select-all-btn">☑ Select All</button>
              <button class="btn btn-default btn-sm" id="select-none-btn">☐ Clear</button>
              <button class="btn btn-danger btn-sm" id="bulk-delete-btn" disabled
                      style="background:var(--pv-danger);border-color:var(--pv-danger);color:#fff;opacity:0.55">
                🗑 Delete Selected
              </button>
            </div>
            <table>
              <thead><tr>
                <th class="col-check"><input type="checkbox" id="select-all-cb" title="Select all"></th>
                <th class="col-name">Name</th>
                <th class="col-size">Size</th>
                <th class="col-mod">Modified</th>
                <th class="col-actions"></th>
              </tr></thead>
              <tbody id="file-list"><tr><td colspan="5" class="empty">Loading…</td></tr></tbody>
            </table>
          </div>

          <div class="modal-backdrop" id="modal">
            <div class="modal">
              <h3 id="modal-title">New Folder</h3>
              <input type="text" id="modal-input" autocomplete="off">
              <div class="modal-actions">
                <button class="btn btn-default" id="modal-cancel">Cancel</button>
                <button class="btn btn-primary" id="modal-ok">OK</button>
              </div>
            </div>
          </div>

          <script>
            const DEFAULT_UPLOAD_PATH = "\(jsDefaultPath)";
            let currentPath = DEFAULT_UPLOAD_PATH;
            let currentItems = [];          // Cached items for current dir (post-filter rendering)
            const selectedNames = new Set(); // Names of selected items in current dir
            let searchFilter = '';

            // ----- Toasts -----
            function toast(message, type = 'info', durationMs = 3200) {
              const stack = document.getElementById('toast-stack');
              if (!stack) return;
              const el = document.createElement('div');
              el.className = 'toast ' + type;
              el.textContent = message;
              stack.appendChild(el);
              setTimeout(() => {
                el.classList.add('leaving');
                setTimeout(() => el.remove(), 220);
              }, durationMs);
            }

            function esc(s) {
              return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;')
                              .replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#x27;');
            }
            function fmtSize(b) {
              if (!b) return '0 B';
              if (b < 1024) return b + ' B';
              if (b < 1024*1024) return (b/1024).toFixed(1) + ' KB';
              if (b < 1024*1024*1024) return (b/1024/1024).toFixed(1) + ' MB';
              return (b/1024/1024/1024).toFixed(2) + ' GB';
            }
            function fmtUptime(seconds) {
              const d = Math.floor(seconds / 86400);
              const h = Math.floor((seconds % 86400) / 3600);
              const m = Math.floor((seconds % 3600) / 60);
              const s = Math.floor(seconds % 60);
              if (d > 0) return d + 'd ' + h + 'h';
              if (h > 0) return h + 'h ' + m + 'm';
              if (m > 0) return m + 'm ' + s + 's';
              return s + 's';
            }
            function joinPath(a, b) {
              if (!a) return b;
              if (!b) return a;
              return a.replace(/\\/+$/, '') + '/' + b.replace(/^\\/+/, '');
            }
            function parentPath(p) {
              if (!p) return '';
              const trimmed = p.replace(/\\/+$/, '');
              const idx = trimmed.lastIndexOf('/');
              return idx >= 0 ? trimmed.slice(0, idx) : '';
            }

            // ----- Modal helpers -----
            const modal = document.getElementById('modal');
            const modalTitle = document.getElementById('modal-title');
            const modalInput = document.getElementById('modal-input');
            const modalOk = document.getElementById('modal-ok');
            const modalCancel = document.getElementById('modal-cancel');
            let modalResolver = null;
            function promptModal(title, placeholder) {
              modalTitle.textContent = title;
              modalInput.value = placeholder || '';
              modal.classList.add('active');
              modalInput.focus();
              modalInput.select();
              return new Promise(resolve => { modalResolver = resolve; });
            }
            modalOk.addEventListener('click', () => { modal.classList.remove('active');
              const v = modalInput.value.trim(); modalResolver && modalResolver(v || null); });
            modalCancel.addEventListener('click', () => { modal.classList.remove('active');
              modalResolver && modalResolver(null); });
            modalInput.addEventListener('keydown', e => { if (e.key === 'Enter') modalOk.click(); else if (e.key === 'Escape') modalCancel.click(); });

            // ----- Listing + breadcrumb -----
            async function loadFiles(path) {
              const isNavigation = path !== undefined && path !== currentPath;
              currentPath = path === undefined ? currentPath : path;
              if (isNavigation) {
                selectedNames.clear();
                searchFilter = '';
                const search = document.getElementById('search-input');
                if (search) search.value = '';
              }
              renderBreadcrumb();
              updateQuickActive();
              const tbody = document.getElementById('file-list');
              tbody.innerHTML = '<tr><td colspan="5" class="empty">Loading…</td></tr>';
              try {
                const res = await fetch('/files?path=' + encodeURIComponent(currentPath));
                if (!res.ok) {
                  const err = await res.json().catch(() => ({}));
                  tbody.innerHTML = '<tr><td colspan="5" class="empty">' + esc(err.error || 'Failed to load') + '</td></tr>';
                  return;
                }
                const payload = await res.json();
                currentItems = payload.items || [];
                renderFileList();
              } catch (e) {
                tbody.innerHTML = '<tr><td colspan="5" class="empty">' + esc(e.message) + '</td></tr>';
              }
            }

            function renderFileList() {
              const tbody = document.getElementById('file-list');
              const filtered = searchFilter
                ? currentItems.filter(it => it.name.toLowerCase().includes(searchFilter))
                : currentItems;
              // Drop selections that no longer exist after a filter / refresh.
              for (const name of Array.from(selectedNames)) {
                if (!filtered.some(it => it.name === name)) selectedNames.delete(name);
              }
              let html = '';
              if (currentPath) {
                html += '<tr data-up="1"><td class="col-check"></td><td class="col-name"><span class="clickable"><span class="dir-icon">↑</span>..</span></td><td></td><td></td><td></td></tr>';
              }
              if (!filtered.length) {
                const msg = searchFilter
                  ? 'No files match "' + esc(searchFilter) + '".'
                  : (currentPath ? 'This folder is empty.' : 'No files yet — drag and drop above to upload!');
                tbody.innerHTML = html + '<tr><td colspan="5" class="empty">' + msg + '</td></tr>';
                updateSelectionUI();
                return;
              }
              html += filtered.map(it => {
                const icon = it.isDirectory ? '<span class="dir-icon">📁</span>' : '<span class="file-icon">📄</span>';
                const sizeCell = it.isDirectory ? '' : fmtSize(it.size);
                const modCell = it.modified ? new Date(it.modified).toLocaleString() : '';
                const checked = selectedNames.has(it.name) ? ' checked' : '';
                const actions = it.isDirectory
                  ? '<button class="btn-icon" data-action="rename" data-name="' + esc(it.name) + '" title="Rename">✎</button>' +
                    '<button class="btn-icon danger" data-action="delete" data-name="' + esc(it.name) + '" data-is-dir="1" title="Delete">🗑</button>'
                  : '<button class="btn-icon" data-action="download" data-name="' + esc(it.name) + '" title="Download">⬇</button>' +
                    '<button class="btn-icon" data-action="rename" data-name="' + esc(it.name) + '" title="Rename">✎</button>' +
                    '<button class="btn-icon danger" data-action="delete" data-name="' + esc(it.name) + '" title="Delete">🗑</button>';
                return '<tr data-name="' + esc(it.name) + '" data-is-dir="' + (it.isDirectory ? '1' : '0') + '">' +
                       '<td class="col-check"><input type="checkbox" data-select="' + esc(it.name) + '"' + checked + '></td>' +
                       '<td class="col-name"><span class="clickable">' + icon + esc(it.name) + '</span></td>' +
                       '<td class="col-size">' + esc(sizeCell) + '</td>' +
                       '<td class="col-mod">' + esc(modCell) + '</td>' +
                       '<td class="col-actions">' + actions + '</td>' +
                       '</tr>';
              }).join('');
              tbody.innerHTML = html;
              updateSelectionUI();
            }

            function updateSelectionUI() {
              const count = selectedNames.size;
              const pill = document.getElementById('selection-pill');
              const bulkBtn = document.getElementById('bulk-delete-btn');
              const headerCb = document.getElementById('select-all-cb');
              pill.textContent = count + ' selected';
              pill.classList.toggle('active', count > 0);
              bulkBtn.disabled = count === 0;
              bulkBtn.style.opacity = count === 0 ? '0.55' : '1';
              if (headerCb) {
                const total = currentItems.filter(it => !searchFilter || it.name.toLowerCase().includes(searchFilter)).length;
                headerCb.checked = count > 0 && count === total;
                headerCb.indeterminate = count > 0 && count < total;
              }
            }

            function renderBreadcrumb() {
              const crumb = document.getElementById('breadcrumb');
              const parts = currentPath ? currentPath.split('/').filter(Boolean) : [];
              let acc = '';
              let html = '<a data-path="">📂 root</a>';
              parts.forEach((p, i) => {
                acc = acc ? acc + '/' + p : p;
                html += '<span class="sep">/</span>';
                if (i === parts.length - 1) {
                  html += '<span>' + esc(p) + '</span>';
                } else {
                  html += '<a data-path="' + esc(acc) + '">' + esc(p) + '</a>';
                }
              });
              crumb.innerHTML = html;
            }
            function updateQuickActive() {
              document.querySelectorAll('.quick-nav .btn').forEach(btn => {
                btn.classList.toggle('active', btn.dataset.quick === currentPath);
              });
            }

            // ----- Row actions + selection -----
            document.getElementById('file-list').addEventListener('click', async e => {
              // Checkbox toggles update the selection set without reloading.
              const cb = e.target.closest('input[type="checkbox"][data-select]');
              if (cb) {
                const name = cb.dataset.select;
                if (cb.checked) selectedNames.add(name); else selectedNames.delete(name);
                updateSelectionUI();
                return;
              }
              const upRow = e.target.closest('tr[data-up]');
              if (upRow) { loadFiles(parentPath(currentPath)); return; }
              const actionBtn = e.target.closest('button[data-action]');
              if (actionBtn) {
                const name = actionBtn.dataset.name;
                const action = actionBtn.dataset.action;
                if (action === 'delete') await deletePath(joinPath(currentPath, name), name);
                else if (action === 'rename') await renamePath(name);
                else if (action === 'download') window.location.href = '/download?path=' + encodeURIComponent(joinPath(currentPath, name));
                return;
              }
              const row = e.target.closest('tr[data-name]');
              if (!row) return;
              const nameClick = e.target.closest('.col-name .clickable');
              if (!nameClick) return;
              const name = row.dataset.name;
              if (row.dataset.isDir === '1') loadFiles(joinPath(currentPath, name));
              else window.location.href = '/download?path=' + encodeURIComponent(joinPath(currentPath, name));
            });

            // ----- Search filter -----
            document.getElementById('search-input').addEventListener('input', e => {
              searchFilter = e.target.value.trim().toLowerCase();
              renderFileList();
            });

            // ----- Multi-select toolbar -----
            document.getElementById('select-all-btn').addEventListener('click', () => {
              const filtered = searchFilter
                ? currentItems.filter(it => it.name.toLowerCase().includes(searchFilter))
                : currentItems;
              filtered.forEach(it => selectedNames.add(it.name));
              renderFileList();
            });
            document.getElementById('select-none-btn').addEventListener('click', () => {
              selectedNames.clear();
              renderFileList();
            });
            document.getElementById('select-all-cb').addEventListener('change', e => {
              if (e.target.checked) {
                const filtered = searchFilter
                  ? currentItems.filter(it => it.name.toLowerCase().includes(searchFilter))
                  : currentItems;
                filtered.forEach(it => selectedNames.add(it.name));
              } else {
                selectedNames.clear();
              }
              renderFileList();
            });
            document.getElementById('bulk-delete-btn').addEventListener('click', async () => {
              if (selectedNames.size === 0) return;
              if (!confirm('Delete ' + selectedNames.size + ' item(s)? This cannot be undone.')) return;
              const paths = Array.from(selectedNames).map(n => joinPath(currentPath, n));
              const res = await fetch('/files/batch-delete', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ paths: paths })
              });
              if (!res.ok) { toast('Bulk delete failed', 'error'); return; }
              const j = await res.json().catch(() => ({}));
              const deleted = j.deleted || 0;
              const failedCount = (j.failed || []).length;
              if (failedCount === 0) {
                toast('Deleted ' + deleted + ' item' + (deleted === 1 ? '' : 's'), 'success');
              } else {
                toast('Deleted ' + deleted + ', ' + failedCount + ' failed', 'error');
              }
              selectedNames.clear();
              loadFiles();
              refreshStats();
            });

            async function deletePath(path, label) {
              if (!confirm('Delete "' + label + '"?')) return;
              const res = await fetch('/files?path=' + encodeURIComponent(path), { method: 'DELETE' });
              if (!res.ok) { toast('Delete failed', 'error'); return; }
              toast('Deleted "' + label + '"', 'success');
              loadFiles();
              refreshStats();
            }
            async function renamePath(name) {
              const newName = await promptModal('Rename "' + name + '" to:', name);
              if (!newName || newName === name) return;
              const from = joinPath(currentPath, name);
              const to = joinPath(currentPath, newName);
              const res = await fetch('/files', {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ from: from, to: to })
              });
              if (!res.ok) { toast('Rename failed', 'error'); return; }
              toast('Renamed to "' + newName + '"', 'success');
              loadFiles();
            }

            // ----- Quick nav -----
            document.querySelector('.quick-nav').addEventListener('click', e => {
              const btn = e.target.closest('button[data-quick]');
              if (!btn) return;
              loadFiles(btn.dataset.quick);
            });

            // ----- Breadcrumb nav -----
            document.getElementById('breadcrumb').addEventListener('click', e => {
              const link = e.target.closest('a[data-path]');
              if (!link) return;
              loadFiles(link.dataset.path);
            });

            // ----- New folder -----
            document.getElementById('newfolder-btn').addEventListener('click', async () => {
              const name = await promptModal('New folder name', '');
              if (!name) return;
              const res = await fetch('/folders', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ path: currentPath, name: name })
              });
              if (!res.ok) { alert('Could not create folder'); return; }
              loadFiles();
            });

            // ----- Refresh -----
            document.getElementById('refresh-btn').addEventListener('click', () => loadFiles());

            // ----- Drag & drop / upload -----
            const zone = document.getElementById('drop-zone');
            zone.addEventListener('dragover', e => { e.preventDefault(); zone.classList.add('hover'); });
            zone.addEventListener('dragleave', () => zone.classList.remove('hover'));
            zone.addEventListener('drop', e => {
              e.preventDefault();
              zone.classList.remove('hover');
              uploadFiles(e.dataTransfer.files);
            });
            document.getElementById('upload-btn').addEventListener('click', () => document.getElementById('file-input').click());
            document.getElementById('file-input').addEventListener('change', e => uploadFiles(e.target.files));

            async function uploadFiles(files) {
              enqueueUploads(Array.from(files || []), currentPath || DEFAULT_UPLOAD_PATH);
            }

            const MAX_CONCURRENT_UPLOADS = 3;
            const LIST_REFRESH_MS = 2500;
            let pendingUploads = [];
            let activeUploadCount = 0;
            let uploadBatchTotal = 0;
            let uploadBatchDone = 0;
            let listRefreshTimer = null;

            function scheduleRefreshFileList() {
              const targetPath = currentPath || DEFAULT_UPLOAD_PATH;
              if (listRefreshTimer) clearTimeout(listRefreshTimer);
              listRefreshTimer = setTimeout(() => {
                listRefreshTimer = null;
                loadFiles(targetPath);
              }, LIST_REFRESH_MS);
            }

            function updateUploadProgressUI() {
              const bar = document.getElementById('progress-bar');
              const fill = document.getElementById('progress-fill');
              const status = document.getElementById('status');
              if (!bar || !fill || !status) return;
              const active = activeUploadCount + pendingUploads.length;
              if (active === 0 && uploadBatchTotal === 0) {
                setTimeout(() => {
                  if (activeUploadCount === 0 && pendingUploads.length === 0) {
                    bar.style.display = 'none';
                    fill.style.width = '0%';
                    status.textContent = '';
                  }
                }, 3000);
                return;
              }
              bar.style.display = 'block';
              const pct = uploadBatchTotal > 0 ? (uploadBatchDone / uploadBatchTotal) * 100 : 0;
              fill.style.width = pct + '%';
              status.textContent = 'Uploading… ' + uploadBatchDone + '/' + uploadBatchTotal
                + (pendingUploads.length ? ' (' + pendingUploads.length + ' queued)' : '');
            }

            function enqueueUploads(fileList, targetPath) {
              if (!fileList || !fileList.length) return;
              noteLocalOp();
              for (let i = 0; i < fileList.length; i++) {
                pendingUploads.push({ file: fileList[i], targetPath: targetPath });
              }
              uploadBatchTotal += fileList.length;
              document.getElementById('progress-bar').style.display = 'block';
              updateUploadProgressUI();
              pumpUploadQueue();
            }

            function pumpUploadQueue() {
              while (activeUploadCount < MAX_CONCURRENT_UPLOADS && pendingUploads.length > 0) {
                const job = pendingUploads.shift();
                activeUploadCount++;
                uploadOneFile(job.file, job.targetPath).finally(() => {
                  activeUploadCount--;
                  uploadBatchDone++;
                  updateUploadProgressUI();
                  if ((currentPath || DEFAULT_UPLOAD_PATH) === job.targetPath) {
                    scheduleRefreshFileList();
                  }
                  if (pendingUploads.length === 0 && activeUploadCount === 0) {
                    uploadBatchTotal = 0;
                    uploadBatchDone = 0;
                    loadFiles();
                    refreshStats();
                    toast('Upload batch complete → ' + job.targetPath, 'success');
                  }
                  pumpUploadQueue();
                });
              }
            }

            function uploadOneFile(file, targetPath) {
              return new Promise(resolve => {
                const fd = new FormData();
                fd.append('files[]', file, file.name);
                const xhr = new XMLHttpRequest();
                xhr.onload = () => resolve();
                xhr.onerror = () => resolve();
                xhr.open('POST', '/upload?path=' + encodeURIComponent(targetPath));
                xhr.send(fd);
              });
            }

            // ----- Dashboard stats -----
            async function refreshStats() {
              try {
                const res = await fetch('/stats');
                if (!res.ok) return;
                const s = await res.json();
                document.getElementById('stat-disk-used').textContent = fmtSize(s.usedDiskBytes);
                document.getElementById('stat-disk-sub').textContent =
                  'of ' + fmtSize(s.totalDiskBytes) + ' total · ' + fmtSize(s.freeDiskBytes) + ' free';
                const pct = s.totalDiskBytes > 0
                  ? Math.min(100, (s.usedDiskBytes / s.totalDiskBytes) * 100)
                  : 0;
                document.getElementById('stat-disk-fill').style.width = pct.toFixed(1) + '%';

                let librarySize = 0;
                let libraryCount = 0;
                (s.directories || []).forEach(d => {
                  librarySize += (d.sizeBytes || 0);
                  libraryCount += (d.fileCount || 0);
                });
                document.getElementById('stat-library-size').textContent = fmtSize(librarySize);
                document.getElementById('stat-library-count').textContent =
                  libraryCount + ' file' + (libraryCount === 1 ? '' : 's') + ' across '
                  + (s.directories || []).length + ' categories';

                document.getElementById('stat-uptime').textContent = fmtUptime(s.uptimeSeconds || 0);
                document.getElementById('stat-version').textContent =
                  'Provenance ' + (s.appVersion || '?') + ' (' + (s.buildNumber || '?') + ')';

                const httpURL = s.serverURL || ('http://' + (s.ipAddress || '?') + ':' + s.httpPort + '/');
                document.getElementById('server-url').textContent = httpURL;
                document.getElementById('webdav-url').textContent =
                  s.webDAVURL || ('http://' + (s.ipAddress || '?') + ':' + s.webDAVPort + '/');

                // Refresh QR if the visible URL changed (cache-busts).
                const qr = document.getElementById('qr-img');
                if (qr) qr.src = '/qr.png?text=' + encodeURIComponent(httpURL);
              } catch (e) {
                // Silent — dashboard is non-critical.
                console.warn('stats fetch failed', e);
              }
            }

            document.getElementById('copy-url-btn').addEventListener('click', async () => {
              const text = document.getElementById('server-url').textContent.trim();
              if (!text || text === '—') return;
              try {
                await navigator.clipboard.writeText(text);
                toast('Copied: ' + text, 'success');
              } catch {
                toast('Copy failed — long-press the URL instead', 'error');
              }
            });

            // Periodic dashboard refresh so disk/uptime stay live without page reload.
            setInterval(refreshStats, 15000);
            refreshStats();

            // ----- Server-Sent Events (real-time file activity) -----
            //
            // Every connected browser opens an EventSource on /events. Each
            // mutating route on the server broadcasts a typed event after the
            // op succeeds. We refresh the file listing when the event touches
            // the current folder, refresh the dashboard for any file op, and
            // show a toast when the event came from someone else.
            let liveEventSource = null;
            let lastLocalOp = 0;        // ms timestamp of the most recent local op
            let refreshTimer = null;    // debounce timer for file-list refresh

            function noteLocalOp() { lastLocalOp = Date.now(); }

            // Wrap our own toast-bearing actions so we know not to re-toast
            // events that originated from this browser.
            ['deletePath','renamePath','uploadFiles','bulkDeleteAction'].forEach(fn => {
              if (typeof window[fn] !== 'function') return;
              const orig = window[fn];
              window[fn] = function() { noteLocalOp(); return orig.apply(this, arguments); };
            });

            function scheduleListRefresh() {
              if (refreshTimer) clearTimeout(refreshTimer);
              refreshTimer = setTimeout(() => {
                refreshTimer = null;
                loadFiles();
              }, 250);
            }

            function pathInsideCurrentDir(eventPath) {
              // Server returns paths relative to browseRoot; current dir is
              // also relative. Match dirname == currentPath (or both root).
              const norm = (eventPath || '').replace(/^\\/+/, '').replace(/\\/+$/, '');
              const lastSlash = norm.lastIndexOf('/');
              const parent = lastSlash >= 0 ? norm.slice(0, lastSlash) : '';
              return parent === (currentPath || '');
            }

            function connectLiveEvents() {
              if (typeof EventSource === 'undefined') return;
              try { liveEventSource && liveEventSource.close(); } catch {}
              const es = new EventSource('/events');
              liveEventSource = es;

              const handle = (kind) => (e) => {
                let data = {};
                try { data = JSON.parse(e.data || '{}'); } catch {}
                const isLocal = (Date.now() - lastLocalOp) < 800; // assume our own op

                if (pathInsideCurrentDir(data.path)) {
                  scheduleListRefresh();
                }
                refreshStats();

                if (!isLocal) {
                  const name = data.name || data.path || '';
                  if (kind === 'upload')      toast('📥 New upload: ' + name, 'info', 2400);
                  else if (kind === 'delete') toast('🗑 Removed: ' + name, 'info', 2200);
                  else if (kind === 'rename') toast('✎ Renamed → ' + name, 'info', 2200);
                  else if (kind === 'folder') toast('📁 New folder: ' + name, 'info', 2200);
                }
              };
              es.addEventListener('upload', handle('upload'));
              es.addEventListener('delete', handle('delete'));
              es.addEventListener('rename', handle('rename'));
              es.addEventListener('folder', handle('folder'));
              es.addEventListener('hello',  () => console.log('[SSE] connected'));

              es.onerror = () => {
                // Browser EventSource auto-reconnects per `retry:` hint.
                console.warn('[SSE] dropped; auto-reconnecting…');
              };
            }
            connectLiveEvents();

            // Initial load — start at the default upload path (matches GCDWebUploader behaviour).
            loadFiles(DEFAULT_UPLOAD_PATH);
          </script>
        </body>
        </html>
        """
    }
}

// MARK: - SSE subscriber hub

/// Fan-out broadcast hub for the `GET /events` Server-Sent-Events stream.
/// Each subscriber owns an `AsyncStream<ByteBuffer>.Continuation`; the hub
/// hands every broadcast to every active continuation. Subscribers self-
/// remove via `unsubscribe(_:)` from the route's defer block when the client
/// disconnects.
final class SSEHub: @unchecked Sendable {
    private let lock = NSLock()
    private var subscribers: [UUID: AsyncStream<ByteBuffer>.Continuation] = [:]

    func subscribe(_ continuation: AsyncStream<ByteBuffer>.Continuation) -> UUID {
        let id = UUID()
        lock.lock()
        subscribers[id] = continuation
        lock.unlock()
        return id
    }

    func unsubscribe(_ id: UUID) {
        lock.lock()
        if let continuation = subscribers.removeValue(forKey: id) {
            continuation.finish()
        }
        lock.unlock()
    }

    func broadcast(_ frame: ByteBuffer) {
        lock.lock()
        let snapshot = Array(subscribers.values)
        lock.unlock()
        for continuation in snapshot {
            continuation.yield(frame)
        }
    }

    var subscriberCount: Int {
        lock.lock(); defer { lock.unlock() }
        return subscribers.count
    }
}
