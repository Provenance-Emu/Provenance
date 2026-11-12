//
//  TVBezelLibraryTests.swift
//  PVUI
//
//  The player's bezels: importing images, the files kept beside them, and The Bezel
//  Project's system table. Every image is drawn here; no artwork is in the repository.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import PVSettings
import PVSystems
@testable import PVUIBase

@Suite("TVBezelLibrary")
struct TVBezelLibraryTests {

    private static let imageSize = CGSize(width: 192, height: 108)
    /// The see-through screen of `makeBezel`, from the top left.
    private static let hole = CGRect(x: 24, y: 4, width: 144, height: 100)

    private let folder: URL
    private let library: TVBezelLibrary
    private let inbox: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("TVBezelLibraryTests-\(UUID().uuidString)")
        folder = base.appendingPathComponent("Bezels")
        inbox = base.appendingPathComponent("Inbox")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        library = TVBezelLibrary(rootURL: folder)
    }

    /// Writes a PNG: opaque grey, with `hole` cut clear when given.
    @discardableResult
    private func makeBezel(_ name: String, in directory: URL, hole: CGRect? = TVBezelLibraryTests.hole) throws -> URL {
        let size = Self.imageSize
        let context = try #require(CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        if let hole {
            // Core Graphics counts rows from the bottom.
            context.clear(CGRect(x: hole.minX, y: size.height - hole.maxY, width: hole.width, height: hole.height))
        }
        let image = try #require(context.makeImage())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    @Test("An image's screen is read from its transparency, from the top left")
    func analyze() throws {
        let url = try makeBezel("tv.png", in: inbox)
        let analysis = try TVBezelImage.analyze(url)
        #expect(analysis.size == Self.imageSize)
        #expect(analysis.screen == Self.hole)
        #expect(TVBezelImage.displayImage(url, maxPixel: 96)?.width == 96)
    }

    @Test("A picked PNG becomes a listed bezel that survives a fresh read of the folder")
    func importImage() throws {
        let url = try makeBezel("My TV.png", in: inbox)
        let result = library.importFiles(at: [url])
        #expect(result.problems.isEmpty)
        let bezel = try #require(result.imported.first)
        #expect(bezel.id == "file:Imported/My TV.png")
        #expect(bezel.name == "My TV")
        #expect(bezel.isListed)
        #expect(bezel.source == .imported)
        #expect(bezel.image?.screen == Self.hole)
        #expect(bezel.image?.size == Self.imageSize)

        let reread = TVBezelLibrary(rootURL: folder)
        reread.refresh()
        #expect(reread.bezels.map(\.id) == [bezel.id])
        #expect(reread.bezels.first?.name == "My TV")
        #expect(reread.bezels.first?.image?.screen == Self.hole)
    }

    @Test("A .cfg names its image; a touch-control overlay and its images are refused")
    func importWithConfigs() throws {
        let art = try makeBezel("art.png", in: inbox)
        let config = inbox.appendingPathComponent("art.cfg")
        try "overlays = 1\noverlay0_overlay = art.png\noverlay0_name = \"Arcade Cabinet\"\noverlay0_descs = 0".write(to: config, atomically: true, encoding: .utf8)
        let pad = try makeBezel("pad.png", in: inbox)
        let padConfig = inbox.appendingPathComponent("pad.cfg")
        try "overlays = 1\noverlay0_overlay = pad.png\noverlay0_descs = 12".write(to: padConfig, atomically: true, encoding: .utf8)
        let orphan = inbox.appendingPathComponent("orphan.cfg")
        try "overlay0_overlay = elsewhere.png".write(to: orphan, atomically: true, encoding: .utf8)

        let result = library.importFiles(at: [art, config, pad, padConfig, orphan])
        #expect(result.imported.map(\.name) == ["Arcade Cabinet"])
        #expect(result.problems.contains { $0.file == "pad.cfg" && $0.problem == .touchControls })
        #expect(result.problems.contains { $0.file == "orphan.cfg" && $0.problem == .missingImage("elsewhere.png") })
        #expect(library.bezels.count == 1)
    }

    @Test("A folder is imported whole, and a second file of the same name is kept beside the first")
    func importFolderAndDuplicates() throws {
        let pack = inbox.appendingPathComponent("pack")
        try makeBezel("one.png", in: pack)
        try makeBezel("two.png", in: pack)
        #expect(library.importFiles(at: [pack]).imported.count == 2)
        let again = library.importFiles(at: [pack.appendingPathComponent("one.png")])
        #expect(again.imported.first?.id == "file:Imported/one 2.png")
        #expect(library.listed.count == 3)
    }

    @Test("Images that are not bezels are refused and leave nothing behind")
    func refusals() throws {
        let opaque = try makeBezel("opaque.png", in: inbox, hole: nil)
        let tiny = try makeBezel("tiny.png", in: inbox, hole: CGRect(x: 4, y: 4, width: 10, height: 10))
        let notImage = inbox.appendingPathComponent("broken.png")
        try Data("not a png".utf8).write(to: notImage)
        let result = library.importFiles(at: [opaque, tiny, notImage])
        #expect(result.imported.isEmpty)
        #expect(Set(result.problems.map(\.problem)) == [.noScreen, .screenTooSmall, .notAnImage])
        #expect(library.bezels.isEmpty)
        let left = (try? FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("Imported").path)) ?? []
        #expect(left.isEmpty)
    }

    @Test("A PNG put into Imported by hand is taken in once; one that is no bezel is remembered and skipped")
    func droppedFiles() throws {
        let imported = folder.appendingPathComponent("Imported")
        try makeBezel("dropped.png", in: imported)
        try makeBezel("photo.png", in: imported, hole: nil)
        library.refresh()
        #expect(library.bezels.map(\.name) == ["dropped"])
        #expect(FileManager.default.fileExists(atPath: imported.appendingPathComponent("photo.png.bezel.json").path))
        // A second read changes nothing.
        library.refresh()
        #expect(library.bezels.map(\.id) == ["file:Imported/dropped.png"])
    }

    @Test("Renaming, giving a system, unlisting and deleting are kept beside the image")
    func changes() throws {
        let bezel = try #require(library.importFiles(at: [try makeBezel("tv.png", in: inbox)]).imported.first)
        library.update(id: bezel.id, name: "Bedroom TV", system: .some(SystemIdentifier.SNES.rawValue))
        var reread = TVBezelLibrary(rootURL: folder)
        reread.refresh()
        #expect(reread.bezel(id: bezel.id)?.name == "Bedroom TV")
        #expect(reread.bezel(id: bezel.id)?.preferredSystems == [SystemIdentifier.SNES.rawValue])

        library.update(id: bezel.id, system: .some(nil), listed: false)
        #expect(library.bezel(id: bezel.id)?.preferredSystems == [])
        #expect(library.listed.isEmpty)
        #expect(library.bezel(id: bezel.id)?.name == "Bedroom TV")

        library.delete(id: bezel.id)
        reread = TVBezelLibrary(rootURL: folder)
        reread.refresh()
        #expect(reread.bezels.isEmpty)
    }

    @Test("A repository's downloads are counted and deleted together")
    func downloads() throws {
        let source = try makeBezel("art.png", in: inbox)
        let repository = BezelProjectRepository(style: .gameArt, suffix: "SNES")
        let folderPath = BezelProjectService.libraryFolder(for: repository)
        let entry = BezelProjectListing.Entry(path: "GameBezels/SNES/ActRaiser (USA).png", kind: .game, size: 1)
        let path = BezelProjectService.libraryPath(for: entry, in: repository)
        let bezel = try library.add(imageAt: source, relativePath: path, name: entry.name, system: nil,
                                    source: .bezelProject, listed: false)
        #expect(bezel.id == "file:The Bezel Project/bezelproject-SNES/GameBezels/SNES/ActRaiser (USA).png")
        #expect(library.bezel(relativePath: path) == bezel)
        #expect(library.listed.isEmpty)
        #expect(library.usage(relativePath: folderPath).count == 1)
        #expect(library.usage(relativePath: folderPath).bytes > 0)
        library.deleteFolder(relativePath: folderPath)
        #expect(library.bezels.isEmpty)
    }
}

@Suite("BezelProjectService")
struct BezelProjectServiceTests {

    @Test("The system table names real systems, none of them with two screens")
    func systemTable() {
        let systems = BezelProjectService.systems
        #expect(!systems.isEmpty)
        for (systemID, suffixes) in systems {
            #expect(SystemIdentifier(rawValue: systemID) != nil, "unknown system \(systemID)")
            #expect(!suffixes.isEmpty && !suffixes.contains(""), "\(systemID) has no repository")
        }
        #expect(systems[SystemIdentifier.DS.rawValue] == nil)
        #expect(systems[SystemIdentifier._3DS.rawValue] == nil)
        #expect(BezelProjectService.repositories(systemID: SystemIdentifier.SNES.rawValue, style: .systemArt).first?.name == "bezelprojectSA-SNES")
        #expect(BezelProjectService.repositories(systemID: "not-a-system", style: .gameArt).isEmpty)
    }

    @Test("A system's bezel reads without its dashes; a game's name is left alone")
    func displayNames() {
        let system = BezelProjectListing.Entry(path: "Super-Nintendo-Entertainment-System.png", kind: .system, size: 1)
        let game = BezelProjectListing.Entry(path: "GameBezels/SNES/Spider-Man (USA).png", kind: .game, size: 1)
        #expect(BezelProjectService.displayName(for: system) == "Super Nintendo Entertainment System")
        #expect(BezelProjectService.displayName(for: game) == "Spider-Man (USA)")
    }
}
