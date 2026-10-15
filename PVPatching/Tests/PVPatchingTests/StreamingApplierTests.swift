//
//  StreamingApplierTests.swift
//  PVPatchingTests
//
//  PatchApplier on top of PVPatchEngine: xdelta, "ignore checksum", hostile patches, the
//  in-flight and cancellation paths, cache-key stability, and a >4 GiB image in bounded memory.
//

import Darwin
import XCTest
@testable import PVPatching

/// The images behind `Resources/xdelta/*.xdelta`; a copy of PVPatchEngine's `FixtureData`.
enum XDeltaFixture {
    private static let vocabulary: [[UInt8]] = [
        "GALE01", "Super Smash Bros", "Melee", "bomb-omb", "texture", "audio", "banner", "opening.bnr",
        "apploader", "fst.bin", "boot.bin", "bi2.bin", "\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}"
    ].map { Array($0.utf8) }

    static func bytes(seed: UInt64, count: Int) -> [UInt8] {
        var state = seed
        func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
        var output = [UInt8]()
        output.reserveCapacity(count + 16)
        while output.count < count {
            let value = next()
            if value & 3 == 0 {
                for shift in stride(from: 0, to: 64, by: 8) { output.append(UInt8(truncatingIfNeeded: value >> UInt64(shift))) }
            } else {
                output.append(contentsOf: vocabulary[Int(value >> 8) % vocabulary.count])
            }
        }
        return Array(output.prefix(count))
    }

    static func lowEntropyBytes(seed: UInt64, count: Int) -> [UInt8] {
        bytes(seed: seed, count: count).map { [0x20, 0x41, 0x42, 0x0A][Int($0) & 3] }
    }

    static func source() -> Data { Data(bytes(seed: 1, count: 300_000)) }

    static func target() -> Data {
        var target = bytes(seed: 1, count: 300_000)
        target.replaceSubrange(1_000..<1_100, with: bytes(seed: 2, count: 100))
        target.insert(contentsOf: bytes(seed: 3, count: 2_000), at: 150_000)
        target.insert(contentsOf: lowEntropyBytes(seed: 5, count: 30_000), at: 200_000)
        target.removeSubrange(280_000..<285_000)
        target.append(contentsOf: bytes(seed: 4, count: 3_500))
        return Data(target)
    }
}

/// Peak resident size while work runs.
private final class ResidentSampler: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: UInt64 = 0
    private var running = true

    static func current() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }

    func start() {
        record()
        Thread.detachNewThread { [self] in
            while isRunning {
                record()
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
    }

    private var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    private func record() {
        let value = Self.current()
        lock.lock()
        peak = max(peak, value)
        lock.unlock()
    }

    func stop() -> UInt64 {
        record()
        lock.lock()
        running = false
        defer { lock.unlock() }
        return peak
    }
}

final class StreamingApplierTests: XCTestCase {
    private var dir: URL!
    private var cacheDir: URL!
    private var applier: PatchApplier!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StreamingApplier-\(UUID().uuidString)", isDirectory: true)
        cacheDir = dir.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        applier = PatchApplier(cache: PatchCache(cacheDirectory: cacheDir))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Helpers

    private func write(_ data: Data, _ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    private func fixture(_ name: String, as fileName: String) throws -> URL {
        let bundled = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "xdelta", subdirectory: "Resources/xdelta"))
        let url = dir.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: bundled, to: url)
        return url
    }

    /// Everything left in the cache that is not a finished entry or a fingerprint sidecar.
    private func strayCacheFiles() -> [String] {
        let all = FileManager.default.enumerator(atPath: cacheDir.path)?.allObjects as? [String] ?? []
        return all.filter { $0.hasSuffix(".partial") }
    }

    /// Entry files and entry directories (a failed apply must leave neither).
    private func cacheEntries() -> [String] {
        let all = FileManager.default.enumerator(atPath: cacheDir.path)?.allObjects as? [String] ?? []
        return all.filter { !$0.hasPrefix(".fingerprints") && !$0.hasSuffix(".partial") }
    }

    private func makeBPS(source: Data, target: Data) -> Data {
        // One TargetRead of the whole target: enough to exercise the CRC checks.
        var body = Array("BPS1".utf8) + encodeVLI(source.count) + encodeVLI(target.count) + encodeVLI(0)
        if !target.isEmpty {
            body += encodeVLI(((target.count - 1) << 2) | 1) + Array(target)
        }
        body += le32(patchCRC32(source)) + le32(patchCRC32(target))
        return Data(body + le32(patchCRC32(Data(body))))
    }

    private func makeUPS(source: Data, target: Data) -> Data {
        var out = Array("UPS1".utf8) + encodeVLI(source.count) + encodeVLI(target.count)
        let count = max(source.count, target.count)
        var index = 0
        var last = 0
        func byte(_ data: Data, _ i: Int) -> UInt8 { i < data.count ? data[i] : 0 }
        while index < count {
            if byte(source, index) == byte(target, index) { index += 1; continue }
            out += encodeVLI(index - last)
            while index < count, byte(source, index) != byte(target, index) {
                out.append(byte(source, index) ^ byte(target, index))
                index += 1
            }
            out.append(0)
            index += 1
            last = index
        }
        out += le32(patchCRC32(source)) + le32(patchCRC32(target))
        return Data(out + le32(patchCRC32(Data(out))))
    }

    // MARK: - xdelta

    func testXDeltaNamedPatchAppliesThroughTheApplier() async throws {
        let rom = try write(XDeltaFixture.source(), "Game.iso")
        let patch = try fixture("basic", as: "Game [Hack].xdelta")

        let artifact = try await applier.apply(patchURL: patch, to: rom)

        XCTAssertEqual(artifact.format, .xdelta)
        XCTAssertEqual(try Data(contentsOf: artifact.url), XDeltaFixture.target())
        XCTAssertEqual(artifact.checkedAgainstSource, true)
        XCTAssertEqual(artifact.patchedCRC32, patchCRC32(XDeltaFixture.target()))
        XCTAssertEqual(artifact.patchedMD5, PatchHashing.md5Hex(XDeltaFixture.target()))
        XCTAssertTrue(strayCacheFiles().isEmpty)
    }

    func testVCDIFFUnderAnyNameIsDetectedByMagic() async throws {
        let rom = try write(XDeltaFixture.source(), "Game.iso")
        let patch = try fixture("basic", as: "Game.vcdiff")
        XCTAssertEqual(PatchFormat.detect(fileAt: patch), .xdelta3)

        let artifact = try await applier.apply(patchURL: patch, to: rom)
        XCTAssertEqual(artifact.format, .xdelta3)
        XCTAssertEqual(try Data(contentsOf: artifact.url), XDeltaFixture.target())
    }

    func testXDeltaWithoutChecksumsCannotVerify() async throws {
        let rom = try write(XDeltaFixture.source(), "Game.iso")
        let patch = try fixture("nochecksum", as: "Game.xdelta")

        let inspection = try PatchInspector().inspect(patchURL: patch)
        XCTAssertFalse(inspection.canVerifyIntegrity)
        XCTAssertEqual(inspection.targetSize, XDeltaFixture.target().count)

        let artifact = try await applier.apply(patchURL: patch, to: rom)
        XCTAssertEqual(artifact.checkedAgainstSource, false)
        XCTAssertEqual(try Data(contentsOf: artifact.url), XDeltaFixture.target())
    }

    func testXDeltaInspectionReportsSizes() throws {
        let patch = try fixture("basic", as: "Game.xdelta")
        let inspection = try PatchInspector().inspect(patchURL: patch)
        XCTAssertEqual(inspection.format, .xdelta)
        XCTAssertTrue(inspection.canVerifyIntegrity)
        XCTAssertEqual(inspection.targetSize, XDeltaFixture.target().count)
        XCTAssertNotNil(inspection.minimumSourceSize)
        XCTAssertNil(inspection.sourceCRC32)
        XCTAssertEqual(inspection.patchSHA256, PatchHashing.sha256Hex(try Data(contentsOf: patch)))
    }

    func testXDeltaWrongSourceIsAMismatch() async throws {
        var wrong = XDeltaFixture.source()
        wrong[50_000] ^= 0xFF
        let rom = try write(wrong, "Game.iso")
        let patch = try fixture("basic", as: "Game.xdelta")

        do {
            _ = try await applier.apply(patchURL: patch, to: rom)
            XCTFail("expected the window adler32 to reject the wrong source")
        } catch PatchError.sourceROMMismatch {
        }
        XCTAssertTrue(strayCacheFiles().isEmpty)
        XCTAssertTrue(cacheEntries().isEmpty)
    }

    func testTruncatedXDeltaIsCorrupt() async throws {
        let rom = try write(XDeltaFixture.source(), "Game.iso")
        let full = try Data(contentsOf: try fixture("basic", as: "full.xdelta"))
        let patch = try write(full.prefix(full.count / 2), "Game.xdelta")

        do {
            _ = try await applier.apply(patchURL: patch, to: rom)
            XCTFail("expected a truncated patch to fail")
        } catch PatchError.corruptPatchFile {
        }
        XCTAssertTrue(cacheEntries().isEmpty)
    }

    // MARK: - Ignore checksum ("Apply anyway")

    func testIgnoreSourceChecksumAppliesBPSToTheWrongROM() async throws {
        let source = Data((0..<4096).map { UInt8($0 & 0xFF) })
        var target = source
        target[100] = 0xAB
        // SourceRead 100, TargetRead 1, SourceRead the rest: the result follows the ROM it is applied to.
        var body = Array("BPS1".utf8) + encodeVLI(source.count) + encodeVLI(target.count) + encodeVLI(0)
        body += encodeVLI((99 << 2) | 0) + encodeVLI((0 << 2) | 1) + [0xAB]
        body += encodeVLI(((source.count - 101 - 1) << 2) | 0)
        body += le32(patchCRC32(source)) + le32(patchCRC32(target))
        let patch = try write(Data(body + le32(patchCRC32(Data(body)))), "Game.bps")
        var other = source
        other[7] ^= 0x55
        let rom = try write(other, "Game.sfc")

        do {
            _ = try await applier.apply(patchURL: patch, to: rom)
            XCTFail("expected the BPS source CRC to reject a different ROM")
        } catch PatchError.sourceROMMismatch {
        }

        let forced = try await applier.apply(
            patchURL: patch, to: rom, options: PatchApplyOptions(ignoreSourceChecksum: true)
        )
        XCTAssertEqual(forced.checkedAgainstSource, false)
        var expected = other
        expected[100] = 0xAB
        XCTAssertEqual(try Data(contentsOf: forced.url), expected)
    }

    func testIgnoreSourceChecksumAppliesUPSToTheWrongROM() async throws {
        let source = Data((0..<2048).map { UInt8(($0 * 7) & 0xFF) })
        var target = source
        target[10] = 0x01
        target[1500] = 0x02
        let patch = try write(makeUPS(source: source, target: target), "Game.ups")
        var other = source
        other[600] ^= 0x10
        let rom = try write(other, "Game.gba")

        do {
            _ = try await applier.apply(patchURL: patch, to: rom)
            XCTFail("expected the UPS source CRC to reject a different ROM")
        } catch PatchError.sourceROMMismatch {
        }

        let forced = try await applier.apply(
            patchURL: patch, to: rom, options: PatchApplyOptions(ignoreSourceChecksum: true)
        )
        XCTAssertEqual(forced.checkedAgainstSource, false)
        var expected = other
        expected[10] = 0x01
        expected[1500] = 0x02
        XCTAssertEqual(try Data(contentsOf: forced.url), expected)
    }

    /// "Apply anyway" in the batch applier used to stop at the pre-check: BPS still threw.
    func testBatchApplyAnywayReachesTheEngine() async throws {
        let source = Data(repeating: 0x33, count: 512)
        var target = source
        target[0] = 0x44
        let patch = try write(makeBPS(source: source, target: target), "Game.bps")
        let rom = try write(Data(repeating: 0x34, count: 512), "Game.sfc")
        let job = BatchPatchJob(
            patchURL: patch, romURL: rom, romTitle: "Game", confidence: .high,
            crcValidation: .mismatched(expected: patchCRC32(source), actual: patchCRC32(Data(repeating: 0x34, count: 512)))
        )
        let batcher = BatchPatchApplier(applier: applier)
        let out = dir.appendingPathComponent("out", isDirectory: true)

        let results = await batcher.apply(jobs: [job], outputDirectory: out, allowCRCMismatch: true)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].success, results[0].message)
        XCTAssertEqual(try results[0].outputURL.map { try Data(contentsOf: $0) }, target)
    }

    func testVerifiedApplyReportsCheckedAgainstSource() async throws {
        let source = Data(repeating: 0x11, count: 1024)
        var target = source
        target[3] = 0x22
        let rom = try write(source, "Game.sfc")
        let artifact = try await applier.apply(patchURL: try write(makeBPS(source: source, target: target), "Game.bps"), to: rom)
        XCTAssertEqual(artifact.checkedAgainstSource, true)

        let ips = Data(Array("PATCH".utf8) + [0, 0, 3, 0, 1, 0x22] + Array("EOF".utf8))
        let ipsArtifact = try await applier.apply(patchURL: try write(ips, "Other.ips"), to: rom)
        XCTAssertEqual(ipsArtifact.checkedAgainstSource, false)
        XCTAssertEqual(try Data(contentsOf: ipsArtifact.url), target)
    }

    // MARK: - Hostile patches

    func testIPS32RecordFarPastTheImageIsRefusedWithoutOutput() async throws {
        let rom = try write(Data(count: 16), "Game.bin")
        // One record at 0xF0000000: far beyond the 256 MiB an IPS patch may grow an image by.
        let patch = try write(Data(Array("PATCH".utf8) + [0xF0, 0, 0, 0, 0, 1, 0xAA] + Array("EEOF".utf8)), "Game.ips32")

        do {
            _ = try await applier.apply(patchURL: patch, to: rom)
            XCTFail("expected an absurd IPS32 offset to be refused")
        } catch PatchError.corruptPatchFile {
        }
        XCTAssertTrue(strayCacheFiles().isEmpty)
        XCTAssertTrue(cacheEntries().isEmpty)
    }

    func testBPSDeclaringAHugeTargetIsRefused() async throws {
        let rom = try write(Data(count: 16), "Game.bin")
        var body = Array("BPS1".utf8) + encodeVLI(16) + encodeVLI(Int(1) << 40) + encodeVLI(0)
        body += le32(0) + le32(0)
        let patch = try write(Data(body + le32(patchCRC32(Data(body)))), "Game.bps")

        do {
            _ = try await applier.apply(patchURL: patch, to: rom)
            XCTFail("expected a 1 TiB target to be refused")
        } catch let error as PatchError {
            switch error {
            case .corruptPatchFile, .insufficientStorage: break
            default: XCTFail("unexpected \(error)")
            }
        }
        XCTAssertTrue(cacheEntries().isEmpty)
    }

    func testMagicWinsOverTheExtension() async throws {
        let source = Data(repeating: 0, count: 64)
        var target = source
        target[0] = 1
        let rom = try write(source, "Game.sfc")
        let misnamed = try write(makeBPS(source: source, target: target), "Game.ips")
        XCTAssertEqual(PatchFormat.detect(fileAt: misnamed), .bps)
        let artifact = try await applier.apply(patchURL: misnamed, to: rom)
        XCTAssertEqual(artifact.format, .bps)
        XCTAssertEqual(try Data(contentsOf: artifact.url), target)
    }

    // MARK: - Cache and concurrency

    func testStreamedCacheKeyEqualsTheWholeFileKey() throws {
        let rom = Data((0..<(5 * 1024 * 1024 + 17)).map { UInt8(truncatingIfNeeded: $0 &* 31) })
        let patch = Data("PATCH-ish bytes".utf8)
        let romURL = try write(rom, "Game.bin")
        let patchURL = try write(patch, "Game.ips")

        let romDigest = try FileDigest.compute(romURL, kinds: .all)
        let patchDigest = try FileDigest.compute(patchURL, kinds: .sha256)
        XCTAssertEqual(romDigest.sha256, PatchHashing.sha256Hex(rom))
        XCTAssertEqual(romDigest.md5, PatchHashing.md5Hex(rom))
        XCTAssertEqual(romDigest.crc32, patchCRC32(rom))
        XCTAssertEqual(
            PatchHashing.cacheKey(romSHA256: romDigest.sha256!, patchSHA256: patchDigest.sha256!),
            PatchHashing.cacheKey(romData: rom, patchData: patch)
        )
    }

    func testConcurrentAppliesOfOneVariantShareTheRun() async throws {
        let source = Data((0..<(3 * 1024 * 1024)).map { UInt8(truncatingIfNeeded: $0) })
        var target = source
        target[1_000_000] ^= 0xFF
        let rom = try write(source, "Game.bin")
        let patch = try write(makeBPS(source: source, target: target), "Game.bps")
        let applier = self.applier!

        async let first = applier.apply(patchURL: patch, to: rom, outputStem: "Same")
        async let second = applier.apply(patchURL: patch, to: rom, outputStem: "Same")
        let (a, b) = try await (first, second)

        XCTAssertEqual(a.url, b.url)
        XCTAssertEqual(a.patchedMD5, b.patchedMD5)
        XCTAssertEqual(try Data(contentsOf: a.url), target)
        XCTAssertTrue(strayCacheFiles().isEmpty)
    }

    func testCancellingLeavesNoOutput() async throws {
        let rom = dir.appendingPathComponent("Big.iso")
        XCTAssertTrue(FileManager.default.createFile(atPath: rom.path, contents: nil))
        let handle = try FileHandle(forWritingTo: rom)
        try handle.truncate(atOffset: 512 * 1024 * 1024)
        try handle.close()
        let patch = try write(Data(Array("PATCH".utf8) + [0, 0, 0, 0, 1, 0x01] + Array("EOF".utf8)), "Big.ips")
        let applier = self.applier!

        let task = Task { try await applier.apply(patchURL: patch, to: rom) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("expected cancellation")
        } catch PatchError.cancelled {
        }
        XCTAssertTrue(strayCacheFiles().isEmpty)
        XCTAssertTrue(cacheEntries().isEmpty)
    }

    // MARK: - Large image

    /// A sparse 4.5 GB source patched by BPS with a TargetRead past 4 GiB: hashing, patching and
    /// re-hashing all stream, so resident memory barely moves.
    func testFourAndAHalfGigabyteImagePatchesInBoundedMemory() async throws {
        let sourceSize = 4_500_000_000
        let free = PatchApplier.availableCapacity(at: dir) ?? 0
        try XCTSkipIf(free < 20_000_000_000, "needs 20 GB free, have \(free / 1_000_000_000) GB")

        let rom = dir.appendingPathComponent("Disc.iso")
        XCTAssertTrue(FileManager.default.createFile(atPath: rom.path, contents: nil))
        let handle = try FileHandle(forWritingTo: rom)
        try handle.truncate(atOffset: UInt64(sourceSize))
        try handle.close()

        // Target = the source with its last 8 bytes replaced.
        let tail = Data("PVPATCH!".utf8)
        let keep = sourceSize - tail.count
        var sourceCRC = CRC32Accumulator()
        var targetCRC = CRC32Accumulator()
        let zeros = Data(count: 8 * 1024 * 1024)
        var remaining = sourceSize
        while remaining > 0 {
            let step = min(remaining, zeros.count)
            let chunk = zeros.prefix(step)
            sourceCRC.update(chunk)
            let keepPart = max(0, min(step, keep - (sourceSize - remaining)))
            if keepPart > 0 { targetCRC.update(zeros.prefix(keepPart)) }
            remaining -= step
        }
        targetCRC.update(tail)

        var body = Array("BPS1".utf8) + encodeVLI(sourceSize) + encodeVLI(sourceSize) + encodeVLI(0)
        body += encodeVLI(((keep - 1) << 2) | 0)
        body += encodeVLI(((tail.count - 1) << 2) | 1) + Array(tail)
        body += le32(sourceCRC.value) + le32(targetCRC.value)
        let patch = try write(Data(body + le32(patchCRC32(Data(body)))), "Disc.bps")

        let sampler = ResidentSampler()
        let before = ResidentSampler.current()
        sampler.start()
        let artifact = try await applier.apply(patchURL: patch, to: rom)
        let peak = sampler.stop()
        print("PVPatching 4.5 GB BPS: resident \(before >> 20) MiB before, peak \(peak >> 20) MiB")

        XCTAssertLessThan(peak.subtractingReportingOverflow(before).partialValue, 64 << 20)
        XCTAssertEqual(artifact.patchedCRC32, targetCRC.value)
        XCTAssertEqual(artifact.checkedAgainstSource, true)
        let output = try FileHandle(forReadingFrom: artifact.url)
        defer { try? output.close() }
        XCTAssertEqual(try output.seekToEnd(), UInt64(sourceSize))
        try output.seek(toOffset: UInt64(keep))
        XCTAssertEqual(try output.read(upToCount: tail.count), tail)

        // Unchanged inputs: the fingerprint sidecar answers without hashing 9 GB again.
        let started = Date()
        let again = try await applier.apply(patchURL: patch, to: rom)
        XCTAssertTrue(again.wasCached)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
        try FileManager.default.removeItem(at: artifact.url)
    }
}
