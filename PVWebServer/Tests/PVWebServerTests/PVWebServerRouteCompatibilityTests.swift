import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import XCTest
@testable import PVWebServer

final class PVWebServerRouteCompatibilityTests: XCTestCase {
    func testHTTPUploadDefaultsToImportsAndEmitsCompletion() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = PVModernWebServer(browseRoot: root)
        let destination = root.appendingPathComponent("Imports/probe.rom")
        let completed = expectation(description: "Upload completion preserves importer contract")
        let token = NotificationCenter.default.addObserver(forName: .pvWebServerFileUploadCompleted, object: nil, queue: nil) { note in
            guard note.userInfo?["filePath"] as? String == destination.path else { return }
            XCTAssertEqual(note.userInfo?["fileSize"] as? Int, 7)
            completed.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        try await Application(router: server.buildHTTPRouter()).test(.router) { client in
            let response = try await client.execute(
                uri: "/upload", method: .post,
                headers: [.contentType: "multipart/form-data; boundary=Probe"],
                body: ByteBuffer(string: "--Probe\r\nContent-Disposition: form-data; name=\"files[]\"; filename=\"probe.rom\"\r\n\r\nROMDATA\r\n--Probe--\r\n")
            )
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(try Data(contentsOf: destination), Data("ROMDATA".utf8))
        }
        await fulfillment(of: [completed], timeout: 1)
    }

    func testExplicitSystemDirectoryUploadPreservesZipAndRejectsTraversal() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = PVModernWebServer(browseRoot: root)
        let zip = Data([0x50, 0x4B, 0x03, 0x04, 0x42])
        var body = Data("--Probe\r\nContent-Disposition: form-data; name=\"files[]\"; filename=\"probe.zip\"\r\n\r\n".utf8)
        body.append(zip)
        body.append(Data("\r\n--Probe--\r\n".utf8))
        let uploadBody = ByteBuffer(bytes: body)

        try await Application(router: server.buildHTTPRouter()).test(.router) { client in
            let response = try await client.execute(
                uri: "/upload?path=ROMs/com.provenance.mame", method: .post,
                headers: [.contentType: "multipart/form-data; boundary=Probe"], body: uploadBody
            )
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("ROMs/com.provenance.mame/probe.zip")), zip)
            let forbidden = try await client.execute(
                uri: "/upload?path=../escape", method: .post,
                headers: [.contentType: "multipart/form-data; boundary=Probe"], body: uploadBody
            )
            XCTAssertEqual(forbidden.status, .forbidden)
        }
    }

    func testWebDAVWriteListMoveDeletePreservesFileEvents() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = PVModernWebServer(browseRoot: root)
        let propfindMethod = try XCTUnwrap(HTTPRequest.Method("PROPFIND"))
        let moveMethod = try XCTUnwrap(HTTPRequest.Method("MOVE"))
        let destinationHeader = try XCTUnwrap(HTTPField.Name("Destination"))
        let moved = expectation(description: "MOVE event")
        let deleted = expectation(description: "DELETE event")
        let moveToken = NotificationCenter.default.addObserver(forName: .pvWebServerFileMoved, object: nil, queue: nil) { note in
            guard note.userInfo?["toPath"] as? String == root.appendingPathComponent("moved.rom").path else { return }
            XCTAssertEqual(note.userInfo?["fromPath"] as? String, root.appendingPathComponent("probe.rom").path)
            moved.fulfill()
        }
        let deleteToken = NotificationCenter.default.addObserver(forName: .pvWebServerFileDeleted, object: nil, queue: nil) { note in
            guard note.userInfo?["filePath"] as? String == root.appendingPathComponent("moved.rom").path else { return }
            deleted.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(moveToken)
            NotificationCenter.default.removeObserver(deleteToken)
        }
        try await Application(router: server.buildWebDAVRouter(uploadDirectory: root)).test(.router) { client in
            let put = try await client.execute(uri: "/probe.rom", method: .put, body: ByteBuffer(string: "ROMDATA"))
            XCTAssertEqual(put.status, .created)
            let propfind = try await client.execute(uri: "/", method: propfindMethod)
            XCTAssertEqual(propfind.status.code, 207)
            XCTAssertTrue(String(buffer: propfind.body).contains("probe.rom"))
            var moveHeaders = HTTPFields()
            moveHeaders[destinationHeader] = "http://localhost/moved.rom"
            let move = try await client.execute(uri: "/probe.rom", method: moveMethod, headers: moveHeaders)
            XCTAssertEqual(move.status, .noContent)
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("moved.rom")), Data("ROMDATA".utf8))
            let delete = try await client.execute(uri: "/moved.rom", method: .delete)
            XCTAssertEqual(delete.status, .noContent)
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("moved.rom").path))
        }
        await fulfillment(of: [moved, deleted], timeout: 1)
    }

    func testDebugRoutesRetainExistingBasicAuthPolicy() async throws {
        let defaults = UserDefaults.standard
        let keys = [PVDebugAPIPrefs.enabledKey, PVDebugAPIPrefs.authEnabledKey, PVDebugAPIPrefs.passwordKey]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.set(true, forKey: PVDebugAPIPrefs.enabledKey)
        defaults.set(true, forKey: PVDebugAPIPrefs.authEnabledKey)
        defaults.set("route-test-password", forKey: PVDebugAPIPrefs.passwordKey)
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = PVModernWebServer(browseRoot: root)
        try await Application(router: server.buildHTTPRouter()).test(.router) { client in
            let unauthorized = try await client.execute(uri: "/api/debug", method: .get)
            XCTAssertEqual(unauthorized.status, .unauthorized)
            let authorized = try await client.execute(
                uri: "/api/debug", method: .get,
                headers: [.authorization: PVDebugAPIPrefs.expectedAuthorizationHeader(password: "route-test-password")]
            )
            XCTAssertEqual(authorized.status, .ok)
            XCTAssertTrue(String(buffer: authorized.body).contains("routes"))
        }
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
