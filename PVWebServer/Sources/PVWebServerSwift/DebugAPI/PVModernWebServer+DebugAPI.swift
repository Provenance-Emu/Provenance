//
//  PVModernWebServer+DebugAPI.swift
//  PVWebServer
//
//  Mounts `/api/debug/*` on the HTTP router. Only mounted when
//  `PVDebugAPIPrefs.isEnabled` (DEBUG builds, or the hidden Release toggle);
//  every request is checked against `PVDebugAPIPrefs.isAuthorized` and then
//  dispatched to whatever PVUIBase registered in `PVDebugAPIRegistry`.
//

import Foundation
import HTTPTypes
import Hummingbird
import PVLogging

extension PVModernWebServer {

    /// Max JSON body accepted by a debug route.
    private static let debugAPIMaxBody = 1 * 1_024 * 1_024

    func registerDebugAPIRoutes(on router: Router<BasicRequestContext>) {
        guard PVDebugAPIPrefs.isEnabled else { return }
        ILOG("[PVModernWebServer] Debug API enabled (auth: \(PVDebugAPIPrefs.authEnabled))")

        let dispatch: @Sendable (Request, BasicRequestContext) async throws -> Response = { request, _ in
            try await Self.dispatchDebugAPI(request)
        }
        router.get("/api/debug", use: dispatch)
        router.get("/api/debug/**", use: dispatch)
        router.post("/api/debug/**", use: dispatch)
    }

    private static func dispatchDebugAPI(_ request: Request) async throws -> Response {
        guard PVDebugAPIPrefs.isAuthorized(
            header: request.headers[.authorization],
            authEnabled: PVDebugAPIPrefs.authEnabled,
            password: PVDebugAPIPrefs.password
        ) else {
            var headers: HTTPFields = [.contentType: "application/json"]
            headers[.wwwAuthenticate] = "Basic realm=\"Provenance Debug API\""
            let body = Data(#"{"ok":false,"error":"unauthorized"}"#.utf8)
            return Response(status: .unauthorized, headers: headers, body: .init(byteBuffer: ByteBuffer(bytes: body)))
        }

        let method = request.method.rawValue
        let path = request.uri.path.count > 1 && request.uri.path.hasSuffix("/")
            ? String(request.uri.path.dropLast())
            : request.uri.path

        if path == "/api/debug" {
            return Self.debugResponse(.ok(["routes": PVDebugAPIRegistry.shared.routes]))
        }

        guard let handler = PVDebugAPIRegistry.shared.handler(method: method, path: path) else {
            return Self.debugResponse(.error("no debug route \(method) \(path)", status: 404))
        }

        var body: Data?
        if request.method == .post {
            let buffer = try await request.body.collect(upTo: debugAPIMaxBody)
            body = buffer.withUnsafeReadableBytes { Data($0) }
        }

        let debugRequest = PVDebugAPIRequest(
            method: method,
            path: path,
            query: Self.allQueryParameters(from: request),
            body: body
        )
        return Self.debugResponse(await handler(debugRequest))
    }

    private static func debugResponse(_ response: PVDebugAPIResponse) -> Response {
        Response(
            status: HTTPResponse.Status(code: response.status),
            headers: [.contentType: response.contentType, .cacheControl: "no-store"],
            body: .init(byteBuffer: ByteBuffer(bytes: response.body))
        )
    }

    private static func allQueryParameters(from request: Request) -> [String: String] {
        let uriString = String(describing: request.uri)
        guard let components = URLComponents(string: uriString.hasPrefix("http") ? uriString : "http://x" + uriString),
              let items = components.queryItems else { return [:] }
        var query: [String: String] = [:]
        for item in items {
            query[item.name] = item.value ?? ""
        }
        return query
    }
}
