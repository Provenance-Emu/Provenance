// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents a (de)compression method.
public enum CompressionMethod {
    /// BZip2.
    case bzip2
    /// Copy (no compression).
    case copy
    /// Deflate.
    case deflate
    /// LZMA.
    case lzma
    /// LZMA 2.
    case lzma2
    /// Other/unknown method.
    case other
}
