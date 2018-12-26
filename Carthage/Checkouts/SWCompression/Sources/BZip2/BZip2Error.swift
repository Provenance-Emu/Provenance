// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error, which happened during BZip2 decompression.
 It may indicate that either data is damaged or it might not be compressed with BZip2 at all.
 */
public enum BZip2Error: Error {
    /// 'Magic' number is not 0x425a.
    case wrongMagic
    /// BZip version is not 2.
    case wrongVersion
    /// Unsupported block size (not from '0' to '9').
    case wrongBlockSize
    /// Unsupported block type (is neither 'pi' nor 'sqrt(pi)').
    case wrongBlockType
    /// Block is randomized.
    case randomizedBlock
    /// Wrong number of Huffman tables/groups (should be between 2 and 6).
    case wrongHuffmanGroups
    /// Selector is greater than the total number of Huffman tables/groups.
    case wrongSelector
    /// Wrong length of Huffman code (should be between 0 and 20).
    case wrongHuffmanCodeLength
    /// Symbol wasn't found in Huffman tree.
    case symbolNotFound
    /**
     Computed checksum of uncompressed data doesn't match the value stored in archive.
     Associated value of the error contains already decompressed data.
     */
    case wrongCRC(Data)
}
