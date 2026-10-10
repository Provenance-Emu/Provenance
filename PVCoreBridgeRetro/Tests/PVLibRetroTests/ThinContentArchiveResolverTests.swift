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

    @Test func parsesInfoSupportedExtensions() {
        let text = """
        # comment = ignored
        display_name = "Nintendo - SNES / FFC (Snes9x)"
        supported_extensions = "smc|sfc|swc|fig|bs|st"
        needs_fullpath = "false"
        """
        #expect(ThinContentArchiveResolver.supportedExtensions(inInfoText: text) == "smc|sfc|swc|fig|bs|st")
        #expect(ThinContentArchiveResolver.supportedExtensions(inInfoText: "corename = \"x\"\n") == nil)
    }

    @Test func readsSupportedExtensionsBesideTheDylib() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveInfo-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let dylib = root.appendingPathComponent("snes9x_libretro.dylib")
        try Data().write(to: dylib)
        try Data("supported_extensions = \"sfc|smc\"\n".utf8)
            .write(to: root.appendingPathComponent("snes9x_libretro.info"))
        #expect(ThinContentArchiveResolver.supportedExtensions(besideDylib: dylib.path) == "sfc|smc")
        #expect(ThinContentArchiveResolver.supportedExtensions(besideDylib: nil) == nil)
    }

    @Test func inflatesASingleRomIntoMemory() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveMem-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let zip = try makeZip(root: root, files: ["Game.sfc": Data([0x01, 0x02, 0x03, 0x04])])
        let resolved = ThinContentArchiveResolver.resolveContent(atPath: zip.path,
                                                                 validExtensions: "smc|sfc|swc",
                                                                 infoExtensions: nil,
                                                                 blockExtract: false,
                                                                 needFullPath: false,
                                                                 forceExtract: false,
                                                                 extractionRoot: root.appendingPathComponent("cache").path)
        #expect(resolved.data == Data([0x01, 0x02, 0x03, 0x04]))
        #expect(URL(fileURLWithPath: resolved.path).pathExtension == "sfc")
        #expect(resolved.retryUncompressedOnFailure)
        // The ROM was not written out. The path only names the extension.
        #expect(!fm.fileExists(atPath: resolved.path))
    }

    @Test func leavesANativeZipAndRetriesWhenItAlsoHoldsARom() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveNative-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let zippedROM = try makeZip(root: root, name: "Zelda.zip", files: ["Zelda.sfc": Data([0x53, 0x46, 0x43])])
        let both = ThinContentArchiveResolver.resolveContent(atPath: zippedROM.path,
                                                             validExtensions: "zip|sfc",
                                                             infoExtensions: "sfc",
                                                             blockExtract: false,
                                                             needFullPath: false,
                                                             forceExtract: false,
                                                             extractionRoot: root.appendingPathComponent("cache").path)
        #expect(both.path == zippedROM.path)
        #expect(both.data == nil)
        #expect(both.retryUncompressedOnFailure)

        let romset = try makeZip(root: root, name: "sf2.zip", files: ["sf2.1": Data([0x01]), "sf2.2": Data([0x02])])
        let arcade = ThinContentArchiveResolver.resolveContent(atPath: romset.path,
                                                               validExtensions: "zip|7z",
                                                               infoExtensions: nil,
                                                               blockExtract: false,
                                                               needFullPath: true,
                                                               forceExtract: false,
                                                               extractionRoot: root.appendingPathComponent("cache").path)
        #expect(arcade.path == romset.path)
        #expect(!arcade.retryUncompressedOnFailure)
    }

    @Test func infoExtensionsFillAnEmptyCoreList() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveInfoExt-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let rom = Data([0x11, 0x22])
        let zip = try makeZip(root: root, files: ["Game.sfc": rom])
        let resolved = ThinContentArchiveResolver.resolveContent(atPath: zip.path,
                                                                 validExtensions: nil,
                                                                 infoExtensions: "sfc|smc",
                                                                 blockExtract: false,
                                                                 needFullPath: false,
                                                                 forceExtract: false,
                                                                 extractionRoot: root.appendingPathComponent("cache").path)
        #expect(resolved.data == rom)
    }

    @Test func liveCoreExtensionsWinOverTheInfoFile() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveLive-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let zip = try makeZip(root: root, name: "sf2.zip", files: ["sf2.1": Data([0x01])])
        let resolved = ThinContentArchiveResolver.resolveContent(atPath: zip.path,
                                                                 validExtensions: "zip|7z",
                                                                 infoExtensions: "sfc|smc",
                                                                 blockExtract: false,
                                                                 needFullPath: false,
                                                                 forceExtract: false,
                                                                 extractionRoot: root.appendingPathComponent("cache").path)
        #expect(resolved.path == zip.path)
        #expect(resolved.data == nil)
        #expect(!resolved.retryUncompressedOnFailure)
    }

    @Test func retriesByExtractingTheRom() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveRetry-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let rom = Data([0xAB, 0xCD])
        let zip = try makeZip(root: root, files: ["Game.sfc": rom])
        let resolved = ThinContentArchiveResolver.resolveContent(atPath: zip.path,
                                                                 validExtensions: "zip|sfc",
                                                                 infoExtensions: nil,
                                                                 blockExtract: false,
                                                                 needFullPath: true,
                                                                 forceExtract: true,
                                                                 extractionRoot: root.appendingPathComponent("cache").path)
        #expect(URL(fileURLWithPath: resolved.path).lastPathComponent == "Game.sfc")
        #expect(fm.contents(atPath: resolved.path) == rom)
        #expect(!resolved.retryUncompressedOnFailure)
    }

    @Test func extractsADiscBundleInsteadOfOneMemoryBuffer() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveDisc-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let zip = try makeZip(root: root, name: "Disc.zip", files: [
            "Disc.cue": Data("FILE \"Disc.bin\" BINARY\n".utf8),
            "Disc.bin": Data(repeating: 0xCD, count: 32)
        ])
        let resolved = ThinContentArchiveResolver.resolveContent(atPath: zip.path,
                                                                 validExtensions: "cue|bin",
                                                                 infoExtensions: nil,
                                                                 blockExtract: false,
                                                                 needFullPath: false,
                                                                 forceExtract: false,
                                                                 extractionRoot: root.appendingPathComponent("cache").path)
        #expect(resolved.data == nil)
        #expect(URL(fileURLWithPath: resolved.path).lastPathComponent == "Disc.cue")
        #expect(fm.fileExists(atPath: resolved.path))
    }

    @Test func materializesOneVirtualArchiveMember() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveVFS-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let rom = Data([0x4A, 0x41, 0x47])
        let zip = try makeZip(root: root, files: ["Game.j64": rom, "readme.txt": Data("notes".utf8)])
        let cache = root.appendingPathComponent("cache").path
        let virtual = zip.path + "#Game.j64"
        let materialized = ThinContentArchiveResolver.materializeVirtualPath(virtual, extractionRoot: cache)
        #expect(fm.contents(atPath: materialized ?? "") == rom)
        let again = ThinContentArchiveResolver.materializeVirtualPath(virtual, extractionRoot: cache)
        #expect(again == materialized)
    }

    @Test func unknownCoreRetryPicksTheLargestFile() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ThinArchiveLargest-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let rom = Data(repeating: 0xEE, count: 64)
        let zip = try makeZip(root: root, files: ["readme.txt": Data("hi".utf8), "Game.bin": rom])
        let first = ThinContentArchiveResolver.resolveContent(atPath: zip.path,
                                                              validExtensions: "",
                                                              infoExtensions: nil,
                                                              blockExtract: false,
                                                              needFullPath: true,
                                                              forceExtract: false,
                                                              extractionRoot: root.appendingPathComponent("cache").path)
        #expect(first.path == zip.path)
        #expect(first.retryUncompressedOnFailure)
        let retry = ThinContentArchiveResolver.resolveContent(atPath: zip.path,
                                                              validExtensions: "",
                                                              infoExtensions: nil,
                                                              blockExtract: false,
                                                              needFullPath: true,
                                                              forceExtract: true,
                                                              extractionRoot: root.appendingPathComponent("cache").path)
        #expect(URL(fileURLWithPath: retry.path).lastPathComponent == "Game.bin")
        #expect(fm.contents(atPath: retry.path) == rom)
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

    private func makeZip(root: URL, name: String = "Game.zip", files: [String: Data]) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent("staging-\(UUID().uuidString)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        for (fileName, data) in files {
            let url = staging.appendingPathComponent(fileName)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        let zip = root.appendingPathComponent(name)
        #expect(PVArchiveHelper.shared.createZIP(at: zip.path, fromDirectory: staging.path))
        return zip
    }
}
