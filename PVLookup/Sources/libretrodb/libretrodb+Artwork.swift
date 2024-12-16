import Foundation
import PVLookupTypes
import PVSystems

extension libretrodb {
    /// Constructs artwork URLs for a given ROM metadata
    public func getArtworkURLs(forGame metadata: ROMMetadata) -> [URL] {
        print("\nLibretroDB artwork URL construction:")
        print("Input metadata:")
        print("- Title: \(metadata.gameTitle)")
        print("- System: \(metadata.systemID)")
        print("- System Name: \(metadata.systemID.libretroDatabaseName)")
        print("- Filename: \(metadata.romFileName ?? "nil")")
        print("- MD5: \(metadata.romHashMD5 ?? "nil")")

        let baseURL = "https://thumbnails.libretro.com"
        let systemFolder = metadata.systemID.libretroDatabaseName
            .replacingOccurrences(of: " ", with: "%20")

        // Remove the file extension using NSString's deletingPathExtension
        let filename = (metadata.romFileName as NSString?)?.deletingPathExtension
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
