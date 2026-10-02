//
//  ThinContentArchiveResolverTests.swift
//  PVLibRetroTests
//
//  A zipped game must reach a core that can't read zips as the ROM inside it,
//  while arcade cores that read their romset zip keep getting the zip.
//

import Foundation
import Testing
import PVArchiving
@testable import PVCoreBridgeRetro

struct ThinContentArchiveResolverTests {

    private let snes9xExtensions: Set<String> = ["smc", "sfc", "swc", "fig", "bs", "st"]

    @Test func parsesValidExtensions() {
        #expect(ThinContentArchiveResolver.extensions(fromValidExtensions: "J64|jag| rom ||bin")
                == ["j64", "jag", "rom", "bin"])
        #expect(ThinContentArchiveResolver.extensions(fromValidExtensions: nil).isEmpty)
    }

    @Test func extractsZipForCoreThatCannotReadIt() {
        #expect(ThinContentArchiveResolver.shouldExtract(contentPath: "/r/Game.zip",
                                                         validExtensions: snes9xExtensions,
                                                         blockExtract: false))
        #expect(ThinContentArchiveResolver.shouldExtract(contentPath: "/r/Game.7Z",
                                                         validExtensions: snes9xExtensions,
                                                         blockExtract: false))
    }

    @Test func leavesZipForCoreThatReadsIt() {
        #expect(!ThinContentArchiveResolver.shouldExtract(contentPath: "/r/sf2.zip",
                                                          validExtensions: ["zip", "7z", "chd"],
                                                          blockExtract: false))
    }

    @Test func honoursBlockExtractAndUnknownExtensions() {
        #expect(!ThinContentArchiveResolver.shouldExtract(contentPath: "/r/Game.zip",
                                                          validExtensions: snes9xExtensions,
                                                          blockExtract: true))
        #expect(!ThinContentArchiveResolver.shouldExtract(contentPath: "/r/Game.zip",
                                                          validExtensions: [],
                                                          blockExtract: false))
    }

    @Test func leavesNonArchivesAlone() {
        #expect(!ThinContentArchiveResolver.shouldExtract(contentPath: "/r/Game.sfc",
                                                          validExtensions: snes9xExtensions,
                                                          blockExtract: false))
    }

    @Test func prefersCueSheetOverTracks() {
        let files = ["/x/Game (Track 1).bin", "/x/Game (Track 2).bin", "/x/Game.cue"].map(URL.init(fileURLWithPath:))
        let picked = ThinContentArchiveResolver.preferredContent(among: files, validExtensions: ["bin", "cue"])
        #expect(picked?.lastPathComponent == "Game.cue")
    }

    @Test func skipsMacOSMetadataAndUnacceptedFiles() {
        let files = ["/x/__MACOSX/._Game.sfc", "/x/readme.txt", "/x/Game.sfc"].map(URL.init(fileURLWithPath:))
        let picked = ThinContentArchiveResolver.preferredContent(among: files, validExtensions: snes9xExtensions)
        #expect(picked?.lastPathComponent == "Game.sfc")
    }

    @Test func extractsTheRomFromARealZip() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveTest-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }

        let staging = root.appendingPathComponent("staging")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        let rom = Data([0x4A, 0x41, 0x47, 0x55, 0x41, 0x52])
        try rom.write(to: staging.appendingPathComponent("Game.j64"))
        try Data("notes".utf8).write(to: staging.appendingPathComponent("readme.txt"))

        let zip = root.appendingPathComponent("Game.zip")
        #expect(PVArchiveHelper.shared.createZIP(at: zip.path, fromDirectory: staging.path))

        let cache = root.appendingPathComponent("cache").path
        let resolved = ThinContentArchiveResolver.resolveContentPath(zip.path,
                                                                     validExtensions: "j64|jag|rom|abs|cof|bin|prg",
                                                                     blockExtract: false,
                                                                     extractionRoot: cache)
        #expect(URL(fileURLWithPath: resolved).lastPathComponent == "Game.j64")
        #expect(fm.contents(atPath: resolved) == rom)

        // A second boot reuses the extracted copy.
        let again = ThinContentArchiveResolver.resolveContentPath(zip.path,
                                                                  validExtensions: "j64|jag|rom|abs|cof|bin|prg",
                                                                  blockExtract: false,
                                                                  extractionRoot: cache)
        #expect(again == resolved)
    }

    @Test func fallsBackToTheArchiveWhenNothingInsideMatches() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveTest-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }

        let staging = root.appendingPathComponent("staging")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data("notes".utf8).write(to: staging.appendingPathComponent("readme.txt"))
        let zip = root.appendingPathComponent("Docs.zip")
        #expect(PVArchiveHelper.shared.createZIP(at: zip.path, fromDirectory: staging.path))

        let resolved = ThinContentArchiveResolver.resolveContentPath(zip.path,
                                                                     validExtensions: "smc|sfc",
                                                                     blockExtract: false,
                                                                     extractionRoot: root.appendingPathComponent("cache").path)
        #expect(resolved == zip.path)
    }
}
