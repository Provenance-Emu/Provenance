//
//  LiveServerTestCase.swift
//  PVWebServerHostTests
//

import XCTest
import PVWebServer
@testable import PVWebServerHost

/// A started server on a random high port, and a client to talk to it.
class LiveServerTestCase: XCTestCase {
    var root: URL!
    var server: PVHostedWebServer!

    override func setUp() async throws {
        root = try makeTemporaryRoot()
        try await startServer(debugAPI: nil)
    }

    /// Replaces the running server, for a test that needs another debug API.
    func startServer(debugAPI: DebugAPIAccess?) async throws {
        await server?.stopServers()
        server = PVHostedWebServer(uploadDirectory: nil, browseRoot: root, ports: randomPorts(), debugAPI: debugAPI)
        let started = try await server.startServers()
        XCTAssertTrue(started)
    }

    override func tearDown() async throws {
        await server.stopServers()
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: Helpers

    func request(_ method: String, _ path: String, headers: [String: String] = [:], body: Data? = nil) throws -> URLRequest {
        let port = try XCTUnwrap(server.boundPort)
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)\(path)")))
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return request
    }

    @discardableResult
    func send(
        _ method: String,
        _ path: String,
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> (status: Int, body: Data, response: HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: try request(method, path, headers: headers, body: body))
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        return (http.statusCode, data, http)
    }

    func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @discardableResult
    func write(_ relativePath: String, contents: String = "rom") throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    func path(_ relativePath: String) -> String {
        root.appendingPathComponent(relativePath).standardized.path
    }

    func uploadForm(filename: String, contents: String = "ROMDATA") -> (headers: [String: String], body: Data) {
        let body = "--Probe\r\nContent-Disposition: form-data; name=\"files[]\"; filename=\"\(filename)\"\r\n\r\n\(contents)\r\n--Probe--\r\n"
        return (["Content-Type": "multipart/form-data; boundary=Probe"], Data(body.utf8))
    }

    func notes(named name: Notification.Name, during work: () async throws -> Void) async rethrows -> [[AnyHashable: Any]] {
        let recorded = Recorded<[AnyHashable: Any]>()
        let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { note in
            recorded.append(note.userInfo ?? [:])
        }
        defer { NotificationCenter.default.removeObserver(token) }
        try await work()
        return recorded.values
    }

    func text(_ data: Data) -> String {
        String(bytes: data, encoding: .utf8) ?? ""
    }
}
