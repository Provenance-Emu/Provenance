//
//  TVBezelCatalogTests.swift
//  PVUI
//
//  The TVs that ship with the app: the catalogue file and each TV's artwork.
//

#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import PVSettings
import PVShaders
import PVSystems
@testable import PVUIBase

@Suite("TVBezelCatalog")
struct TVBezelCatalogTests {

    private let bezels = TVBezelCatalog.bundled

    @Test("The bundled catalogue has TVs with distinct ids, none of them the 'no TV' value")
    func catalogueDecodes() {
        #expect(!bezels.isEmpty)
        #expect(Set(bezels.map(\.id)).count == bezels.count)
        #expect(!bezels.contains { $0.id == ExternalDisplayBezelRules.noBezelID })
        #expect(!bezels.contains { $0.name.isEmpty })
    }

    @Test("Preferred systems are real, and no two TVs claim the same one")
    func preferredSystems() {
        var claimed: Set<String> = []
        for bezel in bezels {
            for system in bezel.preferredSystems {
                #expect(SystemIdentifier(rawValue: system) != nil, "\(bezel.id) lists unknown system \(system)")
                #expect(claimed.insert(system).inserted, "\(system) is claimed by two TVs")
            }
        }
    }

    @Test("Every TV's own look names a filter by a well-formed id")
    func looks() {
        for bezel in bezels {
            guard let look = bezel.look else { continue }
            #expect(look.shaderID.kind != nil, "\(bezel.id): '\(look.shader)' is not a shader id")
            #expect(!look.shaderID.path.isEmpty)
            // A TV cannot suggest a filter that brings a frame of its own.
            #expect(!look.shaderID.path.hasPrefix("bezel/") && !look.shaderID.path.hasPrefix("border/"))
        }
    }

    @Test("A TV cannot place or shape its tube through the frame's values")
    func frameValuesLeaveGeometryAlone() {
        let geometry = Set(TVBezelShader.geometryValues(tubeAspect: 1, tubeHeightFraction: 1).keys)
        for bezel in bezels {
            #expect(geometry.isDisjoint(with: bezel.frame.keys), "\(bezel.id) sets tube geometry in its frame values")
        }
    }

    @Test("Every TV's artwork loads, with one centred 4:3 tube that leaves room for a cabinet")
    func artwork() throws {
        for bezel in bezels {
            let artwork = try TVBezelArtwork(bezel: bezel)
            let tube = artwork.tubeRect
            let canvas = TVBezelArtwork.canvas
            #expect(abs(tube.midX - canvas.width / 2) < 0.5, "\(bezel.id): tube is not centred across")
            #expect(abs(tube.midY - canvas.height / 2) < 0.5, "\(bezel.id): tube is not centred down")
            #expect(abs(artwork.tubeAspect - 4.0 / 3.0) < 0.001, "\(bezel.id): tube is not 4:3")
            #expect(artwork.tubeHeightFraction > 0.4 && artwork.tubeHeightFraction < 0.9)
        }
    }

    @Test("Artwork renders at the size asked for")
    func artworkRenders() throws {
        let bezel = try #require(bezels.first)
        let artwork = try TVBezelArtwork(bezel: bezel)
        let image = try #require(artwork.image(pixelWidth: 480))
        #expect(image.width == 480 && image.height == 270)
        #expect(artwork.image(pixelWidth: 0) == nil)
        let png = try #require(artwork.pngData(pixelWidth: 480))
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test("A document needs exactly one screen to be a TV")
    func artworkScreenCount() {
        func document(screens: Int) -> Data {
            let nodes = (0 ..< screens).map { #"{"type":"screen","id":"s\#($0)","layout":{"frame":[\#($0 * 10),0,8,6]}}"# }
            let json = #"{"formatVersion":"2.0","requires":[],"identifier":"t","name":"t","gameTypes":["t"],"#
                + #""reference":{"shortSide":1080,"minScale":1,"maxScale":1},"#
                + #""root":{"type":"group","id":"root","children":[\#(nodes.joined(separator: ","))]}}"#
            return Data(json.utf8)
        }
        #expect(throws: TVBezelArtwork.ArtworkError.screenCount(0)) { try TVBezelArtwork(data: document(screens: 0)) }
        #expect(throws: TVBezelArtwork.ArtworkError.screenCount(2)) { try TVBezelArtwork(data: document(screens: 2)) }
        #expect(throws: Never.self) { try TVBezelArtwork(data: document(screens: 1)) }
    }

    @Test("The catalogue resolves the stored choice through the selection rules")
    func resolvesChoice() throws {
        let first = try #require(bezels.first)
        #expect(TVBezelCatalog.bezel(chosen: first.id, matchesSystem: false, systemID: nil) == first)
        #expect(TVBezelCatalog.bezel(chosen: ExternalDisplayBezelRules.noBezelID, matchesSystem: true, systemID: nil) == nil)
        #expect(TVBezelCatalog.bezel(chosen: "not-a-tv", matchesSystem: true, systemID: nil) == nil)
    }

    @Test("A catalogue entry needs only an id, a name and artwork")
    func decodesMinimalEntry() throws {
        let data = Data(#"{"bezels":[{"id":"a","name":"A","artwork":"a.skin.json"}]}"#.utf8)
        let bezel = try #require(try TVBezelCatalog.decode(data).first)
        #expect(bezel.lightsRoom)
        #expect(bezel.look == nil)
        #expect(bezel.frame.isEmpty && bezel.preferredSystems.isEmpty)
    }
}
#endif
