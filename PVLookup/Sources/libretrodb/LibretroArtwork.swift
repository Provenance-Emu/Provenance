import Foundation

/// Handles artwork URL construction and validation for libretro thumbnails
public struct LibretroArtwork {
    /// Base URL for libretro thumbnails
    private static let baseURL = "https://thumbnails.libretro.com"

    /// Types of artwork available
    public enum ArtworkType: String {
        case boxart = "Named_Boxarts"
        case snapshot = "Named_Snaps"
        case titleScreen = "Named_Titles"
    }

    /// Constructs artwork URLs for a given system and game name
    /// - Parameters:
    ///   - systemName: Full system name (e.g. "Nintendo - Game Boy Advance")
    ///   - gameName: Game name including region if available
    ///   - types: Array of artwork types to generate URLs for
    /// - Returns: Array of constructed URLs
    public static func constructURLs(systemName: String, gameName: String, types: [ArtworkType] = [.boxart]) -> [URL] {
        return types.compactMap { type in
            let urlString = "\(baseURL)/\(systemName)/\(type.rawValue)/\(gameName).png"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            return URL(string: urlString ?? "")
        }
    }

    /// Validates if a URL exists by performing a HEAD request
    /// - Parameter url: URL to validate
    /// - Returns: True if URL returns 200 status code
    public static func validateURL(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Gets valid artwork URLs for a given system and game name
    /// - Parameters:
    ///   - systemName: Full system name
    ///   - gameName: Game name including region if available
    /// - Returns: Array of valid artwork URLs
    public static func getValidURLs(systemName: String, gameName: String) async -> [URL] {
        let urls = constructURLs(systemName: systemName, gameName: gameName)

        var validURLs: [URL] = []
        for url in urls {
            if await validateURL(url) {
                validURLs.append(url)
            }
        }

        return validURLs
    }
}

import PVLookupTypes

extension ROMMetadata {
    var libretroDBArtworkURLs: [URL] {
        print("\nLibretroDB artwork URL generation for ROM:")
        print("- Title: \(gameTitle)")
        print("- System: \(systemID)")
        print("- System Name: \(systemID.libretroDatabaseName)")
        print("- Filename: \(romFileName ?? "nil")")
        print("- MD5: \(romHashMD5 ?? "nil")")

        let baseURL = "https://thumbnails.libretro.com"
        let systemFolder = systemID.libretroDatabaseName
            .replacingOccurrences(of: " ", with: "%20")

        // Remove the file extension using NSString's deletingPathExtension
        let filename = (romFileName as NSString?)?.deletingPathExtension
            .replacingOccurrences(of: " ", with: "%20") ?? ""

        print("\nURL Components:")
        print("- Base URL: \(baseURL)")
        print("- System folder: \(systemFolder)")
        print("- Processed filename: \(filename)")

        let boxartURL = URL(string: "\(baseURL)/\(systemFolder)/Named_Boxarts/\(filename).png")
        let titleURL = URL(string: "\(baseURL)/\(systemFolder)/Named_Titles/\(filename).png")
        let snapsURL = URL(string: "\(baseURL)/\(systemFolder)/Named_Snaps/\(filename).png")

        print("\nConstructed URLs:")
        print("- Boxart: \(boxartURL?.absoluteString ?? "nil")")
        print("- Title: \(titleURL?.absoluteString ?? "nil")")
        print("- Snaps: \(snapsURL?.absoluteString ?? "nil")")

        let urls = [boxartURL, titleURL, snapsURL].compactMap { $0 }
        print("\nReturning \(urls.count) valid URLs")

        return urls
    }
}
