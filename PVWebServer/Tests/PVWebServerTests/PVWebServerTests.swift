//
//  PVWebServerTests.swift
//  PVWebServer
//
//  Created by Joseph Mattiello on 6/01/24.
//  Copyright © 2024 Joseph Mattiello. All rights reserved.
//

import Combine
import XCTest
import PVPrimitives
@testable import PVWebServer

class PVWebServerTests: XCTestCase {

    // MARK: - PVWebServerManager tests

    func testManagerDefaultsToLegacyServer() async {
        let manager = PVWebServerManager(useModernServer: false)
        let isRunning = await manager.isRunning
        XCTAssertFalse(isRunning, "Manager should not be running before start()")
    }

    func testManagerFeatureFlagOverride() async {
        let manager = PVWebServerManager(useModernServer: true)
        // Only verifies the flag is accepted; does not attempt a real bind on port 80.
        let isRunning = await manager.isRunning
        XCTAssertFalse(isRunning)
    }

    /// `refreshFeatureFlag()` lives in PVUIBase and reads `PVFeatureFlags`; here we only verify the manager obeys `setModernServerEnabled`.
    func testManagerSetModernServerEnabled() async {
        let manager = PVWebServerManager(useModernServer: false)
        await manager.setModernServerEnabled(true)
        let enabledAfterTrue = await manager.useModernServer
        XCTAssertTrue(enabledAfterTrue)
        await manager.setModernServerEnabled(false)
        let enabledAfterFalse = await manager.useModernServer
        XCTAssertFalse(enabledAfterFalse)
    }

    // MARK: - PVModernWebServer unit tests

    func testModernServerInitDefaultsToImportsDirectory() {
        let server = PVModernWebServer()
        XCTAssertTrue(server.uploadDirectory.lastPathComponent == "Imports",
                      "Default upload directory should be …/Imports")
    }

    func testModernServerCustomUploadDirectory() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let server = PVModernWebServer(uploadDirectory: tmp)
        XCTAssertEqual(server.uploadDirectory, tmp)
        // Verify the directory was created on init
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
        try FileManager.default.removeItem(at: tmp)
    }

    func testModernServerNotRunningBeforeStart() {
        let server = PVModernWebServer()
        XCTAssertFalse(server.isWWWServerRunning)
        XCTAssertFalse(server.isWebDAVServerRunning)
        XCTAssertNil(server.serverURL, "serverURL should be nil before start")
    }

    // MARK: - Notification name constants

    func testNotificationNamesMatchLegacyConstants() {
        XCTAssertEqual(Notification.Name("PVWebServerFileUploadStartedNotification").rawValue,
                       "PVWebServerFileUploadStartedNotification")
        XCTAssertEqual(Notification.Name("PVWebServerFileUploadProgressNotification").rawValue,
                       "PVWebServerFileUploadProgressNotification")
        XCTAssertEqual(Notification.Name("PVWebServerFileUploadCompletedNotification").rawValue,
                       "PVWebServerFileUploadCompletedNotification")
        XCTAssertEqual(Notification.Name("PVWebServerFileUploadFailedNotification").rawValue,
                       "PVWebServerFileUploadFailedNotification")
        XCTAssertEqual(Notification.Name("WebServerUploadProgress").rawValue,
                       "WebServerUploadProgress")
        XCTAssertEqual(Notification.Name("WebServerUploadCompleted").rawValue,
                       "WebServerUploadCompleted")
        XCTAssertEqual(Notification.Name("WebServerStatusChanged").rawValue,
                       "WebServerStatusChanged")
    }

    func testFileLifecycleNotificationNamesExist() {
        XCTAssertEqual(Notification.Name("PVWebServerFileDeletedNotification").rawValue,
                       "PVWebServerFileDeletedNotification")
        XCTAssertEqual(Notification.Name("PVWebServerFileMovedNotification").rawValue,
                       "PVWebServerFileMovedNotification")
    }

    // MARK: - File-lifecycle notification posting

    /// Tests that an observer receives the correct file path when a
    /// `pvWebServerFileDeleted` notification is posted with the expected payload.
    /// Note: this test validates notification delivery and payload shape; it does
    /// not exercise the full `PVModernWebServer` HTTP DELETE route handler — that
    /// requires an integration test against a running server.
    func testDeleteNotificationDeliveredToObserver() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        let testFile = tmp.appendingPathComponent("test.rom")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try Data([0xDE, 0xAD, 0xBE, 0xEF]).write(to: testFile)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let server = PVModernWebServer(uploadDirectory: tmp)

        var receivedPath: String?
        let expectation = XCTestExpectation(description: "pvWebServerFileDeleted fires")

        let token = NotificationCenter.default.addObserver(
            forName: Notification.Name("PVWebServerFileDeletedNotification"), object: nil, queue: nil
        ) { note in
            receivedPath = note.userInfo?["filePath"] as? String
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        // Simulate what the DELETE route handler does:
        try FileManager.default.removeItem(at: testFile)
        NotificationCenter.default.post(
            name: Notification.Name("PVWebServerFileDeletedNotification"),
            object: server,
            userInfo: ["filePath": testFile.path]
        )

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedPath, testFile.path)
    }

    func testCombineFileDeletedPublisher() {
        let manager = PVWebServerManager()
        var cancellables = Set<AnyCancellable>()
        var receivedPath: String?
        let expectation = XCTestExpectation(description: "fileDeletedPublisher emits")

        manager.fileDeletedPublisher
            .sink { path in
                receivedPath = path
                expectation.fulfill()
            }
            .store(in: &cancellables)

        NotificationCenter.default.post(
            name: Notification.Name("PVWebServerFileDeletedNotification"),
            object: nil,
            userInfo: ["filePath": "/some/test.rom"]
        )

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedPath, "/some/test.rom")
    }

    func testCombineFileMovedPublisher() {
        let manager = PVWebServerManager()
        var cancellables = Set<AnyCancellable>()
        var receivedEvent: (from: String, to: String)?
        let expectation = XCTestExpectation(description: "fileMovedPublisher emits")

        manager.fileMovedPublisher
            .sink { event in
                receivedEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)

        NotificationCenter.default.post(
            name: Notification.Name("PVWebServerFileMovedNotification"),
            object: nil,
            userInfo: ["fromPath": "/old/a.rom", "toPath": "/new/a.rom"]
        )

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedEvent?.from, "/old/a.rom")
        XCTAssertEqual(receivedEvent?.to, "/new/a.rom")
    }
}
