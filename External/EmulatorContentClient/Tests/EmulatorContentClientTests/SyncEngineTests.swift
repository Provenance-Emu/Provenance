import EmulatorContentClient
import XCTest

/// Records the requests a sync call makes and answers them from a script, so the suite needs no server.
private final class ScriptedTransport: ContentTransport, @unchecked Sendable {
    /// The engine issues one request at a time, so these need no lock.
    private nonisolated(unsafe) var scripts: [(Int, String)]
    private nonisolated(unsafe) var requests: [URLRequest] = []

    init(_ scripts: [(Int, String)]) {
        self.scripts = scripts
    }

    var recorded: [URLRequest] { requests }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let next = scripts.removeFirst()
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "http://127.0.0.1")!,
            statusCode: next.0,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(next.1.utf8), response)
    }
}

final class SyncEngineTests: XCTestCase {
    private let base = URL(string: "http://127.0.0.1:7878")!

    func testChangePagesStopWhenTheCursorStopsAdvancing() async throws {
        let transport = ScriptedTransport([
            (200, #"{"changes":[{"cursor":1,"entityType":"asset","entityId":"a","op":"upsert","libraryId":"lib","itemId":"item","sensitive":false,"recordedAt":"t"}],"nextCursor":"1"}"#),
            (200, #"{"changes":[],"nextCursor":"1"}"#),
        ])
        let sync = ContentSync(baseURL: base, token: "device-token", transport: transport)
        var pages: [ChangeList] = []
        for try await page in sync.changePages(from: "0", limit: 50, excludeOwnDevice: true) {
            pages.append(page)
        }
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].changes.count, 1)
        XCTAssertEqual(pages[1].changes.count, 0)
        let query = transport.recorded[0].url?.query ?? ""
        XCTAssertTrue(query.contains("excludeOwnDevice=1"))
        XCTAssertTrue(query.contains("cursor=0"))
        XCTAssertFalse(transport.recorded[0].allHTTPHeaderFields?["Authorization"]?.isEmpty ?? true)
    }

    func testAdoptingASavePostsToThatAsset() async throws {
        let transport = ScriptedTransport([
            (200, #"{"id":"copy","itemId":"item","kind":"battery_save","displayName":"battery.sav","relativePath":"battery.sav","sha256":"abc","size":12,"md5":null,"crc":null,"shareable":true,"revision":2,"createdAt":"t","updatedAt":"t","conflictOf":null}"#),
        ])
        let sync = ContentSync(baseURL: base, token: "device-token", transport: transport)
        let asset = try await sync.adopt(assetId: "copy")
        XCTAssertEqual(asset.relativePath, "battery.sav")
        XCTAssertNil(asset.conflictOf)
        XCTAssertEqual(transport.recorded[0].httpMethod, "POST")
        XCTAssertEqual(transport.recorded[0].url?.path, "/api/v1/files/copy/adopt")
    }

    func testAPartialDownloadAsksForTheRemainderAndKeepsItsETag() {
        let sync = ContentSync(baseURL: base, token: "device-token", transport: ScriptedTransport([]))
        let request = sync.contentRequest(assetId: "asset", localBytes: 400, etag: "\"digest\"")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Range"), "bytes=400-")
        XCTAssertEqual(request.value(forHTTPHeaderField: "If-Range"), "\"digest\"")
    }

    func testAnInterruptedUploadContinuesFromTheOffsetTheServerHolds() async throws {
        let transport = ScriptedTransport([
            (200, #"{"id":"up","received":400,"state":"open"}"#),
        ])
        let sync = ContentSync(baseURL: base, token: "device-token", transport: transport)
        let offset = try await sync.receivedOffset(uploadId: "up")
        XCTAssertEqual(offset, 400)
        XCTAssertEqual(transport.recorded[0].url?.path, "/api/v1/uploads/up")
    }

    func testARefusalSurfacesTheProblemTitleWithoutTheToken() async throws {
        let transport = ScriptedTransport([
            (409, #"{"title":"Only a save can be chosen"}"#),
        ])
        let sync = ContentSync(baseURL: base, token: "device-token", transport: transport)
        do {
            _ = try await sync.adopt(assetId: "rom")
            XCTFail("a refusal must throw")
        } catch let failure as SyncFailure {
            XCTAssertEqual(failure.status, 409)
            XCTAssertEqual(failure.message, "Only a save can be chosen")
            XCTAssertFalse(failure.message.contains("device-token"))
        }
    }
}
