// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error, which happened during processing 7-Zip container.
 It may indicate that either container is damaged or it might not be 7-Zip container at all.
 */
public enum SevenZipError: Error {
    /// Wrong container's signature.
    case wrongSignature
    /// Unsupported version of container's format.
    case wrongFormatVersion
    /// CRC either of one of the files from the container or one of the container's strucutures is incorrect.
    case wrongCRC
    /// Size either of one of the files from the container or one of the container's strucutures is incorrect.
    case wrongSize
    /// Files have StartPos property. This feature isn't supported.
    case startPosNotSupported
    /// External feature isn't supported.
    case externalNotSupported
    /// Coders with multiple in and/or out streams aren't supported.
    case multiStreamNotSupported
    /// Additional streams feature isn't supported.
    case additionalStreamsNotSupported
    /// Entry is compressed using unsupported compression method.
    case compressionNotSupported
    /// Entry or container's header is encrypted. This feature isn't supported.
    case encryptionNotSupported
    /// Unknown/incorrect internal 7-Zip structure was encountered or a required internal structure is missing.
    case internalStructureError
}
