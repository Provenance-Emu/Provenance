import PVLookupTypes
import PVSystems
import Foundation

/// Errors that can occur when using TheGamesDB service
public enum TheGamesDBServiceError: Error {
    case notFound
    case badRequest
    case forbidden
    case unknown
    case networkError(Error)
}

/// Service for accessing TheGamesDB API
public final class TheGamesDBService: ArtworkLookupOnlineService {


    private let client: any TheGamesDBClient

    /// Create a new instance of TheGamesDBService
    /// - Parameter apiKey: Optional API key. If not provided, uses default key.
    public init(apiKey: String = API_KEY) {
        self.client = TheGamesDBClientImpl(apiKey: apiKey)
    }

    /// Create a new instance with a custom client (primarily for testing)
    /// - Parameter client: The client to use
    init(client: any TheGamesDBClient) {
        self.client = client
    }

    public func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: [ArtworkType]?
    ) async throws -> [ArtworkMetadata]? {
        // Search for games
        let response = try await client.searchGames(
            name: name,
            platformID: systemID?.theGamesDBID
        )

        // No games found
        if response.data.games.isEmpty {
            return nil
        }

        // Get artwork for each game
        var allArtwork: [ArtworkMetadata] = []
        for game in response.data.games {
            let gameID = "\(game.id)"
            if let gameArtwork = try await getArtwork(
                forGameID: gameID,
                artworkTypes: artworkTypes
            ) {
                // Sort artwork within this game's results
                let sortedGameArtwork = sortArtworkByType(gameArtwork)
                allArtwork.append(contentsOf: sortedGameArtwork)
            }
        }

        return allArtwork.isEmpty ? nil : allArtwork
    }

    // Helper function to sort artwork by type priority
    private func sortArtworkByType(_ artwork: [ArtworkMetadata]) -> [ArtworkMetadata] {
        let priority: [ArtworkType] = [
            .boxFront,    // Front cover is highest priority
            .boxBack,     // Back cover next
            .screenshot,  // Screenshots
            .titleScreen, // Title screens
            .clearLogo,  // Clear logos
            .banner,     // Banners
            .fanArt,     // Fan art
            .manual,     // Manuals
            .other       // Other types last
        ]

        return artwork.sorted { a, b in
            let aIndex = priority.firstIndex(of: a.type) ?? priority.count
            let bIndex = priority.firstIndex(of: b.type) ?? priority.count
            return aIndex < bIndex
        }
    }

    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: [ArtworkType]?
    ) async throws -> [ArtworkMetadata]? {
        let types = artworkTypes?.compactMap { $0.theGamesDBType }
            .filter { !$0.isEmpty }

        let response = try await client.getGameImages(gameID: gameID, types: types)

        var artworks: [ArtworkMetadata] = []
        let baseURL = response.data.base_url.original

        // Process boxart first
        for (_, images) in response.data.imagesDictionary {  // Use imagesDictionary property
            for image in images {
                if image.type == "boxart",
                   let url = URL(string: baseURL + image.filename),
                   let type = ArtworkType(fromTheGamesDB: image.type, side: image.side),
                   artworkTypes?.contains(type) ?? true {
                    artworks.append(ArtworkMetadata(
                        url: url,
                        type: type,
                        resolution: image.resolution,
                        description: nil,
                        source: "TheGamesDB"
                    ))
                }
            }
        }

        // Then process other types
        for (_, images) in response.data.imagesDictionary {  // Use imagesDictionary property
            for image in images where image.type != "boxart" {
                if let url = URL(string: baseURL + image.filename),
                   let type = ArtworkType(fromTheGamesDB: image.type, side: image.side),
                   artworkTypes?.contains(type) ?? true {
                    artworks.append(ArtworkMetadata(
                        url: url,
                        type: type,
                        resolution: image.resolution,
                        description: nil,
                        source: "TheGamesDB"
                    ))
                }
            }
        }

        return artworks.isEmpty ? nil : artworks
    }

    /// Gets artwork URLs for a ROM by searching TheGamesDB
    /// - Parameter rom: ROM metadata to search with
    /// - Returns: Array of artwork URLs, or nil if none found
    public func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        let gameTitle = rom.gameTitle
        // First try searching by game name if we have one
        if !gameTitle.isEmpty {
            let artwork = try await searchArtwork(
                byGameName: gameTitle,
                systemID: rom.systemID,
                artworkTypes: nil  // Get all artwork types
            )

            // Sort artwork and return URLs
            if let artwork = artwork {
                let sortedArtwork = sortArtworkByType(artwork)
                let urls = sortedArtwork.map(\.url)
                if !urls.isEmpty {
                    return urls
                }
            }
        }

        // If we have a filename but no results from title search, try with filename
        if let filename = rom.romFileName, !filename.isEmpty {
            // Strip extension and common ROM notation like (USA), [!], etc
            let cleanName = (filename as NSString).deletingPathExtension
                .replacingOccurrences(of: "\\s*\\([^)]*\\)|\\s*\\[[^\\]]*\\]",
                                    with: "",
                                    options: [.regularExpression])

            let artwork = try await searchArtwork(
                byGameName: cleanName,
                systemID: rom.systemID,
                artworkTypes: nil
            )

            // Sort artwork and return URLs
            if let artwork = artwork {
                let sortedArtwork = sortArtworkByType(artwork)
                return sortedArtwork.map { $0.url }
            }
        }

        return nil
    }
}

private extension ArtworkType {
    init?(fromTheGamesDB type: String, side: String?) {
        switch (type, side) {
        case ("boxart", "front"): self = .boxFront
        case ("boxart", "back"): self = .boxBack
        case ("fanart", _): self = .fanArt
        case ("banner", _): self = .banner
        case ("screenshot", _): self = .screenshot
        case ("clearlogo", _): self = .clearLogo
        case ("titlescreen", _): self = .titleScreen
        default: self = .other
        }
    }

    var theGamesDBType: String {
        switch self {
        case .boxFront, .boxBack: return "boxart"
        case .fanArt: return "fanart"
        case .banner: return "banner"
        case .screenshot: return "screenshot"
        case .clearLogo: return "clearlogo"
        case .titleScreen: return "titlescreen"
        case .manual, .other: return ""
        }
    }
}

private extension SystemIdentifier {
    /// Convert our SystemIdentifier to TheGamesDB platform ID
    var theGamesDBID: Int? {
        switch self {
        // Nintendo Systems
        case .NES: return 7  // Nintendo Entertainment System (NES)
        case .SNES: return 6  // Super Nintendo (SNES)
        case .N64: return 3  // Nintendo 64
        case .GameCube: return 2  // Nintendo GameCube
        case .GB: return 4  // Nintendo Game Boy
        case .GBC: return 41  // Nintendo Game Boy Color
        case .GBA: return 5  // Nintendo Game Boy Advance
        case .DS: return 8  // Nintendo DS
        case ._3DS: return 4912  // Nintendo 3DS
        case .VirtualBoy: return 4918  // Nintendo Virtual Boy
        case .PokemonMini: return 4957  // Nintendo Pokémon Mini
        case .FDS: return 4936  // Famicom Disk System

        // Sega Systems
        case .Genesis: return 18  // Sega Genesis
//        case .MegaDrive: return "36"  // Sega Mega Drive
        case .MasterSystem: return 35  // Sega Master System
        case .GameGear: return 20  // Sega Game Gear
        case .SegaCD: return 21  // Sega CD
        case .Saturn: return 17  // Sega Saturn
        case .Dreamcast: return 16  // Sega Dreamcast
        case .Sega32X: return 33  // Sega 32X
        case .SG1000: return 4949  // SEGA SG-1000
//        case .Pico: return "4958"  // Sega Pico

        // Sony Systems
        case .PSX: return 10  // Sony PlayStation
        case .PS2: return 11  // Sony PlayStation 2
        case .PS3: return 12  // Sony PlayStation 3
//        case .PS4: return "4919"  // Sony PlayStation 4
//        case .PS5: return "4980"  // Sony PlayStation 5
        case .PSP: return 13  // Sony PSP
//        case .PSVita: return "39"  // Sony PS Vita

        // Atari Systems
        case .Atari2600: return 22  // Atari 2600
        case .Atari5200: return 26  // Atari 5200
        case .Atari7800: return 27  // Atari 7800
        case .Lynx: return 4924  // Atari Lynx
        case .AtariJaguar: return 28  // Atari Jaguar
        case .AtariJaguarCD: return 29  // Atari Jaguar CD
//        case .AtariXE: return "30"  // Atari XE

        // NEC Systems
        case .PCE: return 34  // TurboGrafx 16
        case .PCFX: return 4930  // PC-FX
        case .PCECD: return 4955  // TurboGrafx CD

        // SNK Systems
        case .NeoGeo: return 24  // Neo Geo
//        case .NeoGeoCD: return "4956"  // Neo Geo CD
        case .NGP: return 4922  // Neo Geo Pocket
        case .NGPC: return 4923  // Neo Geo Pocket Color

        // Other Systems
        case ._3DO: return 25  // 3DO
        case .WonderSwan: return 4925  // WonderSwan
        case .WonderSwanColor: return 4926  // WonderSwan Color
        case .Vectrex: return 4939  // Vectrex
        case .Intellivision: return 32  // Intellivision
        case .ColecoVision: return 31  // ColecoVision
        case .MAME: return 23  // Arcade
        case .MSX: return 4929  // MSX
        case .C64: return 40  // Commodore 64

//        default: return nil
        case .AppleII: return nil // Apple II
        case .Atari8bit: return nil // Atari 8-Bit
        case .AtariST: return 4937  // Atari ST (we had this as nil, but it exists!)
        case .DOS: return nil // IBM/PC DOS
        case .EP128: return nil // EP128
        case .Macintosh: return nil // Apple Macintosh
        case .MegaDuck: return nil // Megaduck
        case .MSX2: return nil // Microsoft MSX2
        case .Music: return nil // Game Music
        case .Odyssey2: return 4927  // Magnavox Odyssey 2 (we had this as nil, but it exists!)
        case .PalmOS: return nil // Palm PalmOS
        case .RetroArch: return nil // Placeholder
        case .SGFX: return nil // NEC Super Grafx
        case .Supervision: return nil // Watara Supervision
        case .TIC80: return nil // Tic-80
        case .Wii: return nil // Nintndo Wii
        case .ZXSpectrum: return 4913  // Sinclair ZX Spectrum (we had this as nil, but it exists!)
        case .Unknown:  return nil // Default unknown
        }
    }
}
