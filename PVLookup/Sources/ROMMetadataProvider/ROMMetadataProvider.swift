import Foundation
import PVLookupTypes
import PVSystems

public protocol ROMMetadataProvider {
    /// Search by MD5 hash
    func searchROM(byMD5 md5: String) async throws -> ROMMetadata?

    /// Search by filename
    func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]?

    /// Get system ID for ROM - Deprecated
//    @available(*, deprecated, message: "Use systemIdentifier(forRomMD5:or:) instead")
//    func system(forRomMD5 md5: String, or filename: String?) async throws -> Int?

    /// Get SystemIdentifier for ROM
    /// - Parameters:
    ///   - md5: MD5 hash of the ROM
    ///   - filename: Optional filename as fallback
    /// - Returns: SystemIdentifier if found
    func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier?
}

// Default implementation for backward compatibility
public extension ROMMetadataProvider {
    func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier? {
        if let systemID = try await system(forRomMD5: md5, or: filename) {
            return SystemIdentifier.fromOpenVGDBID(systemID)
        }
        return nil
    }

    func system(forRomMD5 md5: String, or filename: String?) async throws -> Int? {
        if let identifier = try await systemIdentifier(forRomMD5: md5, or: filename) {
            return identifier.openVGDBID
        }
        return nil
    }
}
