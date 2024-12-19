import Foundation
import ZIPFoundation
import PVLogging

public extension FileManager {
    /// Extracts a zip file to a destination directory
    /// - Parameters:
    ///   - sourceURL: URL of the zip file
    ///   - destinationURL: URL of the directory to extract to
    func zipItem(at sourceURL: URL, unzipTo destinationURL: URL) throws {
        do {
            DLOG("FileManager+Zip: Starting extraction...")
            DLOG("FileManager+Zip: Source file exists: \(FileManager.default.fileExists(atPath: sourceURL.path))")

            // Create destination directory if needed
            try createDirectory(at: destinationURL, withIntermediateDirectories: true)

            DLOG("FileManager+Zip: Attempting to unzip...")
            try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)

            #if DEBUG || TRACE_LOGGING
            DLOG("FileManager+Zip: Extraction complete")
            print("FileManager+Zip: Destination contents: \(try contentsOfDirectory(atPath: destinationURL.path))")
            #endif

        } catch {
            DLOG("FileManager+Zip: Extraction failed with error: \(error)")
            DLOG("FileManager+Zip: Error details:")
            DLOG("  Description: \(error.localizedDescription)")
            throw error
        }
    }
}
