// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

final class LZMADecoder {

    private let byteReader: ByteReader

    var properties = LZMAProperties()

    var uncompressedSize = -1

    /// An array for storing output data.
    var out = [UInt8]()

    // `out` array also serves as dictionary and out window.
    private var dictStart = 0
    private var dictEnd = 0

    private var dictSize: Int {
        return self.properties.dictionarySize
    }

    private var lc: Int {
        return self.properties.lc
    }

    private var lp: Int {
        return self.properties.lp
    }

    private var pb: Int {
        return self.properties.pb
    }

    private var rangeDecoder = LZMARangeDecoder()
    private var posSlotDecoder  = [LZMABitTreeDecoder]()
    private var alignDecoder = LZMABitTreeDecoder(numBits: LZMAConstants.numAlignBits)
    private var lenDecoder = LZMALenDecoder()
    private var repLenDecoder = LZMALenDecoder()

    /**
     For literal decoding we need `1 << (lc + lp)` amount of tables.
     Each table contains 0x300 probabilities.
     */
    private var literalProbs = [[Int]]()

    /**
     Array with all probabilities:

     - 0..<192: isMatch
     - 193..<205: isRep
     - 205..<217: isRepG0
     - 217..<229: isRepG1
     - 229..<241: isRepG2
     - 241..<433: isRep0Long
     */
    private var probabilities = [Int]()

    private var posDecoders = [Int]()

    // 'Distance history table'.
    private var rep0 = 0
    private var rep1 = 0
    private var rep2 = 0
    private var rep3 = 0

    /// Used to select exact variable from 'IsRep', 'IsRepG0', 'IsRepG1' and 'IsRepG2' arrays.
    private var state = 0

    init(_ byteReader: ByteReader) {
        self.byteReader = byteReader
    }

    /**
     Resets state properties and various sub-decoders of LZMA decoder.
     */
    func resetStateAndDecoders() {
        self.state = 0

        self.rep0 = 0
        self.rep1 = 0
        self.rep2 = 0
        self.rep3 = 0

        self.probabilities = Array(repeating: LZMAConstants.probInitValue, count: 2 * 192 + 4 * 12)
        self.literalProbs = Array(repeating: Array(repeating: LZMAConstants.probInitValue, count: 0x300),
                                  count: 1 << (lc + lp))

        self.posSlotDecoder = []
        for _ in 0..<LZMAConstants.numLenToPosStates {
            self.posSlotDecoder.append(LZMABitTreeDecoder(numBits: 6))
        }
        self.alignDecoder = LZMABitTreeDecoder(numBits: LZMAConstants.numAlignBits)
        self.posDecoders = Array(repeating: LZMAConstants.probInitValue,
                                 count: 1 + LZMAConstants.numFullDistances - LZMAConstants.endPosModelIndex)
        self.lenDecoder = LZMALenDecoder()
        self.repLenDecoder = LZMALenDecoder()
    }

    func resetDictionary() {
        self.dictStart = self.dictEnd
    }

    /// Main LZMA (algorithm) decoder function.
    func decode() throws {
        // First, we need to initialize Rande Decoder.
        guard let rD = LZMARangeDecoder(byteReader)
            else { throw LZMAError.rangeDecoderInitError }
        self.rangeDecoder = rD

        // Main decoding cycle.
        while true {
            // If uncompressed size was defined and everything is unpacked then stop.
            if uncompressedSize == 0 {
                if rangeDecoder.isFinishedOK {
                    break
                }
            }

            let posState = out.count & ((1 << pb) - 1)
            if rangeDecoder.decode(bitWithProb:
                &probabilities[(state << LZMAConstants.numPosBitsMax) + posState]) == 0 {
                if uncompressedSize == 0 {
                    throw LZMAError.exceededUncompressedSize
                }

                // DECODE LITERAL:
                /// Previous literal (zero, if there was none).
                let prevByte = dictEnd == 0 ? 0 : self.byte(at: 1).toInt()
                /// Decoded symbol. Initial value is 1.
                var symbol = 1
                /**
                 Index of table with literal probabilities. It is based on the context which consists of:
                 - `lc` high bits of from previous literal.
                 If there were none, i.e. it is the first literal, then this part is skipped.
                 - `lp` low bits from current position in output.
                 */
                let litState = ((out.count & ((1 << lp) - 1)) << lc) + (prevByte >> (8 - lc))
                // If state is greater than 7 we need to do additional decoding with 'matchByte'.
                if state >= 7 {
                    /**
                     Byte in output at position that is the `distance` bytes before current position,
                     where the `distance` is the distance from the latest decoded match.
                     */
                    var matchByte = self.byte(at: rep0 + 1)
                    repeat {
                        let matchBit = ((matchByte >> 7) & 1).toInt()
                        matchByte <<= 1
                        let bit = rangeDecoder.decode(bitWithProb:
                            &literalProbs[litState][((1 + matchBit) << 8) + symbol])
                        symbol = (symbol << 1) | bit
                        if matchBit != bit {
                            break
                        }
                    } while symbol < 0x100
                }
                while symbol < 0x100 {
                    symbol = (symbol << 1) | rangeDecoder.decode(bitWithProb: &literalProbs[litState][symbol])
                }
                let byte = (symbol - 0x100).toUInt8()
                uncompressedSize -= 1
                self.put(byte)
                // END.

                // Finally, we need to update `state`.
                if state < 4 {
                    state = 0
                } else if state < 10 {
                    state -= 3
                } else {
                    state -= 6
                }

                continue
            }

            var len: Int
            if rangeDecoder.decode(bitWithProb: &probabilities[193 + state]) != 0 {
                // REP MATCH CASE
                if uncompressedSize == 0 {
                    throw LZMAError.exceededUncompressedSize
                }
                if dictEnd == 0 {
                    throw LZMAError.windowIsEmpty
                }
                if rangeDecoder.decode(bitWithProb: &probabilities[205 + state]) == 0 {
                    // (We use last distance from 'distance history table').
                    if rangeDecoder.decode(bitWithProb:
                        &probabilities[241 + (state << LZMAConstants.numPosBitsMax) + posState]) == 0 {
                        // SHORT REP MATCH CASE
                        state = state < 7 ? 9 : 11
                        let byte = self.byte(at: rep0 + 1)
                        self.put(byte)
                        uncompressedSize -= 1
                        continue
                    }
                } else { // REP MATCH CASE
                    // (It means that we use distance from 'distance history table').
                    // So the following code selectes one distance from history...
                    // based on the binary data.
                    let dist: Int
                    if rangeDecoder.decode(bitWithProb: &probabilities[217 + state]) == 0 {
                        dist = rep1
                    } else {
                        if rangeDecoder.decode(bitWithProb: &probabilities[229 + state]) == 0 {
                            dist = rep2
                        } else {
                            dist = rep3
                            rep3 = rep2
                        }
                        rep2 = rep1
                    }
                    rep1 = rep0
                    rep0 = dist
                }
                len = repLenDecoder.decode(with: rangeDecoder, posState: posState)
                state = state < 7 ? 8 : 11
            } else { // SIMPLE MATCH CASE
                // First, we need to move history of distance values.
                rep3 = rep2
                rep2 = rep1
                rep1 = rep0
                len = lenDecoder.decode(with: rangeDecoder, posState: posState)
                state = state < 7 ? 7 : 10

                // DECODE DISTANCE:
                /// Is used to define context for distance decoding.
                var lenState = len
                if lenState > LZMAConstants.numLenToPosStates - 1 {
                    lenState = LZMAConstants.numLenToPosStates - 1
                }

                /// Defines decoding scheme for distance value.
                let posSlot = posSlotDecoder[lenState].decode(with: rangeDecoder)
                if posSlot < 4 {
                    // If `posSlot` is less than 4 then distance has defined value (no need to decode).
                    // And distance is actually equal to `posSlot`.
                    rep0 = posSlot
                } else {
                    let numDirectBits = (posSlot >> 1) - 1
                    var dist = (2 | (posSlot & 1)) << numDirectBits
                    if posSlot < LZMAConstants.endPosModelIndex {
                        // In this case we need a sequence of bits decoded with bit tree...
                        // ...(separate trees for different `posSlot` values)...
                        // ...and 'Reverse' scheme to get distance value.
                        dist += LZMABitTreeDecoder.bitTreeReverseDecode(probs: &posDecoders,
                                                                        startIndex: dist - posSlot,
                                                                        bits: numDirectBits, rangeDecoder)
                    } else {
                        // Middle bits of distance are decoded as direct bits from RangeDecoder.
                        dist += rangeDecoder.decode(directBits: (numDirectBits - LZMAConstants.numAlignBits))
                            << LZMAConstants.numAlignBits
                        // Low 4 bits are decoded with a bit tree decoder (called 'AlignDecoder')...
                        // ...with "Reverse" scheme.
                        dist += alignDecoder.reverseDecode(with: rangeDecoder)
                    }
                    rep0 = dist
                }
                // END.

                // Check if finish marker is encountered.
                // Distance value of 2^32 is used to indicate 'End of Stream' marker.
                if UInt32(rep0) == 0xFFFFFFFF {
                    guard rangeDecoder.isFinishedOK
                        else { throw LZMAError.rangeDecoderFinishError }
                    break
                }

                if uncompressedSize == 0 {
                    throw LZMAError.exceededUncompressedSize
                }
                if rep0 >= dictSize || (rep0 > dictEnd && dictEnd < dictSize) {
                    throw LZMAError.notEnoughToRepeat
                }
            }
            // Converting from zero-based length of the match to the real one.
            len += LZMAConstants.matchMinLen
            if uncompressedSize > -1 && uncompressedSize < len {
                throw LZMAError.repeatWillExceed
            }
            for _ in 0..<len {
                let byte = self.byte(at: rep0 + 1)
                self.put(byte)
                uncompressedSize -= 1
            }
        }
    }

    // MARK: Dictionary (out window) related functions.

    func put(_ byte: UInt8) {
        out.append(byte)
        dictEnd += 1
        if dictEnd - dictStart == dictSize {
            dictStart += 1
        }
    }

    private func byte(at distance: Int) -> UInt8 {
        return out[distance <= dictEnd ? dictEnd - distance : dictSize - distance + dictEnd]
    }

}
