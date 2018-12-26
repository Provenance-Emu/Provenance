// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides decompression function for LZMA2 algorithm.
public class LZMA2: DecompressionAlgorithm {

    /**
     Decompresses `data` using LZMA2 algortihm.

     - Note: It is assumed that the first byte of `data` is a dictionary size encoded with standard encoding scheme of
     LZMA2 format.

     - Parameter data: Data compressed with LZMA2.

     - Throws: `LZMAError` or `LZMA2Error` if unexpected byte (bit) sequence was encountered in `data`.
     It may indicate that either data is damaged or it might not be compressed with LZMA2 at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data) throws -> Data {
        let byteReader = ByteReader(data: data)
        return try decompress(byteReader, byteReader.byte())
    }

    static func decompress(_ byteReader: ByteReader, _ dictSizeByte: UInt8) throws -> Data {
        let decoder = try LZMA2Decoder(byteReader, dictSizeByte)
        try decoder.decode()
        return Data(bytes: decoder.out)
    }

}
