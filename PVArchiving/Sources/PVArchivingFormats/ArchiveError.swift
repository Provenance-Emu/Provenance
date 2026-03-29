//
//  ArchiveError.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation

/// Consolidated error type for all archive operations.
public enum ArchiveError: Error, LocalizedError, Sendable {
    case invalidArchive
    case fileTooLarge(Int64)
    case extractionFailed(String)
    case compressionFailed(String)
    case formatNotSupported(ArchiveFormat)
    case backendUnavailable(String)
    case unknownCompressionMethod

    /// Thrown when some files in a batch extraction could not be moved.
    /// The archive and temp directory are preserved so the user can retry.
    case batchMoveFailed(succeeded: Int, total: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The archive file is invalid or in an unsupported format."
        case .fileTooLarge(let size):
            let mb = size / 1_000_000
            return "The archive file is too large to extract (\(mb) MB)."
        case .extractionFailed(let message):
            return message
        case .compressionFailed(let message):
            return message
        case .formatNotSupported(let format):
            return "Archive format '\(format.rawValue)' is not yet supported for extraction."
        case .backendUnavailable(let name):
            return "Archive backend '\(name)' is not available on this platform."
        case .unknownCompressionMethod:
            return "Unknown compression method."
        case .batchMoveFailed(let succeeded, let total):
            let failed = total - succeeded
            return "Failed to move \(failed) of \(total) extracted file(s) to the import directory. "
                + "The archive and extracted files have been preserved for retry."
        }
    }
}
