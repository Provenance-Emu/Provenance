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
}

/// URLSession transport with a short timeout: a peer's `u0..u3` candidates
/// are tried in turn, and a dead candidate must not stall the browse for
/// URLSession's default 60 s.
public struct URLSessionLibraryTransport: LibraryHTTPTransport {
    public static let defaultTimeout: TimeInterval = 8

    private let session: URLSession
    private let timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = URLSessionLibraryTransport.defaultTimeout) {
        self.session = session
        self.timeout = timeout
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
