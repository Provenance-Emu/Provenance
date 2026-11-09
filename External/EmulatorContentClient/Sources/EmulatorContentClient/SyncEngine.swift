import Foundation

/// A way to perform one HTTP request. Production uses `URLSession`; tests supply a scripted one.
public protocol ContentTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// `URLSession.shared`, which is available on iOS and tvOS.
public struct URLSessionTransport: ContentTransport {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncFailure(status: 0, message: "The server did not answer over HTTP")
        }
        return (data, http)
    }
}

/// A request the server refused. The token is never part of the message.
public struct SyncFailure: Error, Equatable, Sendable {
    public let status: Int
    public let message: String

    public init(status: Int, message: String) {
        self.status = status
        self.message = message
    }
}

/// The app-neutral sync calls: the change feed, choosing a save, and the requests that resume a transfer.
///
/// Bytes stay with the caller. This type builds the request and reads the JSON, and a download body is
/// left on the response the caller opens, so the same code serves a phone and a television.
public struct ContentSync: Sendable {
    private let baseURL: URL
    private let token: String
    private let transport: any ContentTransport

    public init(baseURL: URL, token: String, transport: any ContentTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    /// One page of the feed. `excludeOwnDevice` omits the changes this device token caused.
    public func changes(cursor: String, limit: Int? = nil, excludeOwnDevice: Bool = false) async throws -> ChangeList {
        let request = SyncRequests.changes(
            baseURL: baseURL,
            token: token,
            cursor: cursor,
            limit: limit,
            excludeOwnDevice: excludeOwnDevice
        )
        return try await send(request)
    }

    /// Pages from `cursor` until a page adds nothing, which is how a client catches up.
    public func changePages(from cursor: String, limit: Int? = nil, excludeOwnDevice: Bool = false) -> AsyncThrowingStream<ChangeList, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var cursor = cursor
                do {
                    while !Task.isCancelled {
                        let page = try await changes(cursor: cursor, limit: limit, excludeOwnDevice: excludeOwnDevice)
                        continuation.yield(page)
                        if page.changes.isEmpty || page.nextCursor == cursor {
                            continuation.finish()
                            return
                        }
                        cursor = page.nextCursor
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Makes a conflict copy the live save. The bytes it replaces stay on the server.
    public func adopt(assetId: String) async throws -> Asset {
        try await send(SyncRequests.adopt(baseURL: baseURL, token: token, assetId: assetId))
    }

    /// The offset the server has committed for an upload, which is where a retry continues.
    public func receivedOffset(uploadId: String) async throws -> Int64 {
        let session: UploadSession = try await send(
            SyncRequests.upload(baseURL: baseURL, token: token, uploadId: uploadId)
        )
        return session.received
    }

    /// The request for an asset from `localBytes` onward. The caller reads the body.
    public func contentRequest(assetId: String, localBytes: Int64, etag: String?) -> URLRequest {
        SyncRequests.content(
            baseURL: baseURL,
            token: token,
            assetId: assetId,
            localBytes: localBytes,
            etag: etag
        )
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await transport.data(for: request)
        guard (200 ..< 300).contains(response.statusCode) else {
            let title = (try? JSONDecoder().decode(ProblemTitle.self, from: data))?.title
            throw SyncFailure(status: response.statusCode, message: title ?? "Content request failed")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// Request shapes shared by the engine and its tests, so a header can be asserted without a server.
public enum SyncRequests {
    public static func changes(baseURL: URL, token: String, cursor: String, limit: Int?, excludeOwnDevice: Bool) -> URLRequest {
        var parts = ["cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"]
        if let limit {
            parts.append("limit=\(limit)")
        }
        if excludeOwnDevice {
            parts.append("excludeOwnDevice=1")
        }
        return authorized(baseURL: baseURL, token: token, path: "/api/v1/changes?\(parts.joined(separator: "&"))")
    }

    public static func adopt(baseURL: URL, token: String, assetId: String) -> URLRequest {
        var request = authorized(baseURL: baseURL, token: token, path: "/api/v1/files/\(assetId)/adopt")
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    public static func upload(baseURL: URL, token: String, uploadId: String) -> URLRequest {
        authorized(baseURL: baseURL, token: token, path: "/api/v1/uploads/\(uploadId)")
    }

    public static func content(baseURL: URL, token: String, assetId: String, localBytes: Int64, etag: String?) -> URLRequest {
        var request = authorized(baseURL: baseURL, token: token, path: "/api/v1/files/\(assetId)/content")
        let plan = ResumePlan.plan(localBytes: localBytes, totalBytes: nil)
        if let range = plan.range {
            request.setValue(range, forHTTPHeaderField: "Range")
            if let etag {
                request.setValue(etag, forHTTPHeaderField: "If-Range")
            }
        }
        return request
    }

    private static func authorized(baseURL: URL, token: String, path: String) -> URLRequest {
        let url = URL(string: path, relativeTo: baseURL) ?? baseURL
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

private struct ProblemTitle: Decodable {
    let title: String
}
