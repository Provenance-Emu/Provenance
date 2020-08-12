// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that provides an implementation of a particular decompression algorithm.
public protocol DecompressionAlgorithm {

    /// Decompress data compressed with particular algorithm.
    static func decompress(data: Data) throws -> Data

}
