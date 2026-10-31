import Foundation
import XCTest
@testable import PVLogging
@testable import PVUIBase
#if canImport(PVWebServer)
import PVWebServer

final class PVDebugAPILogRoutesTests: XCTestCase {
    private func entry(_ message: String, level: LogLevel = .info, category: String = "general", second: TimeInterval = 0) -> LogEntry {
        LogEntry(message: message, level: level, category: category, timestamp: Date(timeIntervalSince1970: second), file: "Test.swift", function: "test", line: 1)
    }

    private func payload(_ response: PVDebugAPIResponse) throws -> [String: Any] {
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: response.body) as? [String: Any])
        XCTAssertEqual(envelope["ok"] as? Bool, response.status == 200)
        return try XCTUnwrap(envelope["data"] as? [String: Any])
    }

    func testOnlyRegistersReadOnlyRoute() async throws {
        let registry = PVDebugAPIRegistry()
        let entries = [entry("scan finished")]
        PVDebugAPILogRoutes.register(in: registry, snapshot: { entries })
        XCTAssertNil(registry.handler(method: "POST", path: "/api/debug/logs"))
        let handler = try XCTUnwrap(registry.handler(method: "GET", path: "/api/debug/logs"))
        let result = await handler(PVDebugAPIRequest(method: "GET", path: "/api/debug/logs", query: [:], body: nil))
        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(try payload(result)["returnedCount"] as? Int, 1)
    }

    func testFiltersBeforeLimitingAndReturnsNewestFirst() throws {
        let entries = [entry("old warning", level: .warning, category: "import", second: 1),
                       entry("unrelated", category: "cloudkit", second: 2),
                       entry("new error", level: .error, category: "import", second: 3)]
        let response = PVDebugAPILogRoutes.response(query: ["category": "IMPORT", "level": "warning", "limit": "1"], entries: entries)
        let data = try payload(response)
        let rows = try XCTUnwrap(data["entries"] as? [[String: Any]])
        XCTAssertEqual(rows.map { $0["message"] as? String }, ["new error"])
        XCTAssertEqual(data["retainedCount"] as? Int, 3)
        XCTAssertEqual(data["matchingCount"] as? Int, 2)
        XCTAssertEqual(data["limitApplied"] as? Bool, true)
        XCTAssertEqual(data["responseTruncated"] as? Bool, false)
    }

    func testRejectsInvalidQueries() {
        for query in [["limit": "0"], ["limit": "-1"], ["limit": "invalid"], ["level": "invalid"], ["category": String(repeating: "x", count: 129)]] {
            XCTAssertEqual(PVDebugAPILogRoutes.response(query: query, entries: []).status, 400)
        }
    }

    func testClampsLimitAndExplainsRetentionForEmptySnapshot() throws {
        let response = PVDebugAPILogRoutes.response(query: ["limit": "999999"], entries: [])
        let data = try payload(response)
        XCTAssertEqual(data["limit"] as? Int, PVDebugAPILogRoutes.maximumLimit)
        XCTAssertEqual(data["retainedCount"] as? Int, 0)
        XCTAssertEqual(data["retention"] as? String, "recentMemoryBuffer")
        XCTAssertEqual(data["earlierEntriesMayBeUnavailable"] as? Bool, true)
        XCTAssertTrue(data["oldestRetained"] is NSNull)
    }

    func testEscapedMessagesCannotExceedResponseBudget() throws {
        let entries = (0..<1_000).map { entry(String(repeating: "\u{0001}", count: 6_000), second: Double($0)) }
        let response = PVDebugAPILogRoutes.response(query: ["limit": "1000"], entries: entries)
        XCTAssertLessThanOrEqual(response.body.count, PVDebugAPILogRoutes.maximumResponseBytes)
        let data = try payload(response)
        XCTAssertEqual(data["responseTruncated"] as? Bool, true)
        let rows = try XCTUnwrap(data["entries"] as? [[String: Any]])
        XCTAssertFalse(rows.isEmpty)
        XCTAssertTrue(rows.allSatisfy { $0["messageTruncated"] as? Bool == true })
    }

    func testTruncationPreservesUnicode() throws {
        let message = String(repeating: "🎮", count: 2_000)
        let response = PVDebugAPILogRoutes.response(query: [:], entries: [entry(message)])
        let rows = try XCTUnwrap(try payload(response)["entries"] as? [[String: Any]])
        let text = try XCTUnwrap(rows.first?["message"] as? String)
        XCTAssertFalse(text.contains("�"))
        XCTAssertTrue(message.hasPrefix(text))
        XCTAssertEqual(rows.first?["messageTruncated"] as? Bool, true)
    }
}
#endif
