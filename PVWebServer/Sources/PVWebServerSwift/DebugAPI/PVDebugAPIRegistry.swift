//
//  PVDebugAPIRegistry.swift
//  PVWebServer
//
//  Framework-agnostic handler table for `/api/debug/*`. PVWebServer can't see
//  the library, the emulator or navigation (it sits below them in the package
//  graph), so the real handlers are registered from PVUIBase
//  (`PVDebugAPIRoutes`) and `PVModernWebServer` looks them up at request
//  time — registration order vs. server start doesn't matter.
//

import Foundation

public struct PVDebugAPIRequest: Sendable {
    public let method: String
    public let path: String
    public let query: [String: String]
    public let body: Data?

    public init(method: String, path: String, query: [String: String], body: Data?) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }

    /// Decoded JSON object body, or `[:]` for an empty / non-object body.
    public var jsonBody: [String: Any] {
        guard let body, !body.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return [:] }
        return json
    }

    /// `name` from the query string, falling back to the JSON body.
    public func value(_ name: String) -> String? {
        if let value = query[name], !value.isEmpty { return value }
        switch jsonBody[name] {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }
}

public struct PVDebugAPIResponse: Sendable {
    public var status: Int
    public var contentType: String
    public var body: Data

    public init(status: Int = 200, contentType: String, body: Data) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

    /// `{"ok": true, "data": …}` envelope (iFly's shape).
    public static func ok(_ data: Any = [String: Any]()) -> PVDebugAPIResponse {
        json(["ok": true, "data": data])
    }

    /// `{"ok": false, "error": …}` envelope.
    public static func error(_ message: String, status: Int = 400) -> PVDebugAPIResponse {
        json(["ok": false, "error": message], status: status)
    }

    public static func json(_ object: Any, status: Int = 200) -> PVDebugAPIResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        return PVDebugAPIResponse(status: status, contentType: "application/json", body: data)
    }

    public static func png(_ data: Data) -> PVDebugAPIResponse {
        PVDebugAPIResponse(contentType: "image/png", body: data)
    }
}

public typealias PVDebugAPIHandler = @Sendable (PVDebugAPIRequest) async -> PVDebugAPIResponse

public final class PVDebugAPIRegistry: @unchecked Sendable {
    public static let shared = PVDebugAPIRegistry()

    private let lock = NSLock()
    private var handlers: [String: PVDebugAPIHandler] = [:]

    public init() {}

    private static func key(_ method: String, _ path: String) -> String {
        "\(method.uppercased()) \(path)"
    }

    /// Register (or replace) the handler for `method path`, e.g. `GET /api/debug/screenshot`.
    public func register(_ method: String, _ path: String, handler: @escaping PVDebugAPIHandler) {
        lock.lock(); defer { lock.unlock() }
        handlers[Self.key(method, path)] = handler
    }

    public func handler(method: String, path: String) -> PVDebugAPIHandler? {
        lock.lock(); defer { lock.unlock() }
        return handlers[Self.key(method, path)]
    }

    /// Sorted `"METHOD /path"` list, served by `GET /api/debug`.
    public var routes: [String] {
        lock.lock(); defer { lock.unlock() }
        return handlers.keys.sorted()
    }
}
