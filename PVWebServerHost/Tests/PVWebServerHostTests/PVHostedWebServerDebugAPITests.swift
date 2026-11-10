//
//  PVHostedWebServerDebugAPITests.swift
//  PVWebServerHostTests
//
//  `/api/debug/*` can drive the app, so no route may answer without authorization, including
//  routes registered after the server started.
//

import XCTest
@testable import PVWebServerHost

final class PVHostedWebServerDebugAPITests: LiveServerTestCase {

    func testNothingIsMountedWhenTheDebugAPIIsOff() async throws {
        let registry = PVDebugAPIRegistry()
        registry.register("GET", "/api/debug/ping") { _ in .ok(["pong": true]) }
        // `setUp` started the server without a debug API, and nothing connects this registry.
        for path in ["/api/debug", "/api/debug/ping"] {
            let result = try await send("GET", path)
            XCTAssertEqual(result.status, 404, path)
        }
    }

    func testDebugRoutesRequireAuthorizationPerRequest() async throws {
        let registry = PVDebugAPIRegistry()
        registry.register("POST", "/api/debug/echo") { request in .ok(["value": request.value("v") ?? ""]) }
        try await startServer(debugAPI: DebugAPIAccess(registry: registry) { $0.header("Authorization") == "Basic good" })

        for headers in [[:], ["Authorization": "Basic bad"]] {
            let refused = try await send("POST", "/api/debug/echo", headers: headers, body: try json(["v": "1"]))
            XCTAssertEqual(refused.status, 401)
            XCTAssertEqual(refused.response.value(forHTTPHeaderField: "WWW-Authenticate"), "Basic realm=\"Provenance Debug API\"")
            let refusal = try object(refused.body)
            XCTAssertEqual(refusal["error"] as? String, "unauthorized")
        }

        let allowed = ["Authorization": "Basic good"]
        let echoed = try await send("POST", "/api/debug/echo", headers: allowed, body: try json(["v": "1"]))
        XCTAssertEqual(echoed.status, 200)
        XCTAssertEqual(echoed.response.value(forHTTPHeaderField: "Cache-Control"), "no-store")
        let echo = try object(echoed.body)
        XCTAssertEqual((echo["data"] as? [String: Any])?["value"] as? String, "1")

        let index = try await send("GET", "/api/debug", headers: allowed)
        let listing = try object(index.body)
        XCTAssertEqual((listing["data"] as? [String: Any])?["routes"] as? [String], ["POST /api/debug/echo"])
        let indexRefused = try await send("GET", "/api/debug")
        XCTAssertEqual(indexRefused.status, 401)
    }

    func testDebugRoutesRegisteredAfterStartAreStillGuarded() async throws {
        let registry = PVDebugAPIRegistry()
        try await startServer(debugAPI: DebugAPIAccess(registry: registry) { $0.header("Authorization") == "Basic good" })
        registry.register("GET", "/api/debug/late") { _ in .ok() }
        let refused = try await send("GET", "/api/debug/late")
        XCTAssertEqual(refused.status, 401)
        let allowed = try await send("GET", "/api/debug/late", headers: ["Authorization": "Basic good"])
        XCTAssertEqual(allowed.status, 200)
    }

    /// A client without the password must not learn which debug routes exist.
    func testUnknownDebugPathsAreRefusedLikeKnownOnes() async throws {
        let registry = PVDebugAPIRegistry()
        registry.register("GET", "/api/debug/ping") { _ in .ok() }
        try await startServer(debugAPI: DebugAPIAccess(registry: registry) { $0.header("Authorization") == "Basic good" })

        for path in ["/api/debug/ping", "/api/debug/missing", "/api/debug/a/b"] {
            let refused = try await send("GET", path)
            XCTAssertEqual(refused.status, 401, path)
        }
        let missing = try await send("GET", "/api/debug/missing", headers: ["Authorization": "Basic good"])
        XCTAssertEqual(missing.status, 404)
        XCTAssertEqual(try object(missing.body)["ok"] as? Bool, false)
        let wrongMethod = try await send("POST", "/api/debug", headers: ["Authorization": "Basic good"])
        XCTAssertEqual(wrongMethod.status, 404)
    }

    func testDebugPathsNeverReachTheFilesUnderThem() async throws {
        _ = try write("api/debug/keep.bin")
        try await startServer(debugAPI: DebugAPIAccess(registry: PVDebugAPIRegistry()) { _ in false })
        let refused = try await send("DELETE", "/api/debug/keep.bin")
        XCTAssertEqual(refused.status, 401)
        XCTAssertTrue(exists("api/debug/keep.bin"))
    }

    func testTheDebugPrefixEndsAtASegment() async throws {
        _ = try write("api/debugger/notes.txt")
        try await startServer(debugAPI: DebugAPIAccess(registry: PVDebugAPIRegistry()) { _ in false })
        // WebDAV answers it, so the debug routes (which refuse everyone here) did not.
        let result = try await send("DELETE", "/api/debugger/notes.txt")
        XCTAssertEqual(result.status, 204)
        XCTAssertFalse(exists("api/debugger/notes.txt"))
    }

    func testOversizedDebugBodyIsRefused() async throws {
        let registry = PVDebugAPIRegistry()
        registry.register("POST", "/api/debug/echo") { _ in .ok() }
        try await startServer(debugAPI: DebugAPIAccess(registry: registry) { _ in true })
        let result = try await send("POST", "/api/debug/echo", body: Data(count: 1_024 * 1_024 + 1))
        XCTAssertEqual(result.status, 413)
    }
}
