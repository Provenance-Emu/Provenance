import Foundation
import PVLookupTypes
import PVSystems

public protocol ROMMetadataProvider {
    /// Search by MD5 hash
    func searchROM(byMD5 md5: String) async throws -> ROMMetadata?

    /// Search by filename
    func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]?

    /// Get SystemIdentifier for ROM
    /// - Parameters:
    ///   - md5: MD5 hash of the ROM
    ///   - filename: Optional filename as fallback
    /// - Returns: SystemIdentifier if found
    func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier?

    /// Search directly by MD5 hash with optional system filter
    /// - Parameters:
    ///   - md5: MD5 hash to search for
    ///   - systemID: Optional system ID to filter results
    /// - Returns: Array of ROM metadata matching the MD5, or nil if none found
    func searchByMD5(_ md5: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]?
}

// Helper methods for database providers
public extension ROMMetadataProvider {
    /// Sanitizes a string for safe use in SQL LIKE queries
    /// - Parameter string: The string to sanitize
    /// - Returns: A sanitized string safe for SQL LIKE queries
    func sanitizeForSQLLike(_ string: String) -> String {
        // First escape special LIKE characters
        let escapedLike = string
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "\\", with: "\\\\")  // Escape backslashes first
            .replacingOccurrences(of: "'", with: "''")     // SQL quotes
            .replacingOccurrences(of: "\"", with: "\\\"")  // Double quotes
            .replacingOccurrences(of: "(", with: "\\(")    // Parentheses
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: "[", with: "\\[")    // Square brackets
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "*", with: "\\*")    // Wildcards
            .replacingOccurrences(of: "?", with: "\\?")
            .replacingOccurrences(of: "#", with: "\\#")

        return escapedLike
    }

    /// Creates a SQL LIKE pattern for fuzzy matching
    /// - Parameter filename: The filename to create a pattern for
    /// - Returns: A sanitized SQL LIKE pattern
    func createSQLLikePattern(_ filename: String) -> String {
        let sanitized = sanitizeForSQLLike(filename)
        return "%\(sanitized)%"
    }
}

// Default implementation for backward compatibility
public extension ROMMetadataProvider {
    func searchByMD5(_ md5: String, systemID: SystemIdentifier? = nil) async throws -> [ROMMetadata]? {
        // Default implementation just wraps searchROM(byMD5:)
        if let result = try await searchROM(byMD5: md5) {
            return [result]
        }
        return nil
    }

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
