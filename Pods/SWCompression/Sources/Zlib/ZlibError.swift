// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error which happened while processing a Zlib archive.
 It may indicate that either archive is damaged or it might not be Zlib archive at all.
 */
public enum ZlibError: Error {
    /// Compression method used in archive is different from Deflate, which is the only supported one.
    case wrongCompressionMethod
    /// Compression info has value incompatible with Deflate compression method.
    case wrongCompressionInfo
    /// First two bytes of archive's flags are inconsistent with each other.
    case wrongFcheck
    /// Compression level has value, which is different from the supported ones.
    case wrongCompressionLevel
    /**
     Computed checksum of uncompressed data doesn't match the value stored in archive.
     Associated value of the error contains already decompressed data.
     */
    case wrongAdler32(Data)
}
