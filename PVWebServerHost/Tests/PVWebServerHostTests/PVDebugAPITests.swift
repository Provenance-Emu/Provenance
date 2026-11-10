//
//  PVDebugAPITests.swift
//  PVWebServerHostTests
//

import Foundation
import XCTest
@testable import PVWebServerHost

final class PVDebugAPIPrefsTests: XCTestCase {

    func testAuthDefaultsOnInReleaseOffInDebug() {
        XCTAssertTrue(PVDebugAPIPrefs.resolvedAuthEnabled(stored: nil, isDebugBuild: false))
        XCTAssertFalse(PVDebugAPIPrefs.resolvedAuthEnabled(stored: nil, isDebugBuild: true))
    }

    func testExplicitAuthChoiceWins() {
        XCTAssertFalse(PVDebugAPIPrefs.resolvedAuthEnabled(stored: false, isDebugBuild: false))
        XCTAssertTrue(PVDebugAPIPrefs.resolvedAuthEnabled(stored: true, isDebugBuild: true))
    }

    func testAuthDisabledAuthorizesEverything() {
        XCTAssertTrue(PVDebugAPIPrefs.isAuthorized(header: nil, authEnabled: false, password: ""))
    }

    func testAuthFailsClosedWithoutPassword() {
        let header = PVDebugAPIPrefs.expectedAuthorizationHeader(password: "")
        XCTAssertFalse(PVDebugAPIPrefs.isAuthorized(header: header, authEnabled: true, password: ""))
    }

    func testAuthRequiresExactHeader() {
        let header = PVDebugAPIPrefs.expectedAuthorizationHeader(password: "hunter2")
        XCTAssertEqual(header, "Basic " + Data("Provenance:hunter2".utf8).base64EncodedString())
        XCTAssertTrue(PVDebugAPIPrefs.isAuthorized(header: header, authEnabled: true, password: "hunter2"))
        XCTAssertFalse(PVDebugAPIPrefs.isAuthorized(header: header, authEnabled: true, password: "other"))
        XCTAssertFalse(PVDebugAPIPrefs.isAuthorized(header: nil, authEnabled: true, password: "hunter2"))
    }
}

final class PVDebugAPIRegistryTests: XCTestCase {

    func testLookupIsByMethodAndPath() async throws {
        let registry = PVDebugAPIRegistry()
        registry.register("get", "/api/debug/ping") { _ in .ok(["pong": true]) }

        XCTAssertNil(registry.handler(method: "POST", path: "/api/debug/ping"))
        let handler = try XCTUnwrap(registry.handler(method: "GET", path: "/api/debug/ping"))
        let response = await handler(PVDebugAPIRequest(method: "GET", path: "/api/debug/ping", query: [:], body: nil))
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(registry.routes, ["GET /api/debug/ping"])
    }

    func testObserverSeesExistingAndLaterRoutes() {
        let registry = PVDebugAPIRegistry()
        registry.register("get", "/api/debug/early") { _ in .ok() }
        let seen = Recorded<String>()
        registry.observeRoutes { method, path in seen.append("\(method) \(path)") }
        registry.register("post", "/api/debug/late") { _ in .ok() }
        XCTAssertEqual(seen.values, ["GET /api/debug/early", "POST /api/debug/late"])
    }

    func testRequestValuePrefersQueryThenJSONBody() {
        let body = try? JSONSerialization.data(withJSONObject: ["md5": "abc", "slot": 3])
        let request = PVDebugAPIRequest(method: "POST", path: "/x", query: ["md5": "fromQuery"], body: body)
        XCTAssertEqual(request.value("md5"), "fromQuery")
        XCTAssertEqual(request.value("slot"), "3")
        XCTAssertNil(request.value("missing"))
    }
}
