import XCTest
@testable import CoreManager

final class CoreManifestTests: XCTestCase {

    // MARK: - Test fixtures

    static let sampleYAML = """
    buildbot:
      base_url: "https://buildbot.libretro.com/nightly/apple"
      ios_path: "ios-arm64/latest"
      tvos_path: "tvos-arm64/latest"

    cores:
      - name: fceumm
        ios: true
        tvos: true
        appstore: true
        enabled: true

      - name: snes9x
        ios: true
        tvos: true
        appstore: true
        enabled: false

      - name: dolphin
        ios: true
        tvos: true
        appstore: false
        enabled: true
        filename: "dolphin_libretro.dylib"
        appstore_excluded_reason: "Contains JIT"

      - name: flycast
        ios: true
        tvos: true
        appstore: true
        enabled: true
        filename: "flycast_libretro.dylib"

      - name: vitaquake2
        ios: false
        tvos: true
        appstore: true
        enabled: false

      - name: puau
        ios: false
        tvos: true
        appstore: true
        enabled: true
    """

    // MARK: - BuildbotConfig tests

    func testBuildbotConfig() throws {
        let manifest = try loadFixture()
        XCTAssertEqual(manifest.buildbot.baseURL, "https://buildbot.libretro.com/nightly/apple")
        XCTAssertEqual(manifest.buildbot.iosPath, "ios-arm64/latest")
        XCTAssertEqual(manifest.buildbot.tvosPath, "tvos-arm64/latest")
    }

    func testBuildbotBaseURLs() throws {
        let manifest = try loadFixture()
        XCTAssertEqual(
            manifest.buildbot.iosBase,
            "https://buildbot.libretro.com/nightly/apple/ios-arm64/latest"
        )
        XCTAssertEqual(
            manifest.buildbot.tvosBase,
            "https://buildbot.libretro.com/nightly/apple/tvos-arm64/latest"
        )
    }

    // MARK: - CoreEntry filename tests

    func testStandardCoreFilenames() throws {
        let manifest = try loadFixture()
        let fceumm = try XCTUnwrap(manifest.cores.first { $0.name == "fceumm" })
        XCTAssertEqual(fceumm.iosFilename, "fceumm_libretro_ios.dylib")
        XCTAssertEqual(fceumm.tvosFilename, "fceumm_libretro_tvos.dylib")
        XCTAssertFalse(fceumm.isPlatformNeutral)
    }

    func testPlatformNeutralCoreFilenames() throws {
        let manifest = try loadFixture()
        let flycast = try XCTUnwrap(manifest.cores.first { $0.name == "flycast" })
        XCTAssertEqual(flycast.iosFilename, "flycast_libretro.dylib")
        XCTAssertEqual(flycast.tvosFilename, "flycast_libretro.dylib")
        XCTAssertTrue(flycast.isPlatformNeutral)
    }

    func testDolphinFilename() throws {
        let manifest = try loadFixture()
        let dolphin = try XCTUnwrap(manifest.cores.first { $0.name == "dolphin" })
        XCTAssertEqual(dolphin.filename, "dolphin_libretro.dylib")
        XCTAssertEqual(dolphin.iosFilename, "dolphin_libretro.dylib")
        XCTAssertEqual(dolphin.tvosFilename, "dolphin_libretro.dylib")
    }

    // MARK: - URL generation tests

    func testStandardCoreURL() throws {
        let manifest = try loadFixture()
        let fceumm = try XCTUnwrap(manifest.cores.first { $0.name == "fceumm" })
        XCTAssertEqual(
            fceumm.iosURL(buildbot: manifest.buildbot),
            "https://buildbot.libretro.com/nightly/apple/ios-arm64/latest/fceumm_libretro_ios.dylib.zip"
        )
        XCTAssertEqual(
            fceumm.tvosURL(buildbot: manifest.buildbot),
            "https://buildbot.libretro.com/nightly/apple/tvos-arm64/latest/fceumm_libretro_tvos.dylib.zip"
        )
    }

    func testPlatformNeutralURL() throws {
        let manifest = try loadFixture()
        let flycast = try XCTUnwrap(manifest.cores.first { $0.name == "flycast" })
        XCTAssertEqual(
            flycast.iosURL(buildbot: manifest.buildbot),
            "https://buildbot.libretro.com/nightly/apple/ios-arm64/latest/flycast_libretro.dylib.zip"
        )
        XCTAssertEqual(
            flycast.tvosURL(buildbot: manifest.buildbot),
            "https://buildbot.libretro.com/nightly/apple/tvos-arm64/latest/flycast_libretro.dylib.zip"
        )
    }

    // MARK: - Filtering tests

    func testIosCoresFilter() throws {
        let manifest = try loadFixture()
        let ios = manifest.iosCores()
        let names = ios.map { $0.name }
        XCTAssertTrue(names.contains("fceumm"))
        XCTAssertTrue(names.contains("dolphin"))   // ios: true
        XCTAssertTrue(names.contains("snes9x"))    // ios: true, even though disabled
        XCTAssertFalse(names.contains("puau"))     // ios: false
        XCTAssertFalse(names.contains("vitaquake2")) // ios: false
    }

    func testTvosCoresFilter() throws {
        let manifest = try loadFixture()
        let tvos = manifest.tvosCores()
        let names = tvos.map { $0.name }
        XCTAssertTrue(names.contains("fceumm"))
        XCTAssertTrue(names.contains("puau"))
        XCTAssertTrue(names.contains("vitaquake2")) // tvos: true
    }

    func testAppstoreFilterExcludesDolphin() throws {
        let manifest = try loadFixture()
        let appstoreIOS = manifest.iosCores(appstore: true)
        let names = appstoreIOS.map { $0.name }
        XCTAssertFalse(names.contains("dolphin"))  // appstore: false
        XCTAssertTrue(names.contains("fceumm"))
    }

    func testDisabledCoreIsPresent() throws {
        // Disabled cores are still returned in the list — they are just flagged
        let manifest = try loadFixture()
        let ios = manifest.iosCores()
        let snes9x = ios.first { $0.name == "snes9x" }
        XCTAssertNotNil(snes9x)
        XCTAssertFalse(snes9x!.enabled)
    }

    // MARK: - CoreEntry properties

    func testCoreEntryFlags() throws {
        let manifest = try loadFixture()

        let fceumm = try XCTUnwrap(manifest.cores.first { $0.name == "fceumm" })
        XCTAssertTrue(fceumm.ios)
        XCTAssertTrue(fceumm.tvos)
        XCTAssertTrue(fceumm.appstore)
        XCTAssertTrue(fceumm.enabled)

        let snes9x = try XCTUnwrap(manifest.cores.first { $0.name == "snes9x" })
        XCTAssertFalse(snes9x.enabled)

        let dolphin = try XCTUnwrap(manifest.cores.first { $0.name == "dolphin" })
        XCTAssertFalse(dolphin.appstore)
        XCTAssertTrue(dolphin.enabled)
        XCTAssertEqual(dolphin.appstoreExcludedReason, "Contains JIT")

        let puau = try XCTUnwrap(manifest.cores.first { $0.name == "puau" })
        XCTAssertFalse(puau.ios)
        XCTAssertTrue(puau.tvos)
    }

    // MARK: - Core count sanity

    func testCoreCount() throws {
        let manifest = try loadFixture()
        XCTAssertEqual(manifest.cores.count, 6)
    }

    // MARK: - Helpers

    private func loadFixture() throws -> CoreManifest {
        // Write YAML to a temp file and load it
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_cores_\(UUID().uuidString).yml")
        try Self.sampleYAML.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try CoreManifest.load(from: tmp)
    }
}
