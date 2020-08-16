// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import BitByteData

/// Properties of LZMA. This API is intended to be used by advanced users.
public struct LZMAProperties {

    /// Number of bits used for the literal encoding context. Default value is 3.
    public var lc: Int = 3

    /// Number of bits to include in "literal position state". Default value is 0.
    public var lp: Int = 0

    /// Number of bits to include in "position state". Default value is 2.
    public var pb: Int = 2

    /**
     Size of the dictionary. Default value is 1 << 24.

     - Note: Dictionary size cannot be less than 4096. In case of attempt to set it to the value less than 4096 it will
     be automatically set to 4096 instead.
     */
    public var dictionarySize: Int = 1 << 24 {
        didSet {
            if dictionarySize < 1 << 12 {
                dictionarySize = 1 << 12
            }
        }
    }

    /**
     Initializes LZMA properties with values of lc, lp, pb, and dictionary size.

     - Note: It is not tested if values of lc, lp, and pb are valid.
     */
    public init(lc: Int, lp: Int, pb: Int, dictionarySize: Int) {
        self.lc = lc
        self.lp = lp
        self.pb = pb
        self.dictionarySize = dictionarySize
    }

    public init() { }

    init(lzmaByte: UInt8, _ dictSize: Int) throws {
        guard lzmaByte < 9 * 5 * 5
            else { throw LZMAError.wrongProperties }

        let intByte = lzmaByte.toInt()

        self.lc = intByte % 9
        self.pb = (intByte / 9) / 5
        self.lp = (intByte / 9) % 5

        self.dictionarySize = dictSize
    }

    init(_ byteReader: ByteReader) throws {
        try self.init(lzmaByte: byteReader.byte(), byteReader.int(fromBytes: 4))
    }

}
