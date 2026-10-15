//
//  LibraryHTTPTransport.swift
//  PVLibrarySharing
//
//  The HTTP seam: URLSession in the app, scripted responses in tests.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct LibraryHTTPRequest: Sendable, Equatable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data?

    public init(url: URL, method: String = "GET", headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }

    /// A JSON POST, `Data` fields encoded as base64 (Codable's default, which
    /// both peer apps use).
    static func jsonPost<Body: Encodable>(url: URL, body: Body) throws -> LibraryHTTPRequest {
        LibraryHTTPRequest(
            url: url,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(body)
        )
    }

    /// A GET carrying a library bearer token.
    static func authorizedGet(url: URL, token: String) -> LibraryHTTPRequest {
        LibraryHTTPRequest(url: url, headers: ["Authorization": "Bearer \(token)"])
    }
}

public struct LibraryHTTPResponse: Sendable, Equatable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// Case-insensitive header lookup.
    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

public protocol LibraryHTTPTransport: Sendable {
    func send(_ request: LibraryHTTPRequest) async throws -> LibraryHTTPResponse

    /// Downloads `request` into `file`, resuming at `resumeOffset`.
    ///
    /// Sends `Range: bytes=<resumeOffset>-` when the offset is positive. What
    /// lands in `file` is decided by `DownloadSink`; non-2xx answers leave the
    /// file untouched. `progress` gets the file's total bytes on disk.
    func download(
        _ request: LibraryHTTPRequest,
        to file: URL,
        resumeOffset: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> LibraryDownloadResponse
}

public extension LibraryHTTPTransport {
    /// Buffered fallback over `send`, for transports that can't stream (test
    /// doubles). Follows the same rules as the streaming path.
    func download(
        _ request: LibraryHTTPRequest,
        to file: URL,
        resumeOffset: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> LibraryDownloadResponse {
        let response = try await send(DownloadSink.ranged(request, resumeOffset: resumeOffset))
        var sink = DownloadSink(file: file, resumeOffset: resumeOffset)
        try sink.begin(status: response.status, headers: response.headers)
        try sink.append(response.body)
        let result = try sink.finish()
        progress(sink.bytesOnDisk)
        return result
    }
}

/// The result of a download. `writtenFrom` is where the bytes were written:
/// `0` when the server sent the whole file (a 200, even to a ranged request),
/// the resume offset on a matching 206, and nil when nothing was written
/// (an error status, or a 206 for a range that wasn't asked for).
public struct LibraryDownloadResponse: Sendable, Equatable {
    public var status: Int
    public var headers: [String: String]
    public var writtenFrom: Int64?
    /// The file's size on disk afterwards.
    public var bytesOnDisk: Int64
    /// The response body of a non-2xx answer, for diagnostics.
    public var errorBody: Data

    public init(status: Int, headers: [String: String] = [:], writtenFrom: Int64?, bytesOnDisk: Int64, errorBody: Data = Data()) {
        self.status = status
        self.headers = headers
        self.writtenFrom = writtenFrom
        self.bytesOnDisk = bytesOnDisk
        self.errorBody = errorBody
    }
}

/// Writes a download's body into a `.part` file, deciding from the status
/// where the bytes go. Shared by the streaming and buffered paths so both obey
/// the same resume rules:
///
/// - 206 whose `Content-Range` starts at the resume offset: append there.
/// - 200: the server ignored the range and sends everything, so truncate to
///   zero first. Appending would give a file of the right length with the
///   wrong bytes (ECS `ResumePlanner` and both peers' pullers agree).
/// - Anything else, including a 206 for another range: write nothing.
struct DownloadSink {
    let file: URL
    let resumeOffset: Int64
    private(set) var status = 0
    private(set) var headers: [String: String] = [:]
    private(set) var writtenFrom: Int64?
    private(set) var bytesOnDisk: Int64 = 0
    private var handle: FileHandle?
    private var errorBody = Data()

    /// Error bodies are small JSON; cap what is kept of a misbehaving one.
    private static let maxErrorBody = 16 * 1024

    init(file: URL, resumeOffset: Int64) {
        self.file = file
        self.resumeOffset = resumeOffset
    }

    static func ranged(_ request: LibraryHTTPRequest, resumeOffset: Int64) -> LibraryHTTPRequest {
        var request = request
        if resumeOffset > 0 {
            request.headers["Range"] = "bytes=\(resumeOffset)-"
        }
        return request
    }

    /// The first byte of a `Content-Range: bytes S-E/T` value.
    static func contentRangeStart(_ value: String?) -> Int64? {
        guard let value, value.hasPrefix("bytes ") else { return nil }
        let spec = value.dropFirst("bytes ".count)
        guard let dash = spec.firstIndex(of: "-") else { return nil }
        return Int64(spec[spec.startIndex..<dash])
    }

    mutating func begin(status: Int, headers: [String: String]) throws {
        self.status = status
        self.headers = headers
        let start: Int64?
        switch status {
        case 200:
            start = 0
        case 206:
            let rangeHeader = headers.first { $0.key.caseInsensitiveCompare("Content-Range") == .orderedSame }?.value
            start = Self.contentRangeStart(rangeHeader) == resumeOffset ? resumeOffset : nil
        default:
            start = nil
        }
        guard let start else { return }
        let manager = FileManager.default
        if !manager.fileExists(atPath: file.path) {
            guard manager.createFile(atPath: file.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: file.path])
            }
        }
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(start))
        try handle.seekToEnd()
        self.handle = handle
        writtenFrom = start
        bytesOnDisk = start
    }

    mutating func append(_ data: Data) throws {
        guard !data.isEmpty else { return }
        if let handle {
            try handle.write(contentsOf: data)
            bytesOnDisk += Int64(data.count)
        } else if errorBody.count < Self.maxErrorBody {
            errorBody.append(data.prefix(Self.maxErrorBody - errorBody.count))
        }
    }

    /// Closes the file. Safe to call after a failure: what was written stays,
    /// so the next attempt resumes from it.
    mutating func close() {
        try? handle?.close()
        handle = nil
    }

    mutating func finish() throws -> LibraryDownloadResponse {
        if let handle {
            try handle.synchronize()
            try handle.close()
            self.handle = nil
        }
        return LibraryDownloadResponse(
            status: status, headers: headers, writtenFrom: writtenFrom,
            bytesOnDisk: bytesOnDisk, errorBody: errorBody
        )
    }
}

/// URLSession transport with a short timeout: a peer's `u0..u3` candidates
/// are tried in turn, and a dead candidate must not stall the browse for
/// URLSession's default 60 s.
///
/// File downloads use `downloadIdleTimeout` instead: a multi-gigabyte image
/// over weak Wi-Fi can pause for longer than a browse request may take, and
/// only a stall (no bytes at all for that long) should end it.
public struct URLSessionLibraryTransport: LibraryHTTPTransport {
    public static let defaultTimeout: TimeInterval = 8
    public static let defaultDownloadIdleTimeout: TimeInterval = 60

    private let session: URLSession
    private let timeout: TimeInterval
    private let downloadIdleTimeout: TimeInterval

    public init(
        session: URLSession = .shared,
        timeout: TimeInterval = URLSessionLibraryTransport.defaultTimeout,
        downloadIdleTimeout: TimeInterval = URLSessionLibraryTransport.defaultDownloadIdleTimeout
    ) {
        self.session = session
        self.timeout = timeout
        self.downloadIdleTimeout = downloadIdleTimeout
    }

    public func download(
        _ request: LibraryHTTPRequest,
        to file: URL,
        resumeOffset: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> LibraryDownloadResponse {
        let ranged = DownloadSink.ranged(request, resumeOffset: resumeOffset)
        var urlRequest = URLRequest(url: ranged.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: downloadIdleTimeout)
        urlRequest.httpMethod = ranged.method
        urlRequest.httpBody = ranged.body
        for (name, value) in ranged.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let delegate = StreamingDownloadDelegate(sink: DownloadSink(file: file, resumeOffset: resumeOffset), progress: progress)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = downloadIdleTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let downloadSession = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { downloadSession.finishTasksAndInvalidate() }
        let task = downloadSession.dataTask(with: urlRequest)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.start(task, continuation: continuation)
            }
        } onCancel: {
            task.cancel()
        }
    }

    public func send(_ request: LibraryHTTPRequest) async throws -> LibraryHTTPResponse {
        var urlRequest = URLRequest(url: request.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw LibrarySharingError.invalidResponse(status: 0)
        }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        return LibraryHTTPResponse(status: http.statusCode, headers: headers, body: data)
    }
}

/// Streams a data task's body through a `DownloadSink` as it arrives, so a
/// gigabyte image never sits in memory.
private final class StreamingDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    // Touched only from the session's serial delegate queue, and `start`
    // before the task resumes.
    private var sink: DownloadSink
    private var failure: Error?
    private var continuation: CheckedContinuation<LibraryDownloadResponse, Error>?
    private let progress: @Sendable (Int64) -> Void

    init(sink: DownloadSink, progress: @escaping @Sendable (Int64) -> Void) {
        self.sink = sink
        self.progress = progress
    }

    func start(_ task: URLSessionDataTask, continuation: CheckedContinuation<LibraryDownloadResponse, Error>) {
        self.continuation = continuation
        task.resume()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            failure = LibrarySharingError.invalidResponse(status: 0)
            completionHandler(.cancel)
            return
        }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        do {
            try sink.begin(status: http.statusCode, headers: headers)
            completionHandler(.allow)
        } catch {
            failure = error
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard failure == nil else { return }
        do {
            try sink.append(data)
            progress(sink.bytesOnDisk)
        } catch {
            failure = error
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let continuation = self.continuation
        self.continuation = nil
        if let failure = failure ?? error {
            // Keep what arrived: the next attempt resumes from it.
            sink.close()
            if (failure as? URLError)?.code == .cancelled {
                continuation?.resume(throwing: CancellationError())
            } else {
                continuation?.resume(throwing: failure)
            }
            return
        }
        do {
            let result = try sink.finish()
            progress(result.bytesOnDisk)
            continuation?.resume(returning: result)
        } catch {
            continuation?.resume(throwing: error)
        }
    }
}
