// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/**
 Represents an error which happened during LZMA decompression.
 It may indicate that either data is damaged or it might not be compressed with LZMA at all.
 */
public enum LZMAError: Error {
    /// Properties' byte is greater than 225.
    case wrongProperties
    /// Unable to initialize RanderDecorer.
    case rangeDecoderInitError
    /// Size of uncompressed data hit specified limit in the middle of decoding.
    case exceededUncompressedSize
    /// Unable to perfrom repeat-distance decoding because there is nothing to repeat.
    case windowIsEmpty
    /// End of stream marker is reached, but range decoder is in incorrect state.
    case rangeDecoderFinishError
    /// The number of bytes to repeat is greater than the amount bytes that is left to decode.
    case repeatWillExceed
    /// The amount of already decoded bytes is smaller than repeat length.
    case notEnoughToRepeat
}
