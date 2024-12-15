import Foundation
import Zip

extension FileManager {
    /// Extracts a zip file to a destination directory
    /// - Parameters:
    ///   - sourceURL: URL of the zip file
    ///   - destinationURL: URL of the directory to extract to
    func zipItem(at sourceURL: URL, unzipTo destinationURL: URL) throws {
        do {
            print("FileManager+Zip: Starting extraction...")
            print("FileManager+Zip: Source file exists: \(FileManager.default.fileExists(atPath: sourceURL.path))")

            // Create destination directory if needed
            try createDirectory(at: destinationURL, withIntermediateDirectories: true)

            print("FileManager+Zip: Attempting to unzip...")
            try Zip.unzipFile(sourceURL, destination: destinationURL, overwrite: true, password: nil, progress: { progress in
                print("FileManager+Zip: Extraction progress: \(Int(progress * 100))%")
            })

            print("FileManager+Zip: Extraction complete")
            print("FileManager+Zip: Destination contents: \(try contentsOfDirectory(atPath: destinationURL.path))")

        } catch {
            print("FileManager+Zip: Extraction failed with error: \(error)")
            print("FileManager+Zip: Error details:")
            print("  Description: \(error.localizedDescription)")
            throw error
        }
    }
}
