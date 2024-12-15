import Foundation
import SWCompression

extension FileManager {
    /// Extracts a zip file to a destination directory
    /// - Parameters:
    ///   - sourceURL: URL of the zip file
    ///   - destinationURL: URL of the directory to extract to
    func zipItem(at sourceURL: URL, unzipTo destinationURL: URL) throws {
        // Read the zip file data
        let data = try Data(contentsOf: sourceURL)

        // Extract the archive using SWCompression's ZIP support
        let archive = try ZipContainer.open(container: data)

        // Create destination directory if needed
        try createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // Extract each entry
        for entry in archive {
            let entryPath = destinationURL.appendingPathComponent(entry.info.name)

            // Create parent directories if needed
            try createDirectory(at: entryPath.deletingLastPathComponent(),
                              withIntermediateDirectories: true)

            // Extract and write the file
            if let data = entry.data {
                try data.write(to: entryPath)
            }
        }
    }
}
