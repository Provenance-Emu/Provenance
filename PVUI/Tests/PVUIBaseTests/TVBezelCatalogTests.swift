//
//  TVBezelCatalogTests.swift
//  PVUI
//
//  The shared package's TVs as Provenance uses them: its systems, its shader library and its
//  stored choices. The catalogue file, the artwork and the selection rules are tested in SkinKit.
//

#if os(iOS)
import CoreGraphics
import Defaults
import Foundation
import Testing
import PVSettings
@testable import PVShaders
import PVSystems
import SkinKitBezels
@testable import PVUIBase

@Suite("TVBezelCatalog")
struct TVBezelCatalogTests {

    private let bezels: [TVBezel]

    init() {
        ProvenanceBezels.configure()
        bezels = TVBezelCatalog.bundled
    }

    @Test("The bundled catalogue reaches Provenance with its TVs")
    func catalogueDecodes() {
        #expect(!bezels.isEmpty)
        #expect(Set(bezels.map(\.id)).count == bezels.count)
        #expect(!bezels.contains { $0.id == ExternalDisplayBezelRules.noBezelID })
    }

    @Test("Preferred systems are systems Provenance has")
    func preferredSystems() {
        for bezel in bezels {
            for system in bezel.preferredSystems {
                #expect(SystemIdentifier(rawValue: system) != nil, "\(bezel.id) lists unknown system \(system)")
            }
        }
    }

    @Test("The Bezel Project's table names systems Provenance has, none of them with two screens")
    func bezelProjectSystems() {
        let systems = BezelProjectService.systems
        #expect(!systems.isEmpty)
        for systemID in systems.keys {
            #expect(SystemIdentifier(rawValue: systemID) != nil, "unknown system \(systemID)")
        }
        #expect(systems[SystemIdentifier.DS.rawValue] == nil)
        #expect(systems[SystemIdentifier._3DS.rawValue] == nil)
        #expect(BezelProjectService.repositories(systemID: SystemIdentifier.SNES.rawValue, style: .systemArt).first?.name == "bezelprojectSA-SNES")
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

    @Test("The package's preset ids are Provenance's shader ids")
    func presetIDs() {
        #expect(ShaderID(rawValue: TVBezelShader.bezelOnlyID) == .slang("bezel/uborder/preset_tools/append-uborder-bezel-reflections"))
        #expect(ShaderID(rawValue: TVBezelShader.ambientID) == .slang("bezel/uborder/uborder-koko-ambi"))
        for bezel in TVBezelCatalog.shaderPresets {
            #expect(bezel.presetShaderID?.kind == .slang)
            #expect(bezel.presetShaderID.flatMap { ShaderCatalog.shared.entry(for: $0) } != nil)
        }
    }

    @Test("Every TV's artwork loads from the package's bundle")
    func artwork() throws {
        for bezel in bezels {
            let artwork = try TVBezelArtwork(bezel: bezel)
            #expect(abs(artwork.tubeAspect - 4.0 / 3.0) < 0.001, "\(bezel.id): tube is not 4:3")
        }
        let first = try #require(bezels.first)
        let image = try #require(try TVBezelArtwork(bezel: first).image(pixelWidth: 480))
        #expect(image.width == 480 && image.height == 270)
    }

    @Test("The catalogue resolves the stored choice through the selection rules")
    func resolvesChoice() throws {
        let first = try #require(bezels.first)
        func tv(_ chosen: String, matches: Bool) -> TVBezel? {
            TVBezelCatalog.resolve(chosen: chosen, matchesSystem: matches, systemID: nil, systemSuitsTV: true).bezel
        }
        #expect(tv(first.id, matches: false) == first)
        #expect(tv(ExternalDisplayBezelRules.noBezelID, matches: true) == nil)
        #expect(tv("not-a-tv", matches: true) == nil)
    }

    @Test("Automatic gives a console the living room TV and a handheld none")
    func automaticDefaultExists() {
        #expect(TVBezelCatalog.bezel(id: ExternalDisplayBezelRules.automaticDefaultBezelID) != nil)
        let console = TVBezelCatalog.resolve(chosen: ExternalDisplayBezelRules.automaticBezelID, matchesSystem: true,
                                             systemID: SystemIdentifier.SNES.rawValue, systemSuitsTV: true)
        #expect(console.bezel?.id == "living-room-tv")
        #expect(console.resolution.isAutomatic)
        let handheld = TVBezelCatalog.resolve(chosen: ExternalDisplayBezelRules.automaticBezelID, matchesSystem: true,
                                              systemID: SystemIdentifier.GBA.rawValue, systemSuitsTV: false)
        #expect(handheld.bezel == nil)
        #expect(handheld.resolution.outcome == .noneForSystem)
    }

    @Test("The stored choices keep their keys and defaults")
    func storedChoices() {
        #expect(Defaults.Keys.externalDisplayBezel.name == "externalDisplayBezel")
        #expect(Defaults.Keys.externalDisplayBezel.defaultValue == ExternalDisplayBezelRules.automaticBezelID)
        #expect(Defaults.Keys.externalDisplayBezelMatchesSystem.name == "externalDisplayBezelMatchesSystem")
        #expect(Defaults.Keys.externalDisplayBezelLightsRoom.name == "externalDisplayBezelLightsRoom")
        #expect(Defaults.Keys.externalDisplayBezelLightsRoom.defaultValue == nil)
        #expect(Defaults.Keys.externalDisplayGameBezels.name == "externalDisplayGameBezels")
        #expect(Defaults.Keys.externalDisplayBezelProjectStyle.name == "externalDisplayBezelProjectStyle")
        #expect(Defaults.Keys.externalDisplayBezelByGame.name == "externalDisplayBezelByGame")
    }

    @Test("The package is pointed at Provenance's folders, settings and systems")
    func environment() {
        let environment = BezelEnvironment.current
        #expect(environment.libraryRootURL.lastPathComponent == "Bezels")
        #expect(environment.cacheURL.lastPathComponent == "BezelProject")
        #expect(environment.userAgent == "Provenance")
        #expect(environment.settings is DefaultsBezelSettings)
        #expect(environment.systemName(SystemIdentifier.SNES.rawValue) == SystemIdentifier.SNES.fullName)
        #expect(!environment.hasShaderPreset("slang:not/a-preset"))
    }

    // MARK: - Filters inside a TV (Provenance's shader library)

    private func entry(_ path: String, category: String = "crt", parameters: [ShaderParameterDescriptor]) -> ShaderCatalogEntry {
        ShaderCatalogEntry(id: .slang(path), name: path, category: category, passes: 1, historyFrames: 0,
                           usesFeedback: false, lutCount: 0, parameters: parameters, directory: nil)
    }

    private func parameter(_ name: String, initial: Float = 1, minimum: Float = 0, maximum: Float = 1) -> ShaderParameterDescriptor {
        ShaderParameterDescriptor(name: name, label: name, initial: initial, minimum: minimum, maximum: maximum, step: 1)
    }

    @Test("A filter's own curvature is switched off inside a TV")
    func curvatureOff() {
        let geom = entry("crt/crt-geom", parameters: [parameter("CURVATURE"), parameter("R", initial: 2, minimum: 0.1, maximum: 10)])
        #expect(TVBezelShader.curvatureOffValues(for: geom) == ["CURVATURE": 0])

        let lottes = entry("crt/crt-lottes", parameters: [parameter("warpX", initial: 0.031, maximum: 0.125),
                                                           parameter("warpY", initial: 0.041, maximum: 0.125)])
        #expect(TVBezelShader.curvatureOffValues(for: lottes) == ["warpX": 0, "warpY": 0])
    }

    @Test("A filter with no curvature switch is left alone")
    func noCurvature() {
        let plain = entry("crt/scanline", parameters: [parameter("SCANLINE_STRENGTH")])
        #expect(TVBezelShader.curvatureOffValues(for: plain).isEmpty)
        // A parameter that cannot be 0 is not a switch.
        let radius = entry("crt/other", parameters: [parameter("curvature", initial: 2, minimum: 1, maximum: 4)])
        #expect(TVBezelShader.curvatureOffValues(for: radius).isEmpty)
    }

    @Test("A built-in filter with its own curvature flattens the glass instead")
    func nativeCurvature() {
        let native = ShaderCatalogEntry(id: .native(.complexCRT), name: "Complex CRT", category: ShaderCatalog.nativeCategory,
                                        passes: 1, historyFrames: 0, usesFeedback: false, lutCount: 0,
                                        parameters: [parameter("complexCRTWarpX", initial: 0.03, maximum: 0.05)], directory: nil)
        #expect(TVBezelShader.bendsPictureItself(native))
        // A library filter is told to stop instead (curvatureOffValues), so the glass keeps its curve.
        let library = entry("crt/crt-geom", parameters: [parameter("CURVATURE")])
        #expect(!TVBezelShader.bendsPictureItself(library))
        let flat = ShaderCatalogEntry(id: .native(.lcd), name: "LCD", category: ShaderCatalog.nativeCategory,
                                      passes: 1, historyFrames: 0, usesFeedback: false, lutCount: 0,
                                      parameters: [parameter("lcdGridOpacity")], directory: nil)
        #expect(!TVBezelShader.bendsPictureItself(flat))
    }

    @Test("Filters with a frame of their own are recognised")
    func bezelFilters() {
        #expect(TVBezelShader.isBezelFilter(entry("bezel/uborder/uborder-koko-ambi", category: "bezel", parameters: [])))
        #expect(TVBezelShader.isBezelFilter(entry("border/sgb/sgb", category: "border", parameters: [])))
        #expect(!TVBezelShader.isBezelFilter(entry("crt/crt-geom", parameters: [])))
    }
}
#endif
