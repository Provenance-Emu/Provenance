//
//  ServerHTTP.swift
//  PVLibrarySharing
//
//  The request and response types the dialect servers speak, plus the
//  HTTP/1.1 framing the listener needs. Small on purpose: peers send JSON
//  bodies and GETs, and the only large thing is a file body going out.
//

import Foundation

/// One parsed request.
public struct ServerRequest: Sendable, Equatable {
    public var method: String
    /// The path without the query, percent-decoded.
    public var path: String
    /// Query items, percent-decoded; the last value wins for a repeated name.
    public var query: [String: String]
    /// Header names lower-cased.
    public var headers: [String: String]
    public var body: Data?
    /// The peer's address, for logging.
    public var remoteAddress: String?

    public init(
        method: String,
        path: String,
        query: [String: String] = [:],
        headers: [String: String] = [:],
        body: Data? = nil,
        remoteAddress: String? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { $1 })
        self.body = body
        self.remoteAddress = remoteAddress
    }

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }
}

/// One response. A file body is streamed from disk by the listener.
public struct ServerResponse: Sendable, Equatable {
    public enum Body: Sendable, Equatable {
        case data(Data)
        /// `length` nil means to the end of the file.
        case file(URL, offset: Int64, length: Int64?)
    }

    public var status: Int
    public var headers: [String: String]
    public var body: Body

    public init(status: Int, headers: [String: String] = [:], body: Body = .data(Data())) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// `{"error": message}`, the shape both iFly and iCube use for every
    /// non-200 answer (`ContinuityHTTPResponse.error`, `WebRouteResponse.error`).
    public static func error(_ status: Int, _ message: String) -> ServerResponse {
        let payload = (try? JSONSerialization.data(withJSONObject: ["error": message])) ?? Data()
        return ServerResponse(status: status, headers: ["Content-Type": "application/json"], body: .data(payload))
    }

    public static func json(_ data: Data, status: Int = 200, headers: [String: String] = [:]) -> ServerResponse {
        var all = headers
        all["Content-Type"] = "application/json"
        return ServerResponse(status: status, headers: all, body: .data(data))
    }

    /// Encodes with a plain `JSONEncoder` (both peers decode `Data` as base64).
    public static func encoded<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) -> ServerResponse {
        guard let data = try? encoder.encode(value) else { return .error(500, "encoding failed") }
        return .json(data)
    }

    /// The body as data, for tests and small responses; nil for a file body.
    public var bodyData: Data? {
        if case .data(let data) = body { return data }
        return nil
    }
}

public typealias ServerRequestHandler = @Sendable (ServerRequest) async -> ServerResponse

/// HTTP/1.1 framing: request heads in, response heads out.
enum HTTP1 {
    /// Request heads larger than this are refused (431).
    static let maxHeadBytes = 16 * 1024
    /// Request bodies larger than this are refused (413). Peers send small JSON.
    static let maxBodyBytes = 1 << 20
    static let headTerminator = Data("\r\n\r\n".utf8)

    enum ParseError: Error, Equatable {
        case malformed
        case headTooLarge
        case bodyTooLarge
        /// Chunked request bodies aren't needed by any peer.
        case unsupportedTransferEncoding
    }

    struct Head: Equatable {
        var method: String
        var target: String
        var version: String
        var headers: [String: String]

        var contentLength: Int {
            Int(headers["content-length"] ?? "") ?? 0
        }

        /// HTTP/1.1 keeps the connection unless asked to close; 1.0 the reverse.
        var keepAlive: Bool {
            let connection = headers["connection"]?.lowercased() ?? ""
            if version == "HTTP/1.0" { return connection.contains("keep-alive") }
            return !connection.contains("close")
        }
    }

    /// Parses a request head (everything before the blank line).
    static func parseHead(_ data: Data) throws -> Head {
        guard data.count <= maxHeadBytes else { throw ParseError.headTooLarge }
        guard let text = String(data: data, encoding: .utf8) else { throw ParseError.malformed }
        var lines = text.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ", omittingEmptySubsequences: true)
        guard requestLine.count == 3, requestLine[2].hasPrefix("HTTP/1.") else { throw ParseError.malformed }
        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { throw ParseError.malformed }
            let name = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { throw ParseError.malformed }
            headers[name] = value
        }
        if let encoding = headers["transfer-encoding"], encoding.lowercased() != "identity" {
            throw ParseError.unsupportedTransferEncoding
        }
        let head = Head(method: String(requestLine[0]), target: String(requestLine[1]), version: String(requestLine[2]), headers: headers)
        guard head.contentLength >= 0 else { throw ParseError.malformed }
        guard head.contentLength <= maxBodyBytes else { throw ParseError.bodyTooLarge }
        return head
    }

    /// Splits a request target into a decoded path and query.
    static func split(target: String) -> (path: String, query: [String: String]) {
        guard let components = URLComponents(string: target) else { return (target, [:]) }
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            query[item.name] = item.value ?? ""
        }
        return (components.path, query)
    }

    static func request(head: Head, body: Data?, remoteAddress: String?) -> ServerRequest {
        let (path, query) = split(target: head.target)
        return ServerRequest(
            method: head.method, path: path, query: query, headers: head.headers,
            body: body, remoteAddress: remoteAddress
        )
    }

    /// The status line and headers of `response`, with `Content-Length` and
    /// `Connection` filled in.
    static func responseHead(_ response: ServerResponse, contentLength: Int64, keepAlive: Bool) -> Data {
        var lines = ["HTTP/1.1 \(response.status) \(reasonPhrase(response.status))"]
        var headers = response.headers
        headers["Content-Length"] = String(contentLength)
        headers["Connection"] = keepAlive ? "keep-alive" : "close"
        if headers["Content-Type"] == nil, contentLength > 0 {
            headers["Content-Type"] = "application/octet-stream"
        }
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) {
            lines.append("\(name): \(value)")
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }

    static func reasonPhrase(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 202: return "Accepted"
        case 206: return "Partial Content"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 410: return "Gone"
        case 413: return "Payload Too Large"
        case 416: return "Range Not Satisfiable"
        case 429: return "Too Many Requests"
        case 431: return "Request Header Fields Too Large"
        case 500: return "Internal Server Error"
        default: return "Status"
        }
    }
}

/// `Range: bytes=N-` and `bytes=N-M`, as both peers parse it
/// (`ByteRangeRequest`). Multi-range and suffix ranges parse as nil, so the
/// whole file is served, which is always correct.
public struct ByteRange: Sendable, Equatable {
    public var offset: Int64
    /// Inclusive end byte; nil for open-ended.
    public var end: Int64?

    public init(offset: Int64, end: Int64? = nil) {
        self.offset = offset
        self.end = end
    }

    public static func parse(_ header: String?) -> ByteRange? {
        guard let header, header.hasPrefix("bytes=") else { return nil }
        let spec = header.dropFirst("bytes=".count)
        guard !spec.contains(",") else { return nil }
        let parts = spec.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let start = Int64(parts[0]), start >= 0 else { return nil }
        if parts[1].isEmpty { return ByteRange(offset: start) }
        guard let end = Int64(parts[1]), end >= start else { return nil }
        return ByteRange(offset: start, end: end)
    }

    /// Bytes to serve from a file of `totalSize`, or nil when unsatisfiable.
    public func length(totalSize: Int64) -> Int64? {
        guard offset < totalSize else { return nil }
        return min(end ?? totalSize - 1, totalSize - 1) - offset + 1
    }

    public func contentRange(totalSize: Int64) -> String? {
        guard let length = length(totalSize: totalSize) else { return nil }
        return "bytes \(offset)-\(offset + length - 1)/\(totalSize)"
    }
}

extension ServerResponse {
    /// Serves `url` (of `size` bytes) honouring `Range`: 206 with
    /// `Content-Range`, 416 when unsatisfiable, else 200. Both peers' file
    /// routes answer exactly this way.
    static func file(_ url: URL, size: Int64, rangeHeader: String?) -> ServerResponse {
        let base = ["Content-Type": "application/octet-stream", "Accept-Ranges": "bytes"]
        guard let range = ByteRange.parse(rangeHeader) else {
            return ServerResponse(status: 200, headers: base, body: .file(url, offset: 0, length: size))
        }
        guard let length = range.length(totalSize: size), let contentRange = range.contentRange(totalSize: size) else {
            return .error(416, "range not satisfiable")
        }
        var headers = base
        headers["Content-Range"] = contentRange
        return ServerResponse(status: 206, headers: headers, body: .file(url, offset: range.offset, length: length))
    }
}
