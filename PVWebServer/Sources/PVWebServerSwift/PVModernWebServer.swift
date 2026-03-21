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
import Hummingbird
import PVLogging

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
    /// Directory exposed to the web uploader. Defaults to Documents/Imports.
    public let uploadDirectory: URL

    // MARK: State

    private var httpServerTask: Task<Void, Error>?
    private var webDAVServerTask: Task<Void, Error>?
    private var netService: NetService?
    private var cachedIPAddress: String?

    private var _isHTTPRunning: Bool = false
    private var _isWebDAVRunning: Bool = false

    // MARK: Init

    public init(uploadDirectory: URL? = nil, httpPort: Int? = nil, webDAVPort: Int? = nil) {
        let isSimulatorOrCatalyst: Bool = {
#if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
            return true
#else
            return false
#endif
        }()

        self.httpPort    = httpPort    ?? (isSimulatorOrCatalyst ? 8080 : 80)
        self.webDAVPort  = webDAVPort  ?? (isSimulatorOrCatalyst ? 8081 : 81)

        if let dir = uploadDirectory {
            self.uploadDirectory = dir
        } else {
            let docs: URL
#if os(tvOS)
            docs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
#else
            docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
#endif
            self.uploadDirectory = docs.appendingPathComponent("Imports")
        }

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
        async let httpOK  = startHTTPServer()
        async let davOK   = startWebDAVServer()
        let results = try await (httpOK, davOK)

        if results.0 { startBonjourAdvertisement() }

        postStatusNotification(isRunning: true, type: "WebUploader", port: httpPort,   url: serverURL)
        postStatusNotification(isRunning: true, type: "WebDAV", port: webDAVPort, url: webDAVURL)

#if canImport(UIKit) && !os(watchOS)
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
        }
#endif
        return results.0 && results.1
    }

    public func stopServers() async {
        httpServerTask?.cancel()
        webDAVServerTask?.cancel()
        httpServerTask = nil
        webDAVServerTask = nil
        netService?.stop()
        netService = nil
        _isHTTPRunning  = false
        _isWebDAVRunning = false

        postStatusNotification(isRunning: false, type: "WebUploader", port: httpPort,   url: nil)
        postStatusNotification(isRunning: false, type: "WebDAV", port: webDAVPort, url: nil)

#if canImport(UIKit) && !os(watchOS)
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = false
        }
#endif
    }
}

// MARK: - HTTP Server

private extension PVModernWebServer {

    func startHTTPServer() async throws -> Bool {
        let dir = self.uploadDirectory
        let port = self.httpPort

        let router = buildHTTPRouter(uploadDirectory: dir)
        let app = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: port))
        )

        // NOTE (Phase 1 limitation): `_isHTTPRunning` is set optimistically before
        // the NIO event loop confirms the bind. If `app.run()` throws (e.g. port in
        // use), the flag is never reset to false. Phase 2 should introduce a startup
        // channel/continuation to observe the actual bind result before advertising.
        httpServerTask = Task {
            try await app.run()
        }

        _isHTTPRunning = true
        return true
    }

    func buildHTTPRouter(uploadDirectory: URL) -> Router<BasicRequestContext> {
        let router = Router()

        // GET / — serve built-in file-manager HTML
        router.get("/") { request, context -> Response in
            let html = PVModernWebServer.fileManagerHTML(uploadDirectory: uploadDirectory)
            return Response(
                status: .ok,
                headers: [.contentType: "text/html; charset=utf-8"],
                body: .init(byteBuffer: ByteBuffer(string: html))
            )
        }

        // GET /files — JSON directory listing
        router.get("/files") { request, context -> Response in
            let listing = (try? FileManager.default.contentsOfDirectory(
                at: uploadDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
            )) ?? []
            let items = listing.map { url -> [String: Any] in
                let attrs  = (try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]))
                let size   = attrs?.fileSize ?? 0
                let mtime  = attrs?.contentModificationDate.map { ISO8601DateFormatter().string(from: $0) } ?? ""
                return ["name": url.lastPathComponent, "size": size, "modified": mtime]
            }
            let data = (try? JSONSerialization.data(withJSONObject: items)) ?? Data()
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: ByteBuffer(bytes: data))
            )
        }

        // POST /upload — multipart file upload
        router.post("/upload") { [weak self] request, context -> Response in
            guard let self else {
                return Response(status: .internalServerError)
            }
            return try await self.handleUpload(request: request, context: context, uploadDirectory: uploadDirectory)
        }

        // DELETE /files/:name — delete a file
        router.delete("/files/:name") { [weak self] request, context -> Response in
            guard let name = context.parameters.get("name") else {
                return Response(status: .badRequest)
            }
            guard let self,
                  let target = self.resolvedPath(name, withinDirectory: uploadDirectory) else {
                return Response(status: .badRequest)
            }
            do {
                try FileManager.default.removeItem(at: target)
                return Response(status: .noContent)
            } catch {
                return Response(status: .internalServerError)
            }
        }

        return router
    }

    func handleUpload(
        request: Request,
        context: some RequestContext,
        uploadDirectory: URL
    ) async throws -> Response {
        // Cap at 256 MB — reduces DoS/OOM risk on device. Large ROM transfers
        // should use WebDAV PUT (streaming) once that is fully implemented (Phase 2).
        let body = try await request.body.collect(upTo: 256 * 1_024 * 1_024) // 256 MB cap
        guard let bodyData = body.withUnsafeReadableBytes({ ptr -> Data? in
            guard !ptr.isEmpty else { return nil }
            return Data(ptr)
        }) else {
            return Response(status: .badRequest)
        }

        // Parse a simple multipart/form-data body to extract the filename + contents.
        // For a full implementation, use a dedicated multipart parser library.
        guard
            let contentType = request.headers[.contentType],
            let boundary = multipartBoundary(from: String(contentType))
        else {
            return Response(status: .unsupportedMediaType)
        }

        let parts = parseMultipart(data: bodyData, boundary: boundary)
        var savedFiles: [String] = []

        for part in parts {
            guard let filename = part.filename, !filename.isEmpty else { continue }
            // Sanitize: strip path components to just the filename, block hidden files
            let sanitizedName = URL(fileURLWithPath: filename).lastPathComponent
            guard !sanitizedName.isEmpty, !sanitizedName.hasPrefix(".") else { continue }
            guard let dest = resolvedPath(sanitizedName, withinDirectory: uploadDirectory) else { continue }

            let fileData = part.data
            let fileSize = fileData.count

            // Fire upload-started notification BEFORE writing to disk
            NotificationCenter.default.post(
                name: .pvWebServerFileUploadStarted,
                object: self,
                userInfo: ["path": dest.path, "fileSize": fileSize]
            )

            do {
                try fileData.write(to: dest)
                savedFiles.append(sanitizedName)

                NotificationCenter.default.post(
                    name: .pvWebServerFileUploadCompleted,
                    object: self,
                    userInfo: ["filePath": dest.path, "fileSize": fileSize]
                )
                NotificationCenter.default.post(
                    name: .pvWebServerUploadCompleted,
                    object: self,
                    userInfo: ["fileName": dest.path, "fileSize": fileSize]
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
}

// MARK: - WebDAV HTTP field/method constants
// Pre-validated at compile time — these are known RFC-compliant token strings.
// Defining them once at module scope avoids per-request force-unwraps and makes
// any future breakage visible immediately at startup rather than at request time.

/// Custom "DAV" WebDAV capability header. Valid HTTP token — init always succeeds.
private let kWebDAVFieldNameDAV: HTTPField.Name? = HTTPField.Name("DAV")
/// Standard "Allow" HTTP header. Valid HTTP token — init always succeeds.
private let kWebDAVFieldNameAllow: HTTPField.Name? = HTTPField.Name("Allow")

// MARK: - WebDAV Server

private extension PVModernWebServer {

    func startWebDAVServer() async throws -> Bool {
        let dir = self.uploadDirectory
        let port = self.webDAVPort

        let router = buildWebDAVRouter(uploadDirectory: dir)
        let app = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: port))
        )

        // Same Phase 1 limitation as startHTTPServer — bind is not confirmed
        // before returning true. See the note there for Phase 2 follow-up.
        webDAVServerTask = Task {
            try await app.run()
        }

        _isWebDAVRunning = true
        return true
    }

    func buildWebDAVRouter(uploadDirectory: URL) -> Router<BasicRequestContext> {
        let router = Router()

        // OPTIONS — advertise WebDAV class 1 support
        router.on("/**", method: .options) { _, _ -> Response in
            var headers = HTTPFields()
            if let dav = kWebDAVFieldNameDAV   { headers[dav]   = "1" }
            if let allow = kWebDAVFieldNameAllow {
                headers[allow] = "OPTIONS, GET, HEAD, PUT, DELETE, PROPFIND, MKCOL"
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
            guard let self,
                  let target = self.resolvedPath(path, withinDirectory: uploadDirectory),
                  let data = try? Data(contentsOf: target) else {
                return Response(status: .notFound)
            }
            return Response(
                status: .ok,
                headers: [.contentType: "application/octet-stream"],
                body: .init(byteBuffer: ByteBuffer(bytes: data))
            )
        }

        // PUT — file upload
        router.put("/**") { [weak self] request, context -> Response in
            let path = context.parameters.get("**") ?? ""
            guard let self,
                  let target = self.resolvedPath(path, withinDirectory: uploadDirectory) else {
                return Response(status: .forbidden)
            }
            // Same 256 MB cap as the HTTP uploader — Phase 2 will replace this
            // with a streaming write to avoid buffering large files in memory.
            let body = try await request.body.collect(upTo: 256 * 1_024 * 1_024)
            let data = body.withUnsafeReadableBytes { ptr in Data(ptr) }
            try data.write(to: target)

            let fileSize = data.count
            NotificationCenter.default.post(
                name: .pvWebServerFileUploadCompleted,
                object: self,
                userInfo: ["filePath": target.path, "fileSize": fileSize]
            )
            NotificationCenter.default.post(
                name: .pvWebServerUploadCompleted,
                object: self,
                userInfo: ["fileName": target.path, "fileSize": fileSize]
            )
            return Response(status: .created)
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
                return Response(status: .created)
            } catch {
                return Response(status: .methodNotAllowed)
            }
        }

        return router
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
        let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
        let isDir = attrs?.isDirectory ?? false
        let size  = attrs?.fileSize ?? 0
        let mtime = (attrs?.contentModificationDate).map {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            fmt.timeZone = TimeZone(abbreviation: "GMT")
            return fmt.string(from: $0)
        } ?? ""
        let href  = "/" + (url.path.hasPrefix(baseURL.path)
            ? String(url.path.dropFirst(baseURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            : url.lastPathComponent)
        let resourceType = isDir ? "<D:collection/>" : ""

        return """
            <D:response>
                <D:href>\(href.xmlEscaped)</D:href>
                <D:propstat>
                    <D:prop>
                        <D:resourcetype>\(resourceType)</D:resourcetype>
                        <D:getcontentlength>\(size)</D:getcontentlength>
                        <D:getlastmodified>\(mtime)</D:getlastmodified>
                    </D:prop>
                    <D:status>HTTP/1.1 200 OK</D:status>
                </D:propstat>
            </D:response>
        """
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
        let resolved = baseDir.appendingPathComponent(rawPath).standardized
        let basePath = baseDir.standardized.path
        guard resolved.path == basePath || resolved.path.hasPrefix(basePath + "/") else {
            return nil
        }
        return resolved
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

    static func fileManagerHTML(uploadDirectory: URL) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Provenance — Web File Manager</title>
          <style>
            :root { color-scheme: light dark; }
            body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                   max-width: 900px; margin: 0 auto; padding: 20px;
                   background: #f2f2f7; color: #1c1c1e; }
            @media (prefers-color-scheme: dark) {
              body { background: #1c1c1e; color: #f2f2f7; }
              .card { background: #2c2c2e; }
              table { background: #2c2c2e; }
              tr:nth-child(even) { background: #3a3a3c; }
            }
            h1 { font-size: 1.6rem; font-weight: 700; margin-bottom: 4px; }
            .subtitle { color: #8e8e93; margin-bottom: 24px; font-size: 0.9rem; }
            .card { background: #fff; border-radius: 12px; padding: 20px;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin-bottom: 20px; }
            .drop-zone { border: 2px dashed #007aff; border-radius: 10px;
                         padding: 32px; text-align: center; cursor: pointer; transition: background 0.2s; }
            .drop-zone.hover { background: rgba(0,122,255,0.08); }
            .drop-zone p { margin: 8px 0; color: #8e8e93; font-size: 0.9rem; }
            .btn { display: inline-block; padding: 10px 20px; border-radius: 8px;
                   background: #007aff; color: #fff; border: none; cursor: pointer;
                   font-size: 0.95rem; font-weight: 600; margin-top: 10px; }
            .btn:hover { background: #0062cc; }
            #progress-bar { width: 100%; height: 6px; background: #e5e5ea;
                            border-radius: 3px; margin-top: 12px; display: none; }
            #progress-fill { height: 100%; background: #007aff; border-radius: 3px;
                             width: 0%; transition: width 0.2s; }
            #status { margin-top: 8px; font-size: 0.85rem; color: #8e8e93; }
            table { width: 100%; border-collapse: collapse; border-radius: 10px; overflow: hidden; }
            th { text-align: left; padding: 10px 14px; font-size: 0.8rem; font-weight: 600;
                 color: #8e8e93; text-transform: uppercase; letter-spacing: 0.5px; }
            td { padding: 10px 14px; font-size: 0.9rem; border-top: 1px solid #f2f2f7; }
            @media (prefers-color-scheme: dark) { td { border-top-color: #3a3a3c; } }
            .del-btn { background: none; border: none; color: #ff3b30; cursor: pointer;
                       font-size: 0.85rem; padding: 4px 8px; border-radius: 6px; }
            .del-btn:hover { background: rgba(255,59,48,0.1); }
            .empty { color: #8e8e93; text-align: center; padding: 24px; font-size: 0.9rem; }
          </style>
        </head>
        <body>
          <h1>🎮 Provenance</h1>
          <p class="subtitle">Web File Manager — upload ROMs and BIOS files directly from your browser</p>

          <div class="card">
            <h2 style="margin-top:0;font-size:1.1rem">Upload Files</h2>
            <div class="drop-zone" id="drop-zone">
              <svg width="40" height="40" fill="#007aff" viewBox="0 0 24 24">
                <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/>
              </svg>
              <p>Drag &amp; drop ROM files here</p>
              <p>or</p>
              <button class="btn" onclick="document.getElementById('file-input').click()">Choose Files</button>
              <input type="file" id="file-input" multiple style="display:none">
            </div>
            <div id="progress-bar"><div id="progress-fill"></div></div>
            <div id="status"></div>
          </div>

          <div class="card">
            <h2 style="margin-top:0;font-size:1.1rem">Files in Imports/</h2>
            <table id="file-table">
              <thead><tr><th>Name</th><th>Size</th><th>Modified</th><th></th></tr></thead>
              <tbody id="file-list"><tr><td colspan="4" class="empty">Loading…</td></tr></tbody>
            </table>
          </div>

          <script>
            // File listing
            async function loadFiles() {
              try {
                const res = await fetch('/files');
                const items = await res.json();
                const tbody = document.getElementById('file-list');
                if (!items.length) {
                  tbody.innerHTML = '<tr><td colspan="4" class="empty">No files yet — upload some ROMs!</td></tr>';
                  return;
                }
                tbody.innerHTML = items.map(f => `
                  <tr>
                    <td>${esc(f.name)}</td>
                    <td>${fmtSize(f.size)}</td>
                    <td>${f.modified ? new Date(f.modified).toLocaleString() : ''}</td>
                    <td><button class="del-btn" data-name="${esc(f.name)}">Delete</button></td>
                  </tr>`).join('');
              } catch(e) { console.error(e); }
            }

            async function deleteFile(name) {
              if (!confirm('Delete ' + name + '?')) return;
              await fetch('/files/' + encodeURIComponent(name), { method: 'DELETE' });
              loadFiles();
            }

            function esc(s) { return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#x27;'); }
            function fmtSize(b) {
              if (b < 1024) return b + ' B';
              if (b < 1024*1024) return (b/1024).toFixed(1) + ' KB';
              return (b/1024/1024).toFixed(1) + ' MB';
            }

            // Drag & drop
            const zone = document.getElementById('drop-zone');
            zone.addEventListener('dragover', e => { e.preventDefault(); zone.classList.add('hover'); });
            zone.addEventListener('dragleave', () => zone.classList.remove('hover'));
            zone.addEventListener('drop', e => { e.preventDefault(); zone.classList.remove('hover'); uploadFiles(e.dataTransfer.files); });
            document.getElementById('file-input').addEventListener('change', e => uploadFiles(e.target.files));

            async function uploadFiles(files) {
              const bar = document.getElementById('progress-bar');
              const fill = document.getElementById('progress-fill');
              const status = document.getElementById('status');
              bar.style.display = 'block';
              for (let i = 0; i < files.length; i++) {
                const f = files[i];
                status.textContent = `Uploading ${f.name} (${i+1}/${files.length})…`;
                fill.style.width = (i / files.length * 100) + '%';
                const fd = new FormData();
                fd.append('files[]', f, f.name);
                const xhr = new XMLHttpRequest();
                await new Promise(resolve => {
                  xhr.upload.onprogress = e => {
                    if (e.lengthComputable) fill.style.width = ((i + e.loaded/e.total) / files.length * 100) + '%';
                  };
                  xhr.onload = resolve;
                  xhr.open('POST', '/upload');
                  xhr.send(fd);
                });
              }
              fill.style.width = '100%';
              status.textContent = `Done! ${files.length} file(s) uploaded.`;
              setTimeout(() => { bar.style.display='none'; fill.style.width='0%'; status.textContent=''; }, 3000);
              loadFiles();
            }

            // Use event delegation for delete buttons (avoids inline JS / XSS)
            document.getElementById('file-list').addEventListener('click', async (e) => {
                const btn = e.target.closest('.del-btn');
                if (!btn) return;
                const name = btn.dataset.name;
                if (name) await deleteFile(name);
            });

            loadFiles();
          </script>
        </body>
        </html>
        """
    }
}

// MARK: - String+XML

private extension String {
    var xmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
