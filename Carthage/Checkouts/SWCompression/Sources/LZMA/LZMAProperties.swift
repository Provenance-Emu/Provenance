// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import BitByteData

/// Properties of LZMA. This API is intended to be used by advanced users.
public struct LZMAProperties {

    /// Number of bits used for the literal encoding context.
    public var lc: Int

    /// Number of bits to include in "literal position state".
    public var lp: Int

    /// Number of bits to include in "position state".
    public var pb: Int

    /**
     Size of the dictionary.

     - Note: Dictionary size cannot be less than 4096. In case of attempt to set it to the value less than 4096 it will
     be automatically set to 4096 instead.
     */
    public var dictionarySize: Int {
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

    init() {
        self.lc = 0
        self.lp = 0
        self.pb = 0
        self.dictionarySize = 0
    }

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
