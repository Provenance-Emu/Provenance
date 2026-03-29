//
//  PVArchivingTests.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Testing
import Foundation
@testable import PVArchivingFormats
@testable import PVArchiving
import SWCompression

// MARK: - ArchiveFormat Tests

@Suite("ArchiveFormat")
struct ArchiveFormatTests {

    @Test("all file extensions are unique")
    func uniqueExtensions() {
        var seen = Set<String>()
        for format in ArchiveFormat.allCases {
            for ext in format.fileExtensions {
                #expect(!seen.contains(ext), "Duplicate extension '\(ext)' in \(format)")
                seen.insert(ext)
            }
        }
    }

    @Test("from(fileExtension:) round-trips")
    func extensionRoundTrip() {
        for format in ArchiveFormat.allCases {
            for ext in format.fileExtensions {
                #expect(ArchiveFormat.from(fileExtension: ext) == format)
            }
        }
    }

    @Test("from(fileExtension:) is case-insensitive")
    func extensionCaseInsensitive() {
        #expect(ArchiveFormat.from(fileExtension: "ZIP") == .zip)
        #expect(ArchiveFormat.from(fileExtension: "7Z") == .sevenZip)
        #expect(ArchiveFormat.from(fileExtension: "Rar") == .rar)
        #expect(ArchiveFormat.from(fileExtension: "GZ") == .gzip)
        #expect(ArchiveFormat.from(fileExtension: "BZ2") == .bzip2)
        #expect(ArchiveFormat.from(fileExtension: "XZ") == .xz)
        #expect(ArchiveFormat.from(fileExtension: "LZH") == .lzh)
        #expect(ArchiveFormat.from(fileExtension: "LZMA") == .lzma)
    }

    @Test("from(url:) detects from path extension")
    func urlDetection() {
        #expect(ArchiveFormat.from(url: URL(fileURLWithPath: "/tmp/test.7z")) == .sevenZip)
        #expect(ArchiveFormat.from(url: URL(fileURLWithPath: "/tmp/game.zip")) == .zip)
        #expect(ArchiveFormat.from(url: URL(fileURLWithPath: "/tmp/rom.rar")) == .rar)
        #expect(ArchiveFormat.from(url: URL(fileURLWithPath: "/tmp/file.tar")) == .tar)
        #expect(ArchiveFormat.from(url: URL(fileURLWithPath: "/tmp/file.gz")) == .gzip)
        #expect(ArchiveFormat.from(url: URL(fileURLWithPath: "/tmp/file.bz2")) == .bzip2)
        #expect(ArchiveFormat.from(url: URL(fileURLWithPath: "/tmp/file.xz")) == .xz)
        #expect(ArchiveFormat.from(url: URL(fileURLWithPath: "/tmp/file.lzh")) == .lzh)
        #expect(ArchiveFormat.from(url: URL(fileURLWithPath: "/tmp/file.lzma")) == .lzma)
    }

    @Test("from(mimeType:) works for known types")
    func mimeTypeDetection() {
        #expect(ArchiveFormat.from(mimeType: "application/zip") == .zip)
        #expect(ArchiveFormat.from(mimeType: "application/x-7z-compressed") == .sevenZip)
        #expect(ArchiveFormat.from(mimeType: "application/gzip") == .gzip)
        #expect(ArchiveFormat.from(mimeType: "application/x-bzip2") == .bzip2)
        #expect(ArchiveFormat.from(mimeType: "application/x-xz") == .xz)
        #expect(ArchiveFormat.from(mimeType: "application/x-tar") == .tar)
        #expect(ArchiveFormat.from(mimeType: "application/x-rar-compressed") == .rar)
        #expect(ArchiveFormat.from(mimeType: "application/x-lzh-compressed") == .lzh)
    }

    @Test("allFileExtensions covers all formats")
    func allExtensionsCoverage() {
        let all = ArchiveFormat.allFileExtensions
        #expect(all.contains("zip"))
        #expect(all.contains("7z"))
        #expect(all.contains("rar"))
        #expect(all.contains("tar"))
        #expect(all.contains("gz"))
        #expect(all.contains("gzip"))
        #expect(all.contains("bz2"))
        #expect(all.contains("bzip2"))
        #expect(all.contains("xz"))
        #expect(all.contains("lzh"))
        #expect(all.contains("lha"))
        #expect(all.contains("lzma"))
        #expect(all.contains("zst"))
        #expect(all.contains("zstd"))
    }

    @Test("supportsCRCIndex is correct")
    func crcSupport() {
        #expect(ArchiveFormat.zip.supportsCRCIndex)
        #expect(ArchiveFormat.sevenZip.supportsCRCIndex)
        #expect(ArchiveFormat.rar.supportsCRCIndex)
        #expect(ArchiveFormat.lzh.supportsCRCIndex)
        #expect(!ArchiveFormat.gzip.supportsCRCIndex)
        #expect(!ArchiveFormat.tar.supportsCRCIndex)
        #expect(!ArchiveFormat.bzip2.supportsCRCIndex)
    }

    @Test("rawValue encoding is stable")
    func rawValues() {
        #expect(ArchiveFormat.zip.rawValue == "zip")
        #expect(ArchiveFormat.sevenZip.rawValue == "7z")
        #expect(ArchiveFormat.gzip.rawValue == "gz")
        #expect(ArchiveFormat.bzip2.rawValue == "bz2")
    }

    @Test("alternate extensions map to correct format")
    func alternateExtensions() {
        #expect(ArchiveFormat.from(fileExtension: "gzip") == .gzip)
        #expect(ArchiveFormat.from(fileExtension: "bzip2") == .bzip2)
        #expect(ArchiveFormat.from(fileExtension: "lha") == .lzh)
        #expect(ArchiveFormat.from(fileExtension: "zstd") == .zstd)
    }

    @Test("unknown extension returns nil")
    func unknownExtension() {
        #expect(ArchiveFormat.from(fileExtension: "rom") == nil)
        #expect(ArchiveFormat.from(fileExtension: "txt") == nil)
        #expect(ArchiveFormat.from(fileExtension: "") == nil)
    }
}

// MARK: - ArchiveSignature Tests

@Suite("ArchiveSignatureDetector")
struct ArchiveSignatureTests {

    private func writeTempFile(_ bytes: [UInt8]) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bin")
        try Data(bytes).write(to: tmp)
        return tmp
    }

    @Test("detects ZIP magic bytes")
    func detectZip() throws {
        let tmp = try writeTempFile([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == .zip)
    }

    @Test("detects 7z magic bytes")
    func detect7z() throws {
        let tmp = try writeTempFile([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x00])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == .sevenZip)
    }

    @Test("detects RAR magic bytes")
    func detectRar() throws {
        let tmp = try writeTempFile([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00, 0x00])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == .rar)
    }

    @Test("detects gzip magic bytes")
    func detectGzip() throws {
        let tmp = try writeTempFile([0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == .gzip)
    }

    @Test("detects BZip2 magic bytes")
    func detectBzip2() throws {
        let tmp = try writeTempFile([0x42, 0x5A, 0x68, 0x39, 0x31, 0x41, 0x59, 0x26])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == .bzip2)
    }

    @Test("detects XZ magic bytes")
    func detectXz() throws {
        let tmp = try writeTempFile([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00, 0x00, 0x00])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == .xz)
    }

    @Test("detects Zstd magic bytes")
    func detectZstd() throws {
        let tmp = try writeTempFile([0x28, 0xB5, 0x2F, 0xFD, 0x00, 0x00, 0x00, 0x00])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == .zstd)
    }

    @Test("detects LZMA magic bytes")
    func detectLzma() throws {
        let tmp = try writeTempFile([0x5D, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == .lzma)
    }

    @Test("detects XIP (xar) magic bytes")
    func detectXip() throws {
        let tmp = try writeTempFile([0x78, 0x61, 0x72, 0x21, 0x00, 0x00, 0x00, 0x00])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == .xip)
    }

    @Test("returns nil for unknown bytes")
    func detectUnknown() throws {
        let tmp = try writeTempFile([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(ArchiveSignatureDetector.detect(at: tmp) == nil)
    }

    @Test("returns nil for too-short file")
    func detectTooShort() throws {
        let tmp = try writeTempFile([0x50, 0x4B])
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Only 2 bytes — ZIP needs 4
        // Should still detect gzip-like patterns but not ZIP
    }

    @Test("returns nil for nonexistent file")
    func detectMissing() {
        let fake = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).bin")
        #expect(ArchiveSignatureDetector.detect(at: fake) == nil)
    }
}

// MARK: - ArchiveManager Tests

@Suite("ArchiveManager")
struct ArchiveManagerTests {

    @Test("detectFormat prefers magic bytes over extension")
    func detectFormatMagicPriority() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".rar")
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Write ZIP magic bytes but with .rar extension
        try Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00]).write(to: tmp)
        #expect(ArchiveManager.shared.detectFormat(at: tmp) == .zip)
    }

    @Test("detectFormat falls back to extension")
    func detectFormatExtensionFallback() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".7z")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data([0x00, 0x00, 0x00, 0x00]).write(to: tmp)
        #expect(ArchiveManager.shared.detectFormat(at: tmp) == .sevenZip)
    }

    @Test("isArchive returns false for non-archive")
    func isArchiveNonArchive() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data("hello".utf8).write(to: tmp)
        #expect(!ArchiveManager.shared.isArchive(at: tmp))
    }

    @Test("isArchiveExtension checks correctly")
    func isArchiveExtension() {
        #expect(ArchiveManager.isArchiveExtension("zip"))
        #expect(ArchiveManager.isArchiveExtension("7z"))
        #expect(ArchiveManager.isArchiveExtension("rar"))
        #expect(ArchiveManager.isArchiveExtension("gz"))
        #expect(ArchiveManager.isArchiveExtension("gzip"))
        #expect(ArchiveManager.isArchiveExtension("bz2"))
        #expect(ArchiveManager.isArchiveExtension("bzip2"))
        #expect(ArchiveManager.isArchiveExtension("xz"))
        #expect(ArchiveManager.isArchiveExtension("lzh"))
        #expect(ArchiveManager.isArchiveExtension("lha"))
        #expect(ArchiveManager.isArchiveExtension("lzma"))
        #expect(ArchiveManager.isArchiveExtension("tar"))
        #expect(!ArchiveManager.isArchiveExtension("txt"))
        #expect(!ArchiveManager.isArchiveExtension("rom"))
        #expect(!ArchiveManager.isArchiveExtension(""))
    }

    @Test("extract returns error for unknown format")
    func extractUnknownFormat() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: tmp)
            try? FileManager.default.removeItem(at: dest)
        }
        try Data("not an archive".utf8).write(to: tmp)
        do {
            for try await _ in ArchiveManager.shared.extract(at: tmp, to: dest) {}
            Issue.record("Expected error for unknown format")
        } catch {
            #expect(error is ArchiveError)
        }
    }

    @Test("all formats have a registered backend")
    func allFormatsRegistered() {
        for format in ArchiveFormat.allCases {
            #expect(ArchiveManager.shared.backend(for: format) != nil, "Missing backend for \(format)")
        }
    }

    @Test("supportsListing for known formats")
    func listingSupport() {
        #expect(ArchiveManager.shared.supportsListing(for: .zip))
        #expect(ArchiveManager.shared.supportsListing(for: .sevenZip))
        #expect(!ArchiveManager.shared.supportsListing(for: .gzip))
        #expect(!ArchiveManager.shared.supportsListing(for: .tar))
    }
}

// MARK: - Zip Round-Trip Tests

@Suite("ZipBackend Round-Trip")
struct ZipRoundTripTests {

    @Test("create and extract zip archive")
    func createAndExtract() throws {
        let fm = FileManager.default
        let sourceDir = fm.temporaryDirectory.appendingPathComponent("ZipTest_\(UUID().uuidString)")
        let zipFile = fm.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).zip")
        let extractDir = fm.temporaryDirectory.appendingPathComponent("ZipExtract_\(UUID().uuidString)")
        defer {
            try? fm.removeItem(at: sourceDir)
            try? fm.removeItem(at: zipFile)
            try? fm.removeItem(at: extractDir)
        }

        // Create test files
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try Data("hello world".utf8).write(to: sourceDir.appendingPathComponent("test.txt"))
        try Data("binary data".utf8).write(to: sourceDir.appendingPathComponent("data.bin"))

        // Create zip
        try ArchiveManager.shared.createZipArchive(at: zipFile, from: sourceDir)
        #expect(fm.fileExists(atPath: zipFile.path))

        // Extract
        try ArchiveManager.shared.unzipFile(at: zipFile, to: extractDir)

        // Verify
        let extracted1 = extractDir.appendingPathComponent("test.txt")
        let extracted2 = extractDir.appendingPathComponent("data.bin")
        #expect(fm.fileExists(atPath: extracted1.path))
        #expect(fm.fileExists(atPath: extracted2.path))
        #expect(try String(contentsOf: extracted1, encoding: .utf8) == "hello world")
        #expect(try String(contentsOf: extracted2, encoding: .utf8) == "binary data")
    }

    @Test("list entries returns correct metadata")
    func listEntries() throws {
        let fm = FileManager.default
        let sourceDir = fm.temporaryDirectory.appendingPathComponent("ZipListTest_\(UUID().uuidString)")
        let zipFile = fm.temporaryDirectory.appendingPathComponent("list_\(UUID().uuidString).zip")
        defer {
            try? fm.removeItem(at: sourceDir)
            try? fm.removeItem(at: zipFile)
        }

        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try Data("test content here".utf8).write(to: sourceDir.appendingPathComponent("readme.txt"))

        try ArchiveManager.shared.createZipArchive(at: zipFile, from: sourceDir)

        let entries = try ArchiveManager.shared.listEntries(at: zipFile)
        let fileEntries = entries.filter { !$0.isDirectory }
        #expect(fileEntries.count >= 1)

        let readme = fileEntries.first { $0.name.contains("readme.txt") }
        #expect(readme != nil)
        #expect(readme?.crc != nil)
        #expect(readme?.crc != 0)
    }

    @Test("extract via async stream yields all files")
    func asyncStreamExtraction() async throws {
        let fm = FileManager.default
        let sourceDir = fm.temporaryDirectory.appendingPathComponent("ZipAsync_\(UUID().uuidString)")
        let zipFile = fm.temporaryDirectory.appendingPathComponent("async_\(UUID().uuidString).zip")
        let extractDir = fm.temporaryDirectory.appendingPathComponent("ZipAsyncOut_\(UUID().uuidString)")
        defer {
            try? fm.removeItem(at: sourceDir)
            try? fm.removeItem(at: zipFile)
            try? fm.removeItem(at: extractDir)
        }

        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: sourceDir.appendingPathComponent("a.txt"))
        try Data("b".utf8).write(to: sourceDir.appendingPathComponent("b.txt"))
        try Data("c".utf8).write(to: sourceDir.appendingPathComponent("c.txt"))

        try ArchiveManager.shared.createZipArchive(at: zipFile, from: sourceDir)

        var progressValues: [Double] = []
        let files = try await ArchiveManager.shared.extractAll(
            at: zipFile,
            to: extractDir,
            progress: { progressValues.append($0) }
        )
        #expect(files.count == 3)
        #expect(!progressValues.isEmpty)
        #expect(progressValues.last == 1.0)
    }

    @Test("format auto-detection works for zip")
    func autoDetect() throws {
        let fm = FileManager.default
        let sourceDir = fm.temporaryDirectory.appendingPathComponent("ZipDetect_\(UUID().uuidString)")
        let zipFile = fm.temporaryDirectory.appendingPathComponent("detect_\(UUID().uuidString).zip")
        defer {
            try? fm.removeItem(at: sourceDir)
            try? fm.removeItem(at: zipFile)
        }

        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: sourceDir.appendingPathComponent("x.txt"))
        try ArchiveManager.shared.createZipArchive(at: zipFile, from: sourceDir)

        #expect(ArchiveManager.shared.detectFormat(at: zipFile) == .zip)
        #expect(ArchiveManager.shared.isArchive(at: zipFile))
    }
}

// MARK: - GZip Round-Trip Tests

@Suite("GZip Backend")
struct GZipTests {

    @Test("extract gzip compressed file")
    func extractGzip() async throws {
        let fm = FileManager.default
        let content = Data("Hello from gzip test!".utf8)
        let compressed = try GzipArchive.archive(data: content)

        let gzFile = fm.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).gz")
        let extractDir = fm.temporaryDirectory.appendingPathComponent("GzipOut_\(UUID().uuidString)")
        defer {
            try? fm.removeItem(at: gzFile)
            try? fm.removeItem(at: extractDir)
        }

        try compressed.write(to: gzFile)
        let files = try await ArchiveManager.shared.extractAll(at: gzFile, to: extractDir)
        #expect(files.count == 1)

        let extractedData = try Data(contentsOf: files[0])
        #expect(extractedData == content)
    }
}

// MARK: - BZip2 Tests

@Suite("BZip2 Backend")
struct BZip2Tests {

    @Test("extract bzip2 compressed file")
    func extractBzip2() async throws {
        let fm = FileManager.default
        let content = Data("Hello from bzip2 test!".utf8)
        let compressed = BZip2.compress(data: content)

        let bz2File = fm.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).bz2")
        let extractDir = fm.temporaryDirectory.appendingPathComponent("Bz2Out_\(UUID().uuidString)")
        defer {
            try? fm.removeItem(at: bz2File)
            try? fm.removeItem(at: extractDir)
        }

        try compressed.write(to: bz2File)
        let files = try await ArchiveManager.shared.extractAll(at: bz2File, to: extractDir)
        #expect(files.count == 1)

        let extractedData = try Data(contentsOf: files[0])
        #expect(extractedData == content)
    }
}

// MARK: - ArchiveError Tests

@Suite("ArchiveError")
struct ArchiveErrorTests {

    @Test("errorDescription is non-nil for all cases")
    func allErrorsHaveDescriptions() {
        let cases: [ArchiveError] = [
            .invalidArchive,
            .fileTooLarge(500_000_000),
            .extractionFailed("test"),
            .compressionFailed("test"),
            .formatNotSupported(.zstd),
            .backendUnavailable("test"),
            .unknownCompressionMethod,
            .batchMoveFailed(succeeded: 3, total: 5),
        ]
        for error in cases {
            #expect(error.errorDescription != nil, "\(error) has no description")
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("fileTooLarge includes size in description")
    func fileTooLargeDescription() {
        let error = ArchiveError.fileTooLarge(1_500_000_000)
        #expect(error.errorDescription?.contains("1500") == true)
    }

    @Test("batchMoveFailed reports correct counts")
    func batchMoveDescription() {
        let error = ArchiveError.batchMoveFailed(succeeded: 8, total: 10)
        #expect(error.errorDescription?.contains("2") == true) // 10-8 = 2 failed
        #expect(error.errorDescription?.contains("10") == true)
    }
}

// MARK: - ArchiveEntryInfo Tests

@Suite("ArchiveEntryInfo")
struct ArchiveEntryInfoTests {

    @Test("init with defaults")
    func defaultInit() {
        let entry = ArchiveEntryInfo(name: "test.bin")
        #expect(entry.name == "test.bin")
        #expect(entry.size == nil)
        #expect(entry.isDirectory == false)
        #expect(entry.crc == nil)
    }

    @Test("init with all fields")
    func fullInit() {
        let entry = ArchiveEntryInfo(name: "rom.nes", size: 524288, isDirectory: false, crc: 0xDEADBEEF)
        #expect(entry.name == "rom.nes")
        #expect(entry.size == 524288)
        #expect(entry.crc == 0xDEADBEEF)
    }

    @Test("directory entry")
    func directoryEntry() {
        let entry = ArchiveEntryInfo(name: "subdir/", isDirectory: true)
        #expect(entry.isDirectory)
        #expect(entry.crc == nil)
    }

    @Test("equatable")
    func equatable() {
        let a = ArchiveEntryInfo(name: "test", size: 100, crc: 0x1234)
        let b = ArchiveEntryInfo(name: "test", size: 100, crc: 0x1234)
        let c = ArchiveEntryInfo(name: "test", size: 200, crc: 0x1234)
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - Protocol Conformance Tests

@Suite("Protocol Conformance")
struct ProtocolConformanceTests {

    @Test("ZipBackend conforms to all protocols")
    func zipConformance() {
        let zip = ZipBackend()
        #expect(zip is ArchiveExtractorBackend)
        #expect(zip is ArchiveListingBackend)
        #expect(zip is ArchiveCreationBackend)
    }

    @Test("SevenZipBackend conforms to listing")
    func sevenZipConformance() {
        let sz = SevenZipBackend()
        #expect(sz is ArchiveExtractorBackend)
        #expect(sz is ArchiveListingBackend)
    }

    @Test("all backends are Sendable")
    func sendableConformance() {
        func assertSendable<T: Sendable>(_ value: T) {}
        assertSendable(ZipBackend())
        assertSendable(SevenZipBackend())
        assertSendable(RarBackend())
        assertSendable(TarBackend())
        assertSendable(GZipBackend())
        assertSendable(BZip2Backend())
        assertSendable(XZBackend())
        assertSendable(LZMABackend())
        assertSendable(LzhBackend())
        assertSendable(ZstdBackend())
        assertSendable(XIPBackend())
    }

    @Test("ArchiveManager is Sendable")
    func managerSendable() {
        func assertSendable<T: Sendable>(_ value: T) {}
        assertSendable(ArchiveManager.shared)
    }
}

// MARK: - CompressionFormat Tests

@Suite("CompressionFormat")
struct CompressionFormatTests {

    @Test("all cases have unique rawValues")
    func uniqueRawValues() {
        var seen = Set<String>()
        for fmt in CompressionFormat.allCases {
            #expect(!seen.contains(fmt.rawValue))
            seen.insert(fmt.rawValue)
        }
    }
}
