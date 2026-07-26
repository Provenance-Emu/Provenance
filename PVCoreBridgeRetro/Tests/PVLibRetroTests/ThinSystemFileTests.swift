//
//  ThinSystemFileTests.swift
//  PVLibRetroTests
//
//  Tests for the thin-wrapper buildbot system-file auto-download:
//   - ThinSystemFileManifest lookup by core id + stamp naming
//   - ThinSystemFileProvisioner with a stubbed downloader covering
//     success / 404 / offline / corrupt-archive / idempotent-skip.
//

import Testing
import Foundation
import PVArchiving
@testable import PVLibRetro

// MARK: - Manifest lookup tests

struct ThinSystemFileManifestTests {

    @Test func lookup_ppsspp_matchesCaseInsensitively() {
        #expect(ThinSystemFileManifest.entry(forCoreID: "ppsspp_libretro") != nil)
        #expect(ThinSystemFileManifest.entry(forCoreID: "PPSSPP") != nil)
        #expect(ThinSystemFileManifest.entry(forCoreID: "ppsspp")?.stampKey == "ppsspp")
    }

    @Test func lookup_ecwolf_and_prboom() {
        #expect(ThinSystemFileManifest.entry(forCoreID: "ecwolf_libretro")?.stampKey == "ecwolf")
        #expect(ThinSystemFileManifest.entry(forCoreID: "prboom_libretro")?.stampKey == "prboom")
    }

    /// MAME / FinalBurn Neo / XRick assets exist on the buildbot but are
    /// deliberately NOT in this manifest: their archives extract into a
    /// `<core>/` subdir, which `ThinSystemAsset` does not model yet, so they
    /// stay on the legacy `LibretroBuildbot` path. Pin that boundary — adding
    /// one here without a destination-subdir field would misplace the files.
    @Test func subdirExtractingCores_areNotManifestServed() {
        #expect(ThinSystemFileManifest.entry(forCoreID: "mame2003_plus_libretro") == nil)
        #expect(ThinSystemFileManifest.entry(forCoreID: "mame2010_libretro") == nil)
        #expect(ThinSystemFileManifest.entry(forCoreID: "fbneo_libretro") == nil)
        #expect(ThinSystemFileManifest.entry(forCoreID: "xrick_libretro") == nil)
    }

    @Test func lookup_unknownCore_returnsNil() {
        #expect(ThinSystemFileManifest.entry(forCoreID: "snes9x_libretro") == nil)
        #expect(ThinSystemFileManifest.entry(forCoreID: "") == nil)
    }

    @Test func ppsspp_assetURL_isExpectedBuildbotZip() {
        let entry = ThinSystemFileManifest.entry(forCoreID: "ppsspp")
        #expect(entry?.assets.first?.sourceURL.absoluteString
                == "https://buildbot.libretro.com/assets/system/PPSSPP.zip")
    }

    /// `asset(_:displayName:)` silently drops the asset when `URL(string:)`
    /// fails, so an empty list means a malformed (e.g. unencoded) file name.
    /// Every registered entry must yield exactly one well-formed buildbot URL.
    @Test func everyEntry_hasAWellFormedBuildbotAsset() {
        for entry in ThinSystemFileManifest.entries {
            #expect(entry.assets.count == 1,
                    "entry '\(entry.stampKey)' lost its asset to a malformed URL")
            #expect(entry.assets.first?.sourceURL.absoluteString
                        .hasPrefix(ThinSystemFileManifest.systemBaseURL) == true)
        }
    }

    @Test func stampFileName_format() {
        #expect(ThinSystemFileManifest.stampFileName(forStampKey: "ppsspp") == ".pv_assets_ppsspp.stamp")
    }
}

// MARK: - Stub downloader

/// Test double implementing `ThinSystemFileDownloading`.
private final class StubDownloader: ThinSystemFileDownloading, @unchecked Sendable {
    enum Mode {
        /// Return a copy of this local zip fixture.
        case succeed(fixture: URL)
        /// Throw an HTTP error with this status (e.g. 404).
        case httpError(Int)
        /// Throw a transport (offline) error.
        case offline
        /// Return a non-archive payload (corrupt archive).
        case corrupt
    }

    let mode: Mode
    private(set) var downloadCount = 0
    private let lock = NSLock()

    init(mode: Mode) { self.mode = mode }

    func download(from url: URL) async throws -> URL {
        lock.lock(); downloadCount += 1; lock.unlock()
        switch mode {
        case let .succeed(fixture):
            // Copy the fixture so the provisioner can consume (delete) it.
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("dl_\(UUID().uuidString).zip")
            try FileManager.default.copyItem(at: fixture, to: dest)
            return dest
        case let .httpError(code):
            throw ThinSystemFileProvisioner.ProvisionError.httpStatus(code)
        case .offline:
            throw URLError(.notConnectedToInternet)
        case .corrupt:
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("corrupt_\(UUID().uuidString).zip")
            try Data("not a zip".utf8).write(to: dest)
            return dest
        }
    }
}

// MARK: - Provisioner tests

struct ThinSystemFileProvisionerTests {

    /// Create a fresh temp system directory for a test, returns its URL.
    private func makeSystemDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pv_sysfiles_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Build a valid zip fixture containing one file named `prboom.wad`.
    private func makePrBoomZipFixture() throws -> URL {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("fixture_src_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data("WAD-DATA".utf8).write(to: staging.appendingPathComponent("prboom.wad"))
        let zip = FileManager.default.temporaryDirectory
            .appendingPathComponent("fixture_\(UUID().uuidString).zip")
        try ArchiveManager.shared.createZipArchive(at: zip, from: staging)
        try? FileManager.default.removeItem(at: staging)
        return zip
    }

    private func cleanup(_ urls: URL...) {
        for u in urls { try? FileManager.default.removeItem(at: u) }
    }

    @Test func success_extractsFilesAndWritesStamp() async throws {
        let sysDir = try makeSystemDir()
        let fixture = try makePrBoomZipFixture()
        defer { cleanup(sysDir, fixture) }

        let stub = StubDownloader(mode: .succeed(fixture: fixture))
        let provisioner = ThinSystemFileProvisioner(downloader: stub)
        await provisioner.provision(coreId: "prboom_libretro", systemDirectory: sysDir.path)

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: sysDir.appendingPathComponent("prboom.wad").path))
        #expect(fm.fileExists(atPath: sysDir.appendingPathComponent(".pv_assets_prboom.stamp").path))
        #expect(stub.downloadCount == 1)
    }

    @Test func idempotent_secondRunSkipsDownload() async throws {
        let sysDir = try makeSystemDir()
        let fixture = try makePrBoomZipFixture()
        defer { cleanup(sysDir, fixture) }

        let stub = StubDownloader(mode: .succeed(fixture: fixture))
        let provisioner = ThinSystemFileProvisioner(downloader: stub)
        await provisioner.provision(coreId: "prboom_libretro", systemDirectory: sysDir.path)
        await provisioner.provision(coreId: "prboom_libretro", systemDirectory: sysDir.path)

        // Second run sees the stamp and never re-downloads.
        #expect(stub.downloadCount == 1)
    }

    @Test func httpError_noStampNoScratchLeftovers() async throws {
        let sysDir = try makeSystemDir()
        defer { cleanup(sysDir) }

        let stub = StubDownloader(mode: .httpError(404))
        let provisioner = ThinSystemFileProvisioner(downloader: stub)
        await provisioner.provision(coreId: "prboom_libretro", systemDirectory: sysDir.path)

        let fm = FileManager.default
        // No stamp → retries next launch.
        #expect(!fm.fileExists(atPath: sysDir.appendingPathComponent(".pv_assets_prboom.stamp").path))
        // No scratch dir or asset file left behind.
        let contents = try fm.contentsOfDirectory(atPath: sysDir.path)
        #expect(contents.isEmpty)
    }

    @Test func offline_isIsolatedAndLeavesNoStamp() async throws {
        let sysDir = try makeSystemDir()
        defer { cleanup(sysDir) }

        let stub = StubDownloader(mode: .offline)
        let provisioner = ThinSystemFileProvisioner(downloader: stub)
        await provisioner.provision(coreId: "prboom_libretro", systemDirectory: sysDir.path)

        #expect(!FileManager.default.fileExists(
            atPath: sysDir.appendingPathComponent(".pv_assets_prboom.stamp").path))
    }

    @Test func corruptArchive_cleansUpAndLeavesNoStamp() async throws {
        let sysDir = try makeSystemDir()
        defer { cleanup(sysDir) }

        let stub = StubDownloader(mode: .corrupt)
        let provisioner = ThinSystemFileProvisioner(downloader: stub)
        await provisioner.provision(coreId: "prboom_libretro", systemDirectory: sysDir.path)

        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: sysDir.appendingPathComponent(".pv_assets_prboom.stamp").path))
        let contents = try fm.contentsOfDirectory(atPath: sysDir.path)
        #expect(contents.isEmpty)
    }

    @Test func unknownCore_isNoOp() async throws {
        let sysDir = try makeSystemDir()
        let fixture = try makePrBoomZipFixture()
        defer { cleanup(sysDir, fixture) }

        let stub = StubDownloader(mode: .succeed(fixture: fixture))
        let provisioner = ThinSystemFileProvisioner(downloader: stub)
        await provisioner.provision(coreId: "snes9x_libretro", systemDirectory: sysDir.path)

        #expect(stub.downloadCount == 0)
        let contents = try FileManager.default.contentsOfDirectory(atPath: sysDir.path)
        #expect(contents.isEmpty)
    }

    /// Provisioning must not clobber a file the user already placed.
    @Test func existingFile_isPreserved() async throws {
        let sysDir = try makeSystemDir()
        let fixture = try makePrBoomZipFixture()
        defer { cleanup(sysDir, fixture) }

        // Pre-place a user prboom.wad with distinct contents.
        let userFile = sysDir.appendingPathComponent("prboom.wad")
        try Data("USER-WAD".utf8).write(to: userFile)

        let stub = StubDownloader(mode: .succeed(fixture: fixture))
        let provisioner = ThinSystemFileProvisioner(downloader: stub)
        await provisioner.provision(coreId: "prboom_libretro", systemDirectory: sysDir.path)

        let onDisk = try String(contentsOf: userFile, encoding: .utf8)
        #expect(onDisk == "USER-WAD", "existing user file must not be overwritten")
    }
}
