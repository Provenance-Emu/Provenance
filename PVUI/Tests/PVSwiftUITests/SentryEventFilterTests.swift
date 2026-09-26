//
//  SentryEventFilterTests.swift
//  PVSwiftUITests
//

import Testing
@testable import PVSwiftUI

@Suite("SentryEventFilter", .serialized)
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

    @Test("Drops HTTPClientError 404 from libretro thumbnails (PROVENANCE-17Y)")
    func dropsLibretroThumbnail404() {
        let snapshot = SentryEventSnapshot(
            mechanismType: "HTTPClientError",
            exceptionValue: "HTTP Client Error with status code: 404",
            exceptionType: "HTTPClientError",
            level: "error",
            transaction: nil,
            requestURL: "https://thumbnails.libretro.com/Nintendo%20-%20Wii/Named_Boxarts/WWE%20'13%20(Europe).png",
            title: nil,
            tags: [:],
            frames: []
        )
        #expect(!SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Drops 404 from HEAD existence probes on any host")
    func dropsHEADProbe404() {
        let snapshot = SentryEventSnapshot(
            mechanismType: "HTTPClientError",
            exceptionValue: "HTTP Client Error with status code: 404",
            exceptionType: "HTTPClientError",
            level: "error",
            transaction: nil,
            requestURL: "https://provenance-emu.com/api/v1/games",
            requestMethod: "HEAD",
            title: nil,
            tags: [:],
            frames: []
        )
        #expect(!SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Drops unsymbolicated mx_cpu_exception with no app frames (PROVENANCE-251)")
    func dropsSystemOnlyCPUException() {
        let snapshot = SentryEventSnapshot(
            mechanismType: "mx_cpu_exception",
            exceptionValue: "MXCPUException totalCPUTime:90 sec totalSampledTime:154.011 sec",
            exceptionType: "MXCPUException",
            level: "warning",
            transaction: nil,
            requestURL: nil,
            title: nil,
            tags: [:],
            frames: [
                SentryEventFrame(function: nil, filename: nil, package: "libsystem_pthread.dylib", inApp: false),
                SentryEventFrame(function: nil, filename: nil, package: "AudioToolboxCore", inApp: false)
            ]
        )
        #expect(!SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Drops unsymbolicated mx_cpu_exception in an emulator binary")
    func dropsEmulatorBinaryCPUException() {
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
                SentryEventFrame(function: nil, filename: nil, package: "PVCoreAudio", inApp: false)
            ]
        )
        #expect(!SentryEventFilter.shouldReport(snapshot))
    }

    @Test("Keeps unsymbolicated mx_cpu_exception in a PV* framework")
    func keepsPVFrameworkCPUException() {
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
                SentryEventFrame(function: nil, filename: nil, package: "libsystem_pthread.dylib", inApp: false),
                SentryEventFrame(function: nil, filename: nil, package: "PVLibrary", inApp: false)
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
        let lookup = SentryEventFilter.isKnownROMExtension
        SentryEventFilter.isKnownROMExtension = { $0 == "z64" }
        defer { SentryEventFilter.isKnownROMExtension = lookup }
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
