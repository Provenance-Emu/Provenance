//
//  PVHostedWebServer+DebugAPI.swift
//  PVWebServerHost
//
//  Mounts `/api/debug/*`. Only mounted when `PVDebugAPIPrefs.isEnabled` (DEBUG builds, or the
//  hidden Release toggle); every request is checked against `PVDebugAPIPrefs.isAuthorized`
//  and then dispatched to whatever PVUIBase registered in `PVDebugAPIRegistry`.
//

import Foundation
import PVLogging
import PVWebServer

/// Who may reach `/api/debug/*`, and what they reach.
struct DebugAPIAccess {
    let registry: PVDebugAPIRegistry
    /// Asked per request, so changing the password needs no restart.
    let isAuthorized: @Sendable (WebRouteRequest) -> Bool

    /// `nil` unless the debug API is on.
    static func fromPreferences() -> DebugAPIAccess? {
        guard PVDebugAPIPrefs.isEnabled else { return nil }
        ILOG("[PVHostedWebServer] Debug API enabled (auth: \(PVDebugAPIPrefs.authEnabled))")
        return DebugAPIAccess(registry: .shared) { request in
            PVDebugAPIPrefs.isAuthorized(
                header: request.header("Authorization"),
                authEnabled: PVDebugAPIPrefs.authEnabled,
                password: PVDebugAPIPrefs.password
            )
        }
    }
}

extension PVHostedWebServer {

    /// Max JSON body accepted by a debug route.
    private static let debugAPIMaxBody = 1 * 1_024 * 1_024
    private static let debugAPIIndex = "/api/debug"
    /// Every method a client might send. An unrouted method would fall through to WebDAV and be
    /// answered from a folder named `api/debug` under the root.
    private static let debugAPIMethods = ["GET", "POST", "PUT", "PATCH", "DELETE"]

    /// One route covers the index and everything below it, so a client is refused the same way
    /// whether or not a path exists, and routes PVUIBase registers later need no mounting.
    func mountDebugAPI(_ access: DebugAPIAccess) {
        let handler: WebRouteHandler = { request in await Self.dispatchDebugAPI(request, access: access) }
        for method in Self.debugAPIMethods {
            engine.addAsyncHandler(forMethod: method, path: Self.debugAPIIndex, handler: handler)
            engine.addAsyncHandler(forMethod: method, pathPrefix: Self.debugAPIIndex, handler: handler)
        }
    }

    private static func dispatchDebugAPI(
        _ request: WebRouteRequest,
        access: DebugAPIAccess
    ) async -> WebRouteResponse {
        guard access.isAuthorized(request) else {
            return WebRouteResponse(
                status: 401,
                headers: ["WWW-Authenticate": "Basic realm=\"Provenance Debug API\""],
                body: .data(Data(#"{"ok":false,"error":"unauthorized"}"#.utf8))
            )
        }

        let method = request.method.uppercased()
        let path = request.path.count > 1 && request.path.hasSuffix("/") ? String(request.path.dropLast()) : request.path
        if path == debugAPIIndex, method == "GET" {
            return debugResponse(.ok(["routes": access.registry.routes]))
        }
        guard let handler = access.registry.handler(method: method, path: path) else {
            return debugResponse(.error("no debug route \(method) \(path)", status: 404))
        }
        guard (request.body?.count ?? 0) <= debugAPIMaxBody else {
            return debugResponse(.error("body too large", status: 413))
        }
        let debugRequest = PVDebugAPIRequest(
            method: method,
            path: path,
            query: request.query,
            body: method == "POST" ? (request.body ?? Data()) : nil
        )
        return debugResponse(await handler(debugRequest))
    }

    private static func debugResponse(_ response: PVDebugAPIResponse) -> WebRouteResponse {
        WebRouteResponse(
            status: response.status,
            contentType: response.contentType,
            headers: ["Cache-Control": "no-store"],
            body: .data(response.body)
        )
    }
}
