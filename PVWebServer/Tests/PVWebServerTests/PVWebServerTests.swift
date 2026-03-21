//
//  PVWebServerTests.swift
//  PVWebServer
//
//  Created by Joseph Mattiello on 6/01/24.
//  Copyright © 2024 Joseph Mattiello. All rights reserved.
//

import XCTest
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

    func testManagerRefreshFeatureFlag() async {
        let manager = PVWebServerManager()
        // Simulate a debug override being set.
        UserDefaults.standard.set(["modernWebServer": true], forKey: "PVFeatureFlagsDebugOverrides")
        await manager.refreshFeatureFlag()
        // Clean up
        UserDefaults.standard.removeObject(forKey: "PVFeatureFlagsDebugOverrides")
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
        XCTAssertEqual(Notification.Name.pvWebServerFileUploadStarted.rawValue,
                       "PVWebServerFileUploadStartedNotification")
        XCTAssertEqual(Notification.Name.pvWebServerFileUploadCompleted.rawValue,
                       "PVWebServerFileUploadCompletedNotification")
        XCTAssertEqual(Notification.Name.pvWebServerFileUploadFailed.rawValue,
                       "PVWebServerFileUploadFailedNotification")
        XCTAssertEqual(Notification.Name.pvWebServerUploadProgress.rawValue,
                       "WebServerUploadProgress")
        XCTAssertEqual(Notification.Name.pvWebServerStatusChanged.rawValue,
                       "WebServerStatusChanged")
    }
}
