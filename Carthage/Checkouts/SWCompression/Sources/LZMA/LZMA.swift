// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides decompression function for LZMA.
public class LZMA: DecompressionAlgorithm {

    /**
     Decompresses `data` using LZMA.

     - Note: It is assumed that the first nine bytes of `data` represent standard LZMA properties (so called "lc", "lp"
     and "pb"), dictionary size, and uncompressed size all encoded with standard encoding scheme of LZMA format.

     - Parameter data: Data compressed with LZMA.

     - Throws: `LZMAError` if unexpected byte (bit) sequence was encountered in `data`. It may indicate that either data
     is damaged or it might not be compressed with LZMA at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data) throws -> Data {
        let byteReader = ByteReader(data: data)
        let properties = try LZMAProperties(byteReader)
        let uncompSize = byteReader.int(fromBytes: 8)
        return try decompress(byteReader, properties, uncompSize)
    }

    /**
     Decompresses `data` using LZMA with specified algorithm's `properties`, and, optionally, output's
     `uncompressedSize`. If `uncompressedSize` is nil, then `data` must contain finish marker.

     - Note: It is assumed that `data` begins immediately with LZMA compressed bytes with no LZMA properties at the
     beginning.

     - Warning: There is no validation performed for properties of `properties` argument. This API is intended to be
     used by advanced users.

     - Parameter data: Data compressed with LZMA.
     - Parameter properties: Properties of LZMA (such as lc, lp, etc.)
     - Parameter uncompressedSize: Size of uncompressed data; `nil` if it is unknown. In case of `nil`, finish marker
     must be present in `data`.

     - Throws: `LZMAError` if unexpected byte (bit) sequence was encountered in `data`. It may indicate that either data
     is damaged or it might not be compressed with LZMA at all.

     - Returns: Decompressed data.
     */
    public static func decompress(data: Data,
                                  properties: LZMAProperties,
                                  uncompressedSize: Int? = nil) throws -> Data {
        let byteReader = ByteReader(data: data)
        return try decompress(byteReader, properties, uncompressedSize)
    }

    static func decompress(_ byteReader: ByteReader,
                           _ properties: LZMAProperties,
                           _ uncompSize: Int?) throws -> Data {
        let decoder = LZMADecoder(byteReader)
        decoder.properties = properties
        decoder.resetStateAndDecoders()
        decoder.uncompressedSize = uncompSize ?? -1

        try decoder.decode()
        return Data(bytes: decoder.out)
    }

}
