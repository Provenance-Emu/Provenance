//
//  SentryEventFilterTests.swift
//  PVSwiftUITests
//

import Testing
@testable import PVSwiftUI

@Suite("SentryEventFilter")
struct SentryEventFilterTests {

    @Test("Drops HTTPClientError for external artwork CDN 503")
    func dropsExternalCDNHTTPClientError() {
        let snapshot = SentryEventSnapshot(
            mechanismType: "HTTPClientError",
            exceptionValue: "HTTP Client Error with status code: 503",
            exceptionType: "HTTPClientError",
            level: "error",
            transaction: "PVEmulatorViewController",
            requestURL: nil,
            title: nil,
            tags: ["url": "https://cdn.thegamesdb.net/images/original/boxart/back/5223-1.jpg"],
            frames: []
        )
        #expect(!SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Keeps HTTPClientError for app-owned hosts")
    func keepsAppOwnedHTTPClientError() {
        let snapshot = SentryEventSnapshot(
            mechanismType: "HTTPClientError",
            exceptionValue: "HTTP Client Error with status code: 404",
            exceptionType: "HTTPClientError",
            level: "error",
            transaction: nil,
            requestURL: "https://provenance-emu.com/api/v1/games",
            title: nil,
            tags: [:],
            frames: []
        )
        #expect(SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Drops mx_cpu_exception inside emulator frames")
    func dropsEmulatorCPUException() {
        let snapshot = SentryEventSnapshot(
            mechanismType: "mx_cpu_exception",
            exceptionValue: "MXCPUException totalCPUTime:90 sec",
            exceptionType: "MXCPUException",
            level: "warning",
            transaction: nil,
            requestURL: nil,
            title: nil,
            tags: [:],
            frames: [
                SentryEventFrame(function: "CachedInterpreter::Run", filename: nil, package: nil, inApp: false)
            ]
        )
        #expect(!SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Keeps mx_cpu_exception outside emulator")
    func keepsNonEmulatorCPUException() {
        let snapshot = SentryEventSnapshot(
            mechanismType: "mx_cpu_exception",
            exceptionValue: "MXCPUException totalCPUTime:90 sec",
            exceptionType: "MXCPUException",
            level: "warning",
            transaction: nil,
            requestURL: nil,
            title: nil,
            tags: [:],
            frames: [
                SentryEventFrame(function: "LibraryView.body", filename: "LibraryView.swift", package: "Provenance", inApp: true)
            ]
        )
        #expect(SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Drops mx_disk_write_exception in artwork pipeline")
    func dropsArtworkDiskWriteException() {
        let snapshot = SentryEventSnapshot(
            mechanismType: "mx_disk_write_exception",
            exceptionValue: "MXDiskWriteException totalWritesCaused:4,294.969 MB",
            exceptionType: "MXDiskWriteException",
            level: "warning",
            transaction: nil,
            requestURL: nil,
            title: nil,
            tags: [:],
            frames: [
                SentryEventFrame(
                    function: "closure in ArtworkSearchQueue.retryFailedArtworkDownloads",
                    filename: "ArtworkSearchQueue.swift",
                    package: "Provenance",
                    inApp: true
                )
            ]
        )
        #expect(!SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Drops intentional ROM loadFile IO on main thread")
    func dropsROMLoadFileIO() {
        let snapshot = SentryEventSnapshot(
            mechanismType: nil,
            exceptionValue: "Legend of Zelda, The - Ocarina of Time (U) (V1.2) [!].z64",
            exceptionType: "File IO on Main Thread",
            level: "info",
            transaction: "PVEmulatorViewController",
            requestURL: nil,
            title: "File IO on Main Thread",
            tags: [:],
            frames: [
                SentryEventFrame(function: "loadFile(atPath:)", filename: "PVEmulatorViewController.swift", package: nil, inApp: true)
            ]
        )
        #expect(!SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Drops degraded UI performance cold-start info")
    func dropsColdStartPerfInfo() {
        let snapshot = SentryEventSnapshot(
            mechanismType: nil,
            exceptionValue: "The application experiences a significant delay during cold start, primarily driven by the Pre Runtime Init phase",
            exceptionType: nil,
            level: "info",
            transaction: nil,
            requestURL: nil,
            title: "Degraded UI Performance",
            tags: [:],
            frames: []
        )
        #expect(!SentryEventFilter.shouldReport(snapshot))
    }
}
