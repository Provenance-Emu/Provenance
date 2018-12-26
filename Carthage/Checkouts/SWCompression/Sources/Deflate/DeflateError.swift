// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error, which happened during Deflate compression or decompression.
 It may indicate that either the data is damaged or it might not be compressed with Deflate at all.
 */
public enum DeflateError: Error {
    /// Uncompressed block's `length` and `nlength` bytes isn't consistent with each other.
    case wrongUncompressedBlockLengths
    /// Unknown block type (not 0, 1 or 2).
    case wrongBlockType
    /// Decoded symbol was found in Huffman tree but is unknown.
    case wrongSymbol
    /// Symbol wasn't found in Huffman tree.
    case symbolNotFound
}
