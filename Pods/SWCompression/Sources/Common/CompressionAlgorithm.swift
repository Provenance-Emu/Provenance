// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// A type that provides an implementation of a particular compression algorithm.
public protocol CompressionAlgorithm {

    /// Compress data with particular algorithm.
    static func compress(data: Data) throws -> Data

}
