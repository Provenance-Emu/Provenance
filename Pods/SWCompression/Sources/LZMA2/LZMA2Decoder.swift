// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

final class LZMA2Decoder {

    private let byteReader: ByteReader
    private let decoder: LZMADecoder

    var out: [UInt8] {
        return self.decoder.out
    }

    init(_ byteReader: ByteReader, _ dictSizeByte: UInt8) throws {
        self.byteReader = byteReader
        self.decoder = LZMADecoder(byteReader)

        guard dictSizeByte & 0xC0 == 0
            else { throw LZMA2Error.wrongDictionarySize }
        let bits = (dictSizeByte & 0x3F).toInt()
        guard bits < 40
            else { throw LZMA2Error.wrongDictionarySize }

        let dictSize = bits == 40 ? UInt32.max :
            (UInt32(truncatingIfNeeded: 2 | (bits & 1)) << UInt32(truncatingIfNeeded: bits / 2 + 11))

        self.decoder.properties.dictionarySize = dictSize.toInt()
    }

    /// Main LZMA2 decoder function.
    func decode() throws {
        mainLoop: while true {
            let controlByte = byteReader.byte()
            switch controlByte {
            case 0:
                break mainLoop
            case 1:
                self.decoder.resetDictionary()
                self.decodeUncompressed()
            case 2:
                self.decodeUncompressed()
            case 3...0x7F:
                throw LZMA2Error.wrongControlByte
            case 0x80...0xFF:
                try self.dispatch(controlByte)
            default:
                fatalError("Incorrect control byte.") // This statement is never executed.
            }
        }
    }

    /// Function which dispatches LZMA2 decoding process based on `controlByte`.
    private func dispatch(_ controlByte: UInt8) throws {
        let uncompressedSizeBits = controlByte & 0x1F
        let reset = (controlByte & 0x60) >> 5
        let unpackSize = (uncompressedSizeBits.toInt() << 16) +
            self.byteReader.byte().toInt() << 8 + self.byteReader.byte().toInt() + 1
        let compressedSize = self.byteReader.byte().toInt() << 8 + self.byteReader.byte().toInt() + 1
        switch reset {
        case 0:
            break
        case 1:
            self.decoder.resetStateAndDecoders()
        case 2:
            try self.updateProperties()
        case 3:
            try self.updateProperties()
            self.decoder.resetDictionary()
        default:
            throw LZMA2Error.wrongReset
        }
        self.decoder.uncompressedSize = unpackSize
        let outStartIndex = self.decoder.out.count
        let inStartIndex = self.byteReader.offset
        try self.decoder.decode()
        guard unpackSize == self.decoder.out.count - outStartIndex &&
            self.byteReader.offset - inStartIndex == compressedSize
            else { throw LZMA2Error.wrongSizes }
    }

    private func decodeUncompressed() {
        let dataSize = self.byteReader.byte().toInt() << 8 + self.byteReader.byte().toInt() + 1
        for _ in 0..<dataSize {
            self.decoder.put(self.byteReader.byte())
        }
    }

    /**
     Sets `lc`, `pb` and `lp` properties of LZMA decoder with a single `byte` using standard LZMA properties encoding
     scheme and resets decoder's state and sub-decoders.
     */
    private func updateProperties() throws {
        self.decoder.properties = try LZMAProperties(lzmaByte: byteReader.byte(),
                                                     self.decoder.properties.dictionarySize)
        self.decoder.resetStateAndDecoders()
    }

}
