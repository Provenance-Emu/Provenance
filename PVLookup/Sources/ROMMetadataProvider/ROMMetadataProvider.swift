import Foundation
import PVLookupTypes

public protocol ROMMetadataProvider {
    /// Search by MD5 hash
    func searchROM(byMD5 md5: String) async throws -> ROMMetadata?

    /// Search by filename
    func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]?

    /// Get system ID for ROM
    func system(forRomMD5 md5: String, or filename: String?) async throws -> Int?
}
