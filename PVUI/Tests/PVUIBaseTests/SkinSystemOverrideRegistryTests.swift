//
//  SkinSystemOverrideRegistryTests.swift
//  PVUIBaseTests
//
//  Validates the catalog-override registry that backs the SG-1000 catalog
//  install fix.  Focuses on sidecar IO, normalization, batch lookups, and
//  removal hygiene; the catalog-cache fallback path is exercised indirectly
//  via the `availableSkins(for:)` integration covered elsewhere.
//

import Foundation
import Testing
import UIKit
@testable import PVUIBase

@Suite("SkinSystemOverrideRegistry")
struct SkinSystemOverrideRegistryTests {

    // MARK: - Test Helpers

    /// Lightweight stand-in for ``DeltaSkinProtocol`` so we can probe the registry
    /// without instantiating a full `.deltaskin` package on disk.
    private struct StubSkin: DeltaSkinProtocol {
        let identifier: String
        let name: String
        let gameType: DeltaSkinGameType
        let fileURL: URL
        var isDebugEnabled: Bool { false }
        var jsonRepresentation: [String: Any] { [:] }
        func supports(_ traits: DeltaSkinTraits) -> Bool { false }
        func image(for traits: DeltaSkinTraits) async throws -> UIImage { throw CocoaError(.fileReadUnknown) }
        func mappingSize(for traits: DeltaSkinTraits) -> CGSize? { nil }
        func screenGroups(for traits: DeltaSkinTraits) -> [DeltaSkinScreenGroup]? { nil }
        func buttons(for traits: DeltaSkinTraits) -> [DeltaSkinButton]? { nil }
        func screens(for traits: DeltaSkinTraits) -> [DeltaSkinScreen]? { nil }
        func representation(for traits: DeltaSkinTraits) -> DeltaSkin.RepresentationInfo? { nil }
    }

    /// Creates a fresh temporary directory we can drop sidecars and fake skins into.
    private func makeTempDirectory(_ name: String = #function) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkinSystemOverrideRegistryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeRawSidecar(_ json: String, next to skinURL: URL) throws {
        let sidecarURL = SkinSystemOverrideRegistry.sidecarURL(for: skinURL)
        try json.data(using: .utf8)!.write(to: sidecarURL, options: .atomic)
    }

    // MARK: - Sidecar URL Naming

    @Test("Sidecar URL replaces .deltaskin with .skinmeta")
    func sidecarURLDerivation() {
        let skin = URL(fileURLWithPath: "/tmp/cool-skin.deltaskin")
        let sidecar = SkinSystemOverrideRegistry.sidecarURL(for: skin)
        #expect(sidecar.lastPathComponent == "cool-skin.skinmeta")
        #expect(sidecar.pathExtension == SkinSystemOverrideRegistry.sidecarPathExtension)
    }

    @Test("Sidecar URL is computed for .manicskin too")
    func sidecarURLManicSkin() {
        let skin = URL(fileURLWithPath: "/tmp/funky.manicskin")
        let sidecar = SkinSystemOverrideRegistry.sidecarURL(for: skin)
        #expect(sidecar.lastPathComponent == "funky.skinmeta")
    }

    // MARK: - Sidecar Parsing

    @Test("Reads a well-formed sidecar from disk")
    func reads_validSidecar() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let skinURL = dir.appendingPathComponent("sega.deltaskin")
        let json = """
        {
          "version": 1,
          "catalogEntryId": "27142316e1ac9953",
          "skinIdentifier": "com.failyx.sega.sg1000",
          "name": "SEGA SG-1000 Thumbstick",
          "systems": ["sg1000"],
          "gameTypeIdentifier": "com.rileytestut.delta.game.gba"
        }
        """
        try writeRawSidecar(json, next: skinURL)

        let sidecar = SkinSystemOverrideRegistry.shared.readSidecar(for: skinURL)
        #expect(sidecar?.catalogEntryId == "27142316e1ac9953")
        #expect(sidecar?.systems == ["sg1000"])
        #expect(sidecar?.gameTypeIdentifier == "com.rileytestut.delta.game.gba")
    }

    @Test("Returns nil when sidecar is missing")
    func reads_missingSidecar() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let skinURL = dir.appendingPathComponent("nope.deltaskin")
        #expect(SkinSystemOverrideRegistry.shared.readSidecar(for: skinURL) == nil)
    }

    @Test("Returns nil for malformed sidecar JSON")
    func reads_malformedSidecar() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let skinURL = dir.appendingPathComponent("bad.deltaskin")
        try writeRawSidecar("{ this is not json", next: skinURL)
        #expect(SkinSystemOverrideRegistry.shared.readSidecar(for: skinURL) == nil)
    }

    // MARK: - Write / Remove Lifecycle

    @Test("writeSidecar persists json and warms in-memory cache")
    func write_thenLookup() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let registry = SkinSystemOverrideRegistry()
        let skinURL = dir.appendingPathComponent("install-me.deltaskin")
        FileManager.default.createFile(atPath: skinURL.path, contents: nil)

        let entry = SkinCatalogEntry(
            id: "27142316e1ac9953",
            name: "SEGA SG-1000 Thumbstick",
            systems: ["SG1000"],
            downloadURL: URL(string: "https://example.com/x.deltaskin")!
        )
        try await registry.writeSidecar(for: skinURL, entry: entry, skinIdentifier: "com.failyx.sega.sg1000")

        /// Sidecar exists on disk with the .skinmeta extension.
        let sidecarURL = SkinSystemOverrideRegistry.sidecarURL(for: skinURL)
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))

        let stub = StubSkin(
            identifier: "com.failyx.sega.sg1000",
            name: "SEGA SG-1000 Thumbstick",
            gameType: .gba,
            fileURL: skinURL
        )
        let codes = await registry.systemCodes(for: stub)
        #expect(codes == ["sg1000"])
    }

    @Test("removeSidecar deletes the file and forgets cached overrides")
    func remove_clearsEverything() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let registry = SkinSystemOverrideRegistry()
        let skinURL = dir.appendingPathComponent("remove-me.deltaskin")
        FileManager.default.createFile(atPath: skinURL.path, contents: nil)

        let entry = SkinCatalogEntry(
            id: "abc",
            name: "Tester",
            systems: ["nes"],
            downloadURL: URL(string: "https://example.com/x.deltaskin")!
        )
        try await registry.writeSidecar(for: skinURL, entry: entry, skinIdentifier: "tester.id")

        let sidecarURL = SkinSystemOverrideRegistry.sidecarURL(for: skinURL)
        #expect(FileManager.default.fileExists(atPath: sidecarURL.path))

        await registry.removeSidecar(for: skinURL, skinIdentifier: "tester.id")
        #expect(!FileManager.default.fileExists(atPath: sidecarURL.path))

        let stub = StubSkin(identifier: "tester.id", name: "Tester", gameType: .nes, fileURL: skinURL)
        let codes = await registry.systemCodes(for: stub)
        /// No sidecar, no catalog entry that matches a temp-only file, so empty set.
        #expect(codes.isEmpty)
    }

    // MARK: - Normalization & Batch Lookup

    @Test("System codes are lowercased and legacy codes are dropped")
    func normalization_dropsLegacyAndCases() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let registry = SkinSystemOverrideRegistry()
        let skinURL = dir.appendingPathComponent("mixed.deltaskin")
        FileManager.default.createFile(atPath: skinURL.path, contents: nil)

        /// Hand-craft a sidecar with mixed-case + legacy codes to confirm the
        /// reader path normalizes consistently with the writer path.
        let raw = """
        {
          "version": 1,
          "catalogEntryId": "x",
          "skinIdentifier": "x",
          "name": "X",
          "systems": ["SG1000", "Unofficial", "  ", "MasterSystem"],
          "gameTypeIdentifier": null
        }
        """
        try writeRawSidecar(raw, next: skinURL)

        let stub = StubSkin(identifier: "x", name: "X", gameType: .sg1000, fileURL: skinURL)
        let codes = await registry.systemCodes(for: stub)
        #expect(codes == ["sg1000", "mastersystem"])
    }

    @Test("Batch lookup omits skins with no override")
    func batch_omitsEmpty() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let registry = SkinSystemOverrideRegistry()
        let withSidecarURL = dir.appendingPathComponent("with.deltaskin")
        let bareURL = dir.appendingPathComponent("bare.deltaskin")
        FileManager.default.createFile(atPath: withSidecarURL.path, contents: nil)
        FileManager.default.createFile(atPath: bareURL.path, contents: nil)

        let entry = SkinCatalogEntry(
            id: "id1",
            name: "Has Sidecar",
            systems: ["sg1000"],
            downloadURL: URL(string: "https://example.com/x.deltaskin")!
        )
        try await registry.writeSidecar(for: withSidecarURL, entry: entry, skinIdentifier: "skin.with")

        let withSkin = StubSkin(identifier: "skin.with", name: "Has Sidecar", gameType: .gba, fileURL: withSidecarURL)
        let bareSkin = StubSkin(identifier: "skin.bare", name: "Bare", gameType: .nes, fileURL: bareURL)

        let map = await registry.overrideCodesByIdentifier(for: [withSkin, bareSkin])
        #expect(map.keys.contains("skin.with"))
        #expect(!map.keys.contains("skin.bare"))
        #expect(map["skin.with"] == ["sg1000"])
    }

    // MARK: - Codable Round-trip

    @Test("SkinCatalogSidecar round-trips through JSON")
    func sidecarRoundTrip() throws {
        let original = SkinCatalogSidecar(
            catalogEntryId: "27142316e1ac9953",
            skinIdentifier: "com.failyx.sega.sg1000",
            name: "SEGA SG-1000 Thumbstick",
            systems: ["sg1000"],
            gameTypeIdentifier: "com.rileytestut.delta.game.gba"
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SkinCatalogSidecar.self, from: encoded)
        #expect(decoded == original)
    }
}
