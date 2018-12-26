// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

/// Provides unarchive and archive functions for Zlib archives.
public class ZlibArchive: Archive {

    /**
     Unarchives Zlib archive.

     - Note: This function is specification compliant.

     - Parameter archive: Data archived with Zlib.

     - Throws: `DeflateError` or `ZlibError` depending on the type of the problem.
     It may indicate that either archive is damaged or it might not be archived with Zlib
     or compressed with Deflate at all.

     - Returns: Unarchived data.
     */
    public static func unarchive(archive data: Data) throws -> Data {
        /// Object with input data which supports convenient work with bit shifts.
        let bitReader = LsbBitReader(data: data)

        _ = try ZlibHeader(bitReader)

        let out = try Deflate.decompress(bitReader)
        bitReader.align()

        let adler32 = bitReader.uint32().byteSwapped
        guard CheckSums.adler32(out) == adler32
            else { throw ZlibError.wrongAdler32(out) }

        return out
    }

    /**
     Archives `data` into Zlib archive. Data will be also compressed with Deflate algorithm.
     It will also be specified in archive's header that the compressor used the slowest Deflate algorithm.

     - Note: This function is specification compliant.

     - Parameter data: Data to compress and archive.

     - Returns: Resulting archive's data.
     */
    public static func archive(data: Data) -> Data {
        let out: [UInt8] = [
            120, // CM (Compression Method) = 8 (DEFLATE), CINFO (Compression Info) = 7 (32K window size).
            218 // Flags: slowest algorithm, no preset dictionary.
        ]
        var outData = Data(bytes: out)
        outData.append(Deflate.compress(data: data))

        let adler32 = CheckSums.adler32(data)
        var adlerBytes = [UInt8]()
        for i in 0..<4 {
            adlerBytes.append(UInt8(truncatingIfNeeded: (adler32 & (0xFF << ((3 - i) * 8))) >> ((3 - i) * 8)))
        }
        outData.append(Data(bytes: adlerBytes))

        return outData
    }

}
