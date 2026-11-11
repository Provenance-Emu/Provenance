#if os(iOS) || os(tvOS)
import Foundation
import PVLibrary
import PVLibrarySharing
import PVSystems
import RomMClient

@MainActor
enum RomMGameImport {
    static func system(for platform: RomMPlatform) -> SystemIdentifier? {
        let aliases: [String: SystemIdentifier] = [
            "dc": .Dreamcast, "naomi-2": .NAOMI2, "ngc": .GameCube, "gc": .GameCube,
            "arcade": .MAME, "ps1": .PSX, "sega32x": .Sega32X, "sega32": .Sega32X, "megacd": .SegaCD,
            "turbografx16": .PCE, "tg16": .PCE, "pc-engine": .PCE, "turbografx-cd": .PCECD,
            "wonderswan": .WonderSwan, "wonderswan-color": .WonderSwanColor, "sms": .MasterSystem,
            "atari2600": .Atari2600, "atari5200": .Atari5200, "atari7800": .Atari7800, "atari-jaguar": .AtariJaguar,
            "supergrafx": .SGFX, "coleco": .ColecoVision, "virtualboy": .VirtualBoy, "nds": .DS
        ]
        return platform.identifiers.lazy.compactMap { aliases[$0] ?? SystemMap.systemIdentifier(compact: $0) }.first
    }

    static func queue(_ game: RomMGame, from client: RomMClient, system: SystemIdentifier, staging: LibraryStaging) async throws {
        let download = try await client.download(game)
        defer { try? FileManager.default.removeItem(at: download.directory) }
        var files = download.files
        let primary = try selectPrimary(game, files: &files, directory: download.directory)
        try ECSDownloadedGame.validate(files: files)
        let prefix = download.directory.path + "/"
        let folder = staging.root.appendingPathComponent("romm-" + UUID().uuidString, isDirectory: true)
        let importDirectory = folder.appendingPathComponent("files", isDirectory: true)
        let manager = FileManager.default

        try Task.checkCancellation()
        guard !GameImporter.shared.isPausedForEmulation else { throw CancellationError() }
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        var handedOff = false
        defer { if !handedOff { staging.discard(folder) } }
        try manager.moveItem(at: download.directory, to: importDirectory)
        let localPrimary = importDirectory.appendingPathComponent(String(primary.path.dropFirst(prefix.count)))
        let item = ImportQueueItem(url: localPrimary)
        item.userChosenSystem = system
        item.requiresContentBasedDuplicateCheck = true
        if files.count > 1 {
            item.verifiedGameSetMembers = files.filter { $0 != primary }.map {
                importDirectory.appendingPathComponent(String($0.path.dropFirst(prefix.count)))
            }
        }
        try Task.checkCancellation()
        await GameImporter.shared.addImport(item)
        let accepted = await GameImporter.shared.importQueue.contains { $0.id == item.id }
        guard accepted || item.status == .processing || item.status == .success else {
            throw CocoaError(.fileWriteFileExists)
        }
        handedOff = true
        staging.markHandedOff(folder)
        GameImporter.shared.startProcessing()
    }

    private static func selectPrimary(_ game: RomMGame, files: inout [URL], directory: URL) throws -> URL {
        guard let first = files.first else { throw RomMError.invalidContent }
        if files.count == 1 { return first }

        let playlists = files.filter { $0.pathExtension.lowercased() == "m3u" }
        if !playlists.isEmpty {
            guard playlists.count == 1, let playlist = playlists.first else { throw RomMError.invalidContent }
            try requireMembers(files, beside: playlist)
            return playlist
        }
        let archives = files.filter { $0.pathExtension.lowercased() == "zip" }
        if archives.count == 1, let archive = archives.first {
            let companion = ArchiveCompanionLayout.companionDirectory(forArchiveAt: archive).path + "/"
            guard files.filter({ $0 != archive }).allSatisfy({
                $0.path.hasPrefix(companion) && $0.pathExtension.lowercased() == "chd"
            }) else { throw RomMError.invalidContent }
            return archive
        }
        let discs = files.filter { ["cue", "gdi", "chd", "cdi", "iso"].contains($0.pathExtension.lowercased()) }
        if discs.count == 1, let disc = discs.first, ["cue", "gdi"].contains(disc.pathExtension.lowercased()) {
            try requireMembers(files, beside: disc)
            return disc
        }
        guard discs.count > 1,
              files.allSatisfy({ ["cue", "gdi", "chd", "cdi", "iso", "bin", "raw", "img", "sub", "sbi", "wav"]
                  .contains($0.pathExtension.lowercased()) })
        else { throw RomMError.invalidContent }

        let name = (game.fsName as NSString).lastPathComponent
        let playlistName = name.isEmpty || name == "." || name == ".." ? "RomM-(game.id).m3u" : name + ".m3u"
        let playlist = directory.appendingPathComponent(playlistName)
        let prefix = directory.path + "/"
        let tracks = discs.map { String($0.path.dropFirst(prefix.count)) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        try (tracks.joined(separator: "\n") + "\n").write(to: playlist, atomically: true, encoding: .utf8)
        files.append(playlist)
        return playlist
    }

    private static func requireMembers(_ files: [URL], beside primary: URL) throws {
        let prefix = primary.deletingLastPathComponent().path + "/"
        guard files.allSatisfy({ $0.path.hasPrefix(prefix) }) else { throw RomMError.invalidContent }
    }
}

enum RomMLoginStore {
    private static let store = KeychainECSTokenStore(service: "org.provenance-emu.romm")

    static func read(_ server: RomMAddress) -> String? {
        store.token(for: server.baseURL)
    }

    static func write(_ value: String?, server: RomMAddress) throws {
        store.setToken(value, for: server.baseURL)
        guard read(server) == value else { throw CocoaError(.fileWriteUnknown) }
    }
}
#endif
