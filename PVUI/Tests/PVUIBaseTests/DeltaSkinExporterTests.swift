//
//  DeltaSkinExporterTests.swift
//  PVUIBaseTests
//
//  Unit tests for DeltaSkinExporter:
//  - Patched frames are written to the exported archive.
//  - info.json is placed at the archive root (shouldKeepParent: false).
//  - edgeToEdge ↔ standard fallback logic.
//  - noItemsFound thrown for unmatched traits.
//  - The exported archive can be round-tripped through DeltaSkin(fileURL:).
//

#if canImport(UIKit)
import Foundation
import Testing
import UIKit
@testable import PVUIBase

// MARK: - Test fixture helpers

/// Minimal `DeltaSkinProtocol` conformer used by exporter tests.
private struct ExporterTestSkin: DeltaSkinProtocol {
    let identifier: String
    let name: String
    let gameType: DeltaSkinGameType
    let fileURL: URL
    let isDebugEnabled: Bool = false
    let keyboardOverlay: KeyboardOverlayConfig? = nil
    let jsonRepresentation: [String: Any]

    func supports(_ traits: DeltaSkinTraits) -> Bool { true }
    func image(for traits: DeltaSkinTraits) async throws -> UIImage { UIImage() }
    func screens(for traits: DeltaSkinTraits) -> [DeltaSkinScreen]? { nil }
    func screenGroups(for traits: DeltaSkinTraits) -> [DeltaSkinScreenGroup]? { nil }
    func buttons(for traits: DeltaSkinTraits) -> [DeltaSkinButton]? { nil }
    func mappingSize(for traits: DeltaSkinTraits) -> CGSize? { nil }
    func representation(for traits: DeltaSkinTraits) -> DeltaSkin.RepresentationInfo? { nil }
}

/// Builds a minimal info.json dictionary with one button item at the specified frame.
private func makeInfoJSON(
    device: String = "iphone",
    displayType: String = "standard",
    orientation: String = "portrait",
    itemX: Double = 10, itemY: Double = 20,
    itemW: Double = 50, itemH: Double = 30
) -> [String: Any] {
    [
        "name": "ExporterTest",
        "identifier": "com.test.exporter",
        "gameTypeIdentifier": "com.rileytestut.delta.game.gba",
        "debug": false,
        "representations": [
            device: [
                displayType: [
                    orientation: [
                        "assets": ["resizable": "test.pdf"],
                        "mappingSize": ["width": 414, "height": 896],
                        "translucent": false,
                        "screens": [],
                        "items": [
                            [
                                "inputs": ["a"],
                                "frame": [
                                    "x": itemX, "y": itemY,
                                    "width": itemW, "height": itemH
                                ],
                                "extendedEdges": ["top": 0, "bottom": 0, "left": 0, "right": 0]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    ]
}

/// Creates a temporary directory containing a minimal info.json, returns a skin
/// pointing to it and a cleanup closure.
private func makeDirectorySkin(
    json: [String: Any],
    identifier: String = "com.test.dir"
) throws -> (skin: ExporterTestSkin, cleanup: () -> Void) {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory
        .appendingPathComponent("SkinExTest-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let infoData = try JSONSerialization.data(withJSONObject: json)
    try infoData.write(to: dir.appendingPathComponent("info.json"))
    // Placeholder asset file so the directory isn't empty
    try Data().write(to: dir.appendingPathComponent("test.pdf"))

    let skin = ExporterTestSkin(
        identifier: identifier,
        name: "Test",
        gameType: .gba,
        fileURL: dir,
        jsonRepresentation: json
    )
    return (skin, { try? fm.removeItem(at: dir) })
}

/// Returns the `items` array for the given representation path from a loaded `DeltaSkin`'s
/// raw JSON representation.
private func itemsFromJSON(
    _ json: [String: Any],
    device: String = "iphone",
    displayType: String = "standard",
    orientation: String = "portrait"
) -> [[String: Any]]? {
    guard let reps = json["representations"] as? [String: Any],
          let dev = reps[device] as? [String: Any],
          let disp = dev[displayType] as? [String: Any],
          let orient = disp[orientation] as? [String: Any],
          let items = orient["items"] as? [[String: Any]] else { return nil }
    return items
}

// MARK: - Tests

@Suite("DeltaSkinExporter")
struct DeltaSkinExporterTests {

    private let defaultTraits = DeltaSkinTraits(
        device: .iphone,
        displayType: .standard,
        orientation: .portrait
    )

    // MARK: Frame patching

    @Test("Patched frame is present in the exported archive")
    func exportedFrameMatchesPatch() async throws {
        let json = makeInfoJSON()
        let (skin, cleanup) = try makeDirectorySkin(json: json, identifier: "com.test.patch")
        defer { cleanup() }

        let newFrame = CGRect(x: 99, y: 88, width: 77, height: 66)
        let outputURL = try await DeltaSkinExporter.export(
            skin: skin,
            traits: defaultTraits,
            modifiedFrames: [0: newFrame]
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        // Round-trip through DeltaSkin to confirm the archive is valid and readable
        let loaded = try DeltaSkin(fileURL: outputURL)
        let items = try #require(itemsFromJSON(loaded.jsonRepresentation))
        #expect(items.count == 1)
        let frame = try #require(items[0]["frame"] as? [String: Any])
        #expect((frame["x"] as? Double) == 99)
        #expect((frame["y"] as? Double) == 88)
        #expect((frame["width"] as? Double) == 77)
        #expect((frame["height"] as? Double) == 66)
    }

    @Test("Unmodified items retain their original frame after export")
    func unmodifiedFrameIsPreserved() async throws {
        let json = makeInfoJSON(itemX: 5, itemY: 10, itemW: 40, itemH: 25)
        let (skin, cleanup) = try makeDirectorySkin(json: json, identifier: "com.test.preserve")
        defer { cleanup() }

        let outputURL = try await DeltaSkinExporter.export(
            skin: skin,
            traits: defaultTraits,
            modifiedFrames: [:]
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let loaded = try DeltaSkin(fileURL: outputURL)
        let items = try #require(itemsFromJSON(loaded.jsonRepresentation))
        let frame = try #require(items[0]["frame"] as? [String: Any])
        #expect((frame["x"] as? Double) == 5)
        #expect((frame["y"] as? Double) == 10)
        #expect((frame["width"] as? Double) == 40)
        #expect((frame["height"] as? Double) == 25)
    }

    // MARK: Archive structure

    @Test("Exported archive is loadable by DeltaSkin(fileURL:)")
    func exportedArchiveIsLoadable() async throws {
        let json = makeInfoJSON()
        let (skin, cleanup) = try makeDirectorySkin(json: json, identifier: "com.test.loadable")
        defer { cleanup() }

        let outputURL = try await DeltaSkinExporter.export(
            skin: skin,
            traits: defaultTraits,
            modifiedFrames: [:]
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        // DeltaSkin(fileURL:) reads info.json from archive["info.json"] —
        // this succeeds only if info.json is at the zip root (shouldKeepParent: false).
        #expect(throws: Never.self) {
            _ = try DeltaSkin(fileURL: outputURL)
        }
    }

    // MARK: edgeToEdge ↔ standard fallback

    @Test("edgeToEdge traits fall back to standard representation when edgeToEdge is absent")
    func edgeToEdgeFallsBackToStandard() async throws {
        // JSON only has "standard" — requesting edgeToEdge should fall back
        let json = makeInfoJSON(displayType: "standard")
        let (skin, cleanup) = try makeDirectorySkin(json: json, identifier: "com.test.e2e")
        defer { cleanup() }

        let e2eTraits = DeltaSkinTraits(device: .iphone, displayType: .edgeToEdge, orientation: .portrait)
        let newFrame = CGRect(x: 55, y: 44, width: 33, height: 22)
        let outputURL = try await DeltaSkinExporter.export(
            skin: skin,
            traits: e2eTraits,
            modifiedFrames: [0: newFrame]
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let loaded = try DeltaSkin(fileURL: outputURL)
        // The fallback patches the "standard" slot
        let items = try #require(itemsFromJSON(loaded.jsonRepresentation, displayType: "standard"))
        let frame = try #require(items[0]["frame"] as? [String: Any])
        #expect((frame["x"] as? Double) == 55)
    }

    @Test("standard traits fall back to edgeToEdge representation when standard is absent")
    func standardFallsBackToEdgeToEdge() async throws {
        let json = makeInfoJSON(displayType: "edgeToEdge")
        let (skin, cleanup) = try makeDirectorySkin(json: json, identifier: "com.test.std-fallback")
        defer { cleanup() }

        let newFrame = CGRect(x: 1, y: 2, width: 3, height: 4)
        let outputURL = try await DeltaSkinExporter.export(
            skin: skin,
            traits: defaultTraits, // standard
            modifiedFrames: [0: newFrame]
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let loaded = try DeltaSkin(fileURL: outputURL)
        let items = try #require(itemsFromJSON(loaded.jsonRepresentation, displayType: "edgeToEdge"))
        let frame = try #require(items[0]["frame"] as? [String: Any])
        #expect((frame["x"] as? Double) == 1)
    }

    // MARK: Error cases

    @Test("noItemsFound thrown when no representation matches the requested traits")
    func errorThrownForUnmatchedTraits() async throws {
        // JSON only has iphone/standard/portrait; requesting ipad should throw
        let json = makeInfoJSON(device: "iphone")
        let (skin, cleanup) = try makeDirectorySkin(json: json, identifier: "com.test.err")
        defer { cleanup() }

        let ipadTraits = DeltaSkinTraits(device: .ipad, displayType: .standard, orientation: .portrait)

        var caught: Error?
        do {
            _ = try await DeltaSkinExporter.export(
                skin: skin,
                traits: ipadTraits,
                modifiedFrames: [0: CGRect(x: 0, y: 0, width: 10, height: 10)]
            )
        } catch {
            caught = error
        }
        #expect(caught is DeltaSkinExportError)
    }

    @Test("Error thrown when representations key is absent from JSON")
    func errorThrownForMissingRepresentations() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory
            .appendingPathComponent("SkinExTestNoRep-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: dir) }
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let badJSON: [String: Any] = ["name": "Bad", "identifier": "com.test.bad"]
        let infoData = try JSONSerialization.data(withJSONObject: badJSON)
        try infoData.write(to: dir.appendingPathComponent("info.json"))

        let skin = ExporterTestSkin(
            identifier: "com.test.bad",
            name: "Bad",
            gameType: .gba,
            fileURL: dir,
            jsonRepresentation: badJSON
        )

        var caught: Error?
        do {
            _ = try await DeltaSkinExporter.export(
                skin: skin,
                traits: defaultTraits,
                modifiedFrames: [:]
            )
        } catch {
            caught = error
        }
        #expect(caught is DeltaSkinExportError)
    }
}
#endif
