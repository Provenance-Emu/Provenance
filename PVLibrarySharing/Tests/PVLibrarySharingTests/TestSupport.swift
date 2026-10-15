//
//  TestSupport.swift
//  PVLibrarySharingTests
//
//  Fixtures (Fixtures/*.json): neither peer app's test suite has literal JSON
//  (both round-trip through their own codecs), so the fixtures were written by
//  hand from the Swift field lists:
//  - ifly-library-manifest.json: iFly `ContinuityLibraryManifest`
//    (ContinuityKit/Model/ContinuityLibraryManifest.swift), as a plain
//    JSONEncoder writes it (dates as seconds since 2001, nil fields omitted).
//  - icube-library-catalog.json: iCube `ContinuityLibraryCatalog` + `GameIdentity`
//    (PVContinuity/Model/), sorted keys as iCube's encoder writes them; keys
//    follow `GameIdentity.stableKey`.
//  GUESSED (values, not field names): the "GameCube" platform spelling on the
//  third iCube entry (the spec says the coordinator reports it; the catalog
//  code emits gc/wii), the "System SP" iFly platform (an unmapped value for the
//  not-supported path), and every title, size and hash.
//

import CryptoKit
import Foundation
import XCTest
@testable import PVLibrarySharing

enum Fixture {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}

/// Scripted HTTP: responses are queued per path; the last one repeats.
/// Every request is recorded.
final class MockTransport: LibraryHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var scripted: [String: [LibraryHTTPResponse]] = [:]
    private var unreachableHosts: Set<String> = []
    private var handlers: [String: @Sendable (LibraryHTTPRequest) -> LibraryHTTPResponse] = [:]
    private(set) var requests: [LibraryHTTPRequest] = []

    /// Answers every request to `path` with `handler`, ahead of scripted responses.
    func handle(_ path: String, _ handler: @escaping @Sendable (LibraryHTTPRequest) -> LibraryHTTPResponse) {
        lock.lock()
        defer { lock.unlock() }
        handlers[path] = handler
    }

    func script(_ path: String, _ responses: LibraryHTTPResponse...) {
        lock.lock()
        defer { lock.unlock() }
        scripted[path, default: []].append(contentsOf: responses)
    }

    func makeUnreachable(host: String) {
        lock.lock()
        defer { lock.unlock() }
        unreachableHosts.insert(host)
    }

    func requests(to path: String) -> [LibraryHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests.filter { $0.url.path == path }
    }

    func send(_ request: LibraryHTTPRequest) async throws -> LibraryHTTPResponse {
        try respond(to: request)
    }

    private func respond(to request: LibraryHTTPRequest) throws -> LibraryHTTPResponse {
        lock.lock()
        defer { lock.unlock() }
        if let host = request.url.host, unreachableHosts.contains(host) {
            throw URLError(.cannotConnectToHost)
        }
        requests.append(request)
        let path = request.url.path
        if let handler = handlers[path] {
            return handler(request)
        }
        guard var queue = scripted[path], let next = queue.first else {
            return LibraryHTTPResponse(status: 599)
        }
        if queue.count > 1 {
            queue.removeFirst()
            scripted[path] = queue
        }
        return next
    }
}

extension LibraryHTTPResponse {
    static func json<T: Encodable>(_ value: T, status: Int = 200, headers: [String: String] = [:]) -> LibraryHTTPResponse {
        // Test payloads are plain Codable structs; encoding cannot fail.
        // swiftlint:disable:next force_try
        LibraryHTTPResponse(status: status, headers: headers, body: try! JSONEncoder().encode(value))
    }

    static func status(_ code: Int) -> LibraryHTTPResponse {
        LibraryHTTPResponse(status: code, body: Data(#"{"error":"scripted"}"#.utf8))
    }
}

enum TestPaths {
    static let authStart = "/api/continuity/library/auth/start"
    static let authComplete = "/api/continuity/library/auth/complete"
    static let iFlyManifest = "/api/continuity/library/manifest"
    static let iCubeCatalog = "/api/continuity/library/catalog"
    static let art = "/api/continuity/library/art"
    static let pairStart = "/api/continuity/pair/start"
    static let pairComplete = "/api/continuity/pair/complete"
    static let iFlyPull = "/api/continuity/library/pull"
    static let iCubeManifest = "/api/continuity/library/manifest"
    static let file = "/api/continuity/library/file"
}

extension LibraryHTTPRequest {
    func queryValue(_ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}

/// A file host for the library file route: serves `files[path]`, honouring
/// `Range: bytes=N-` unless `ignoresRange`.
final class FileHost: @unchecked Sendable {
    private let lock = NSLock()
    private var files: [String: Data]
    var ignoresRange = false
    /// Statuses returned (once each, in order) before serving normally.
    var interruptions: [Int] = []
    /// Bytes to send before "dropping the connection" on the next serve (once).
    var truncateNextTo: Int?

    init(files: [String: Data]) {
        self.files = files
    }

    func respond(_ request: LibraryHTTPRequest) -> LibraryHTTPResponse {
        lock.lock()
        defer { lock.unlock() }
        if !interruptions.isEmpty {
            return .status(interruptions.removeFirst())
        }
        guard let path = request.queryValue("path"), let data = files[path] else {
            return .status(404)
        }
        var body = data
        var status = 200
        var headers: [String: String] = ["Accept-Ranges": "bytes"]
        if !ignoresRange, let range = request.headers["Range"], range.hasPrefix("bytes="),
           let start = Int(range.dropFirst("bytes=".count).dropLast()) {
            guard start < data.count else { return .status(416) }
            body = data.subdata(in: start..<data.count)
            status = 206
            headers["Content-Range"] = "bytes \(start)-\(data.count - 1)/\(data.count)"
        }
        if let cut = truncateNextTo {
            truncateNextTo = nil
            body = body.prefix(cut)
        }
        return LibraryHTTPResponse(status: status, headers: headers, body: body)
    }
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// A fresh empty folder under the temporary directory.
func makeTemporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PVLibrarySharingTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Decodes a request's JSON body as a loose dictionary.
func jsonObject(_ request: LibraryHTTPRequest) throws -> [String: Any] {
    let body = try XCTUnwrap(request.body)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
}
