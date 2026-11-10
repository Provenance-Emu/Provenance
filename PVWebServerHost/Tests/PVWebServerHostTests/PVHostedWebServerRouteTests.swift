//
//  PVHostedWebServerRouteTests.swift
//  PVWebServerHostTests
//
//  Drives a real listener the way the file-manager page and a WebDAV client do, and holds
//  the server to the notifications the library depends on.
//

import XCTest
import PVWebServer
@testable import PVWebServerHost

final class PVHostedWebServerRouteTests: LiveServerTestCase {

    // MARK: Page and listing

    func testRootServesTheFileManagerPage() async throws {
        let result = try await send("GET", "/")
        XCTAssertEqual(result.status, 200)
        XCTAssertTrue(text(result.body).contains("Provenance — Web File Manager"))
    }

    func testListingSortsFoldersFirstHidesDotfilesAndDecodesThePath() async throws {
        try write("Save States/b.state")
        try write("Save States/.hidden")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Save States/z folder"), withIntermediateDirectories: true)
        let result = try await send("GET", "/files?path=Save%20States")
        XCTAssertEqual(result.status, 200)
        let listing = try object(result.body)
        XCTAssertEqual(listing["path"] as? String, "Save States")
        let items = try XCTUnwrap(listing["items"] as? [[String: Any]])
        XCTAssertEqual(items.compactMap { $0["name"] as? String }, ["z folder", "b.state"])
        XCTAssertEqual(items.last?["size"] as? Int, 3)
    }

    func testListingRejectsEscapesAndNonFolders() async throws {
        try write("ROMs/game.bin")
        let escape = try await send("GET", "/files?path=..%2F..")
        XCTAssertEqual(escape.status, 403)
        let notAFolder = try await send("GET", "/files?path=ROMs/game.bin")
        XCTAssertEqual(notAFolder.status, 404)
    }

    func testDownloadStreamsTheFileAsAnAttachment() async throws {
        try write("ROMs/my game.bin", contents: "BYTES")
        let result = try await send("GET", "/download?path=ROMs%2Fmy%20game.bin")
        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(text(result.body), "BYTES")
        XCTAssertEqual(result.response.value(forHTTPHeaderField: "Content-Disposition"), "attachment; filename=\"my game.bin\"")
    }

    func testDownloadRejectsFoldersAndMissingFilesAndEscapes() async throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("ROMs"), withIntermediateDirectories: true)
        for path in ["/download?path=ROMs", "/download?path=nope.bin", "/download?path=..%2Fsecret", "/download"] {
            let result = try await send("GET", path)
            XCTAssertEqual(result.status, 404, path)
        }
    }

    // MARK: Uploads

    func testUploadDefaultsToImportsAndTellsTheLibrary() async throws {
        let form = uploadForm(filename: "probe.rom")
        var status = 0
        var statusBar: [[AnyHashable: Any]] = []
        let completed = try await notes(named: .pvWebServerFileUploadCompleted) {
            statusBar = try await notes(named: .pvWebServerUploadCompleted) {
                status = try await send("POST", "/upload", headers: form.headers, body: form.body).status
            }
        }
        XCTAssertEqual(status, 200)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("Imports/probe.rom")), Data("ROMDATA".utf8))
        XCTAssertEqual(completed.first?["filePath"] as? String, path("Imports/probe.rom"))
        XCTAssertEqual(statusBar.first?["fileName"] as? String, path("Imports/probe.rom"))
        XCTAssertEqual(statusBar.first?["fileSize"] as? Int64, 7, "StatusMessageManager casts it to Int64")
    }

    func testUploadToAFolderKeepsTheFileUnchanged() async throws {
        let form = uploadForm(filename: "probe.rom")
        let result = try await send("POST", "/upload?path=Save%20States", headers: form.headers, body: form.body)
        XCTAssertEqual(result.status, 200)
        XCTAssertTrue(exists("Save States/probe.rom"))
    }

    func testUploadRejectsTraversal() async throws {
        let form = uploadForm(filename: "probe.rom")
        try await send("POST", "/upload?path=..%2F..", headers: form.headers, body: form.body)
        // The engine files a refused path at the root rather than failing the upload.
        let outside = root.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("probe.rom")
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.path))
        XCTAssertTrue(exists("probe.rom"))
    }

    // MARK: File changes

    func testCreatingAFolderNeedsAValidNameAndAnnouncesIt() async throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("ROMs"), withIntermediateDirectories: true)
        for name in ["", ".hidden", "a/b"] {
            let invalid = try await send("POST", "/folders", body: try json(["path": "ROMs", "name": name]))
            XCTAssertEqual(invalid.status, 400, name)
        }
        var status = 0
        let created = try await notes(named: .pvWebServerFolderCreated) {
            status = try await send("POST", "/folders", body: try json(["path": "ROMs", "name": "New"])).status
        }
        XCTAssertEqual(status, 201)
        XCTAssertEqual(created.first?["filePath"] as? String, path("ROMs/New"))
        let again = try await send("POST", "/folders", body: try json(["path": "ROMs", "name": "New"]))
        XCTAssertEqual(again.status, 409)
    }

    func testMoveCreatesTheDestinationFolderAndTellsTheLibrary() async throws {
        try write("Imports/a.bin")
        var status = 0
        let moved = try await notes(named: .pvWebServerFileMoved) {
            status = try await send("PATCH", "/files", body: try json(["from": "Imports/a.bin", "to": "ROMs/GBA/a.bin"])).status
        }
        XCTAssertEqual(status, 204)
        XCTAssertTrue(exists("ROMs/GBA/a.bin"))
        XCTAssertEqual(moved.first?["fromPath"] as? String, path("Imports/a.bin"))
        XCTAssertEqual(moved.first?["toPath"] as? String, path("ROMs/GBA/a.bin"))
    }

    func testMoveRejectsEscapesAndMissingSources() async throws {
        let escape = try await send("PATCH", "/files", body: try json(["from": "../a", "to": "b"]))
        XCTAssertEqual(escape.status, 400)
        let missing = try await send("PATCH", "/files", body: try json(["from": "nope", "to": "b"]))
        XCTAssertEqual(missing.status, 409)
    }

    func testDeleteTellsTheLibraryAndRefusesTheRoot() async throws {
        try write("ROMs/a.bin")
        var status = 0
        let deleted = try await notes(named: .pvWebServerFileDeleted) {
            status = try await send("DELETE", "/files?path=ROMs%2Fa.bin").status
        }
        XCTAssertEqual(status, 204)
        XCTAssertFalse(exists("ROMs/a.bin"))
        XCTAssertEqual(deleted.first?["filePath"] as? String, path("ROMs/a.bin"))

        for path in ["/files", "/files?path=.", "/files?path=..%2F.."] {
            let refused = try await send("DELETE", path)
            XCTAssertEqual(refused.status, 403, path)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
    }

    func testBatchDeleteReportsEachFailure() async throws {
        try write("ROMs/a.bin")
        try write("ROMs/b.bin")
        let body = try json(["paths": ["ROMs/a.bin", "ROMs/b.bin", "nope.bin", "../escape", "."]])
        let result = try await send("POST", "/files/batch-delete", body: body)
        XCTAssertEqual(result.status, 200)
        let summary = try object(result.body)
        XCTAssertEqual(summary["deleted"] as? Int, 2)
        let failed = try XCTUnwrap(summary["failed"] as? [[String: String]])
        XCTAssertEqual(failed.compactMap { $0["path"] }, ["nope.bin", "../escape", "."])
        XCTAssertEqual(failed[1]["error"], "forbidden")
    }

    // MARK: WebDAV on the shared port

    func testWebDAVMoveIsARenameNotANewROM() async throws {
        try write("ROMs/old.bin")
        let port = try XCTUnwrap(server.boundPort)
        var moved: [[AnyHashable: Any]] = []
        let uploads = try await notes(named: .pvWebServerFileUploadCompleted) {
            moved = try await notes(named: .pvWebServerFileMoved) {
                try await send("MOVE", "/ROMs/old.bin", headers: ["Destination": "http://127.0.0.1:\(port)/ROMs/new.bin"])
            }
        }
        XCTAssertEqual(moved.first?["toPath"] as? String, path("ROMs/new.bin"))
        XCTAssertTrue(uploads.isEmpty)
    }

    func testWebDAVPutReachesTheLibrary() async throws {
        let completed = try await notes(named: .pvWebServerFileUploadCompleted) {
            try await send("PUT", "/ROMs/dav.bin", body: Data("DAV".utf8))
        }
        XCTAssertEqual(completed.first?["filePath"] as? String, path("ROMs/dav.bin"))
    }

    func testPropfindListsTheRootOnTheSamePort() async throws {
        try write("ROMs/a.bin")
        let result = try await send("PROPFIND", "/ROMs", headers: ["Depth": "1"])
        XCTAssertEqual(result.status, 207)
        XCTAssertTrue(text(result.body).contains("a.bin"))
    }

    // MARK: Dashboard

    func testStatsReportTheOnePortForBothProtocols() async throws {
        try write("ROMs/a.bin")
        let response = try await send("GET", "/stats")
        let stats = try object(response.body)
        XCTAssertEqual(stats["httpPort"] as? Int, server.boundPort)
        XCTAssertEqual(stats["webDAVPort"] as? Int, server.boundPort)
        let directories = try XCTUnwrap(stats["directories"] as? [[String: Any]])
        XCTAssertEqual(directories.compactMap { $0["name"] as? String }, ["Imports", "ROMs", "BIOS", "Save States", "Screenshots", "Cheats"])
        XCTAssertEqual(directories.first { $0["name"] as? String == "ROMs" }?["fileCount"] as? Int, 1)
    }

    func testQRCodeIsAPNG() async throws {
        let result = try await send("GET", "/qr.png?text=http%3A%2F%2Fexample%2F")
        XCTAssertEqual(result.status, 200)
        XCTAssertEqual(result.response.value(forHTTPHeaderField: "Content-Type"), "image/png")
        XCTAssertEqual(Array(result.body.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    }

    func testEventsStreamFileChangesAndEndsWhenTheServerStops() async throws {
        let (bytes, _) = try await URLSession.shared.bytes(for: try request("GET", "/events"))
        var lines = bytes.lines.makeAsyncIterator()
        var greeting: [String] = []
        while let line = try await lines.next(), !line.contains("\"ok\":true") { greeting.append(line) }
        XCTAssertTrue(greeting.contains("event: hello"))

        while server.events.subscriberCount == 0 { try await Task.sleep(nanoseconds: 10_000_000) }
        try write("ROMs/a.bin")
        try await send("DELETE", "/files?path=ROMs%2Fa.bin")
        let event = try await lines.next()
        XCTAssertEqual(event, "event: delete")
        let next = try await lines.next()
        let data = try XCTUnwrap(next)
        let payload = try object(Data(data.dropFirst("data: ".count).utf8))
        XCTAssertEqual(payload["path"] as? String, "ROMs/a.bin")
        XCTAssertEqual(payload["name"] as? String, "a.bin")

        await server.stopServers()
        XCTAssertEqual(server.events.subscriberCount, 0)
        while let line = try? await lines.next() { XCTAssertFalse(line.contains("event:"), line) }
        bytes.task.cancel()
    }

    func testRestartedServerIsNotCalledBackByTheOldOne() async throws {
        let handled = expectation(description: "unexpected stop")
        handled.isInverted = true
        server.setUnexpectedStopHandler { handled.fulfill() }
        await server.stopServers()
        await fulfillment(of: [handled], timeout: 0.5)
    }

    // MARK: Status

    func testStartAndStopAnnounceBothProtocolsOnOnePort() async throws {
        let other = PVHostedWebServer(browseRoot: root, ports: randomPorts())
        let started = try await notes(named: .pvWebServerStatusChanged) {
            _ = try await other.startServers()
        }
        XCTAssertEqual(started.compactMap { $0["type"] as? String }, ["WebUploader", "WebDAV"])
        let port = try XCTUnwrap(other.boundPort)
        XCTAssertEqual(Set(started.compactMap { $0["port"] as? Int }), [port])
        XCTAssertEqual(started.compactMap { $0["isRunning"] as? Bool }, [true, true])

        let stopped = await notes(named: .pvWebServerStatusChanged) {
            await other.stopServers()
        }
        XCTAssertEqual(stopped.compactMap { $0["isRunning"] as? Bool }, [false, false])
    }
}
