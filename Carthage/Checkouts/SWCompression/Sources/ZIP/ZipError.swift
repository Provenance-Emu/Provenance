// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error, which happened during processing ZIP container.
 It may indicate that either container is damaged or it might not be ZIP container at all.
 */
public enum ZipError: Error {
    /// End of Central Directoty record wasn't found.
    case notFoundCentralDirectoryEnd
    /// Wrong signature of one of container's structures.
    case wrongSignature
    /// Wrong either compressed or uncompressed size of a container's entry.
    case wrongSize
    /// Version needed to process container is unsupported.
    case wrongVersion
    /// Container is either spanned or consists of several volumes. These features aren't supported.
    case multiVolumesNotSupported
    /// Entry or record is encrypted. This feature isn't supported.
    case encryptionNotSupported
    /// Entry contains patched data. This feature isn't supported.
    case patchingNotSupported
    /// Entry is compressed using unsupported compression method.
    case compressionNotSupported
    /// Local header of an entry is inconsistent with Central Directory.
    case wrongLocalHeader
    /**
     Computed checksum of entry's data doesn't match the value stored in the archive.
     Associated value of the error contains `ZipEntry` objects for all already processed entries:
     */
    case wrongCRC([ZipEntry])
    /// Either entry's comment or file name cannot be processed using UTF-8 encoding.
    case wrongTextField
}
