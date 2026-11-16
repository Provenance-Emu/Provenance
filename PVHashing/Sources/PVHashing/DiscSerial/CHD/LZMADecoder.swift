//
//  LZMADecoder.swift
//  PVHashing
//
//  A raw LZMA1 decoder, written from the public-domain LZMA specification.
//
//  CHD stores each LZMA hunk as a bare range-coder stream: no properties byte,
//  no dictionary size, no end marker. The properties are fixed by chdman
//  (lc 3, lp 0, pb 2) and the output size is the hunk's size, so the decoder
//  takes both from its caller and uses the output buffer as its dictionary.
//

import Foundation

enum LZMADecoder {

    /// chdman's literal context, literal position and position bits.
    struct Properties {
        let lc: Int
        let lp: Int
        let pb: Int
        static let chd = Properties(lc: 3, lp: 0, pb: 2)
    }

    /// Decodes exactly `size` bytes from `source`, or returns nil when the stream is
    /// corrupt or ends early.
    static func decode(_ source: Data, size: Int, properties: Properties = .chd) -> Data? {
        guard size >= 0, source.count >= Range.headerBytes else { return nil }
        var decoder = Decoder(input: [UInt8](source), size: size, properties: properties)
        guard decoder.run() else { return nil }
        return Data(decoder.output)
    }

    // MARK: Layout of the probability table

    private enum Model {
        static let states = 12
        static let positionStatesMax = 16
        static let lengthToPositionStates = 4
        static let endPositionModelIndex = 14
        static let fullDistances = 128
        static let alignBits = 4
        static let matchMinimumLength = 2
        static let initialProbability: UInt16 = 1024

        // Offsets into one flat table. Each block is sized for the largest model.
        static let isMatch = 0
        static let isRep = isMatch + states * positionStatesMax
        static let isRepG0 = isRep + states
        static let isRepG1 = isRepG0 + states
        static let isRepG2 = isRepG1 + states
        static let isRep0Long = isRepG2 + states
        static let positionSlot = isRep0Long + states * positionStatesMax
        static let positionSpecial = positionSlot + lengthToPositionStates * 64
        static let align = positionSpecial + 1 + fullDistances - endPositionModelIndex
        static let length = align + (1 << alignBits)
        static let repLength = length + lengthCoderSize
        static let literal = repLength + lengthCoderSize

        /// choice, choice2, 16 low trees of 8, 16 mid trees of 8, one high tree of 256.
        static let lengthCoderSize = 2 + positionStatesMax * 8 * 2 + 256
        static let lengthLow = 2
        static let lengthMid = lengthLow + positionStatesMax * 8
        static let lengthHigh = lengthMid + positionStatesMax * 8
    }

    private enum Range {
        static let headerBytes = 5
        static let topValue: UInt32 = 1 << 24
        static let modelBits: UInt32 = 11
        static let moveBits: UInt16 = 5
    }

    private struct Decoder {
        let input: [UInt8]
        let size: Int
        let properties: Properties
        var output: [UInt8]
        var written = 0
        var position = 0
        var range: UInt32 = 0xFFFF_FFFF
        var code: UInt32 = 0
        var probabilities: [UInt16]

        init(input: [UInt8], size: Int, properties: Properties) {
            self.input = input
            self.size = size
            self.properties = properties
            output = [UInt8](repeating: 0, count: size)
            let literals = 0x300 << (properties.lc + properties.lp)
            probabilities = [UInt16](repeating: Model.initialProbability, count: Model.literal + literals)
        }

        // MARK: Range decoder

        /// Bytes past the end read as zero; a stream that needs them fails the size check.
        private mutating func nextByte() -> UInt32 {
            defer { position += 1 }
            return position < input.count ? UInt32(input[position]) : 0
        }

        private mutating func normalize() {
            if range < Range.topValue {
                range <<= 8
                code = (code << 8) | nextByte()
            }
        }

        private mutating func bit(_ index: Int) -> Int {
            let probability = probabilities[index]
            let bound = (range >> Range.modelBits) * UInt32(probability)
            let symbol: Int
            if code < bound {
                probabilities[index] = probability + ((2048 - probability) >> Range.moveBits)
                range = bound
                symbol = 0
            } else {
                probabilities[index] = probability - (probability >> Range.moveBits)
                code -= bound
                range -= bound
                symbol = 1
            }
            normalize()
            return symbol
        }

        private mutating func directBits(_ count: Int) -> UInt32 {
            var result: UInt32 = 0
            for _ in 0..<count {
                range >>= 1
                code = code &- range
                let mask = 0 &- (code >> 31)
                code = code &+ (range & mask)
                normalize()
                result = (result << 1) &+ (mask &+ 1)
            }
            return result
        }

        private mutating func tree(_ base: Int, bits: Int) -> Int {
            var node = 1
            for _ in 0..<bits {
                node = (node << 1) + bit(base + node)
            }
            return node - (1 << bits)
        }

        private mutating func reverseTree(_ base: Int, bits: Int) -> Int {
            var node = 1
            var symbol = 0
            for index in 0..<bits {
                let value = bit(base + node)
                node = (node << 1) + value
                symbol |= value << index
            }
            return symbol
        }

        // MARK: Symbols

        private mutating func length(_ base: Int, positionState: Int) -> Int {
            if bit(base) == 0 {
                return tree(base + Model.lengthLow + positionState * 8, bits: 3)
            }
            if bit(base + 1) == 0 {
                return 8 + tree(base + Model.lengthMid + positionState * 8, bits: 3)
            }
            return 16 + tree(base + Model.lengthHigh, bits: 8)
        }

        private mutating func distance(forLength length: Int) -> UInt32 {
            let lengthState = min(length, Model.lengthToPositionStates - 1)
            let slot = tree(Model.positionSlot + lengthState * 64, bits: 6)
            guard slot >= 4 else { return UInt32(slot) }
            let directBitCount = (slot >> 1) - 1
            var distance = UInt32(2 | (slot & 1)) << UInt32(directBitCount)
            if slot < Model.endPositionModelIndex {
                distance += UInt32(reverseTree(Model.positionSpecial + Int(distance) - slot, bits: directBitCount))
            } else {
                distance = distance &+ (directBits(directBitCount - Model.alignBits) << UInt32(Model.alignBits))
                distance = distance &+ UInt32(reverseTree(Model.align, bits: Model.alignBits))
            }
            return distance
        }

        private mutating func literal(state: Int, rep0: Int) -> Bool {
            let previous = written > 0 ? Int(output[written - 1]) : 0
            let positionMask = (1 << properties.lp) - 1
            let context = ((written & positionMask) << properties.lc) + (previous >> (8 - properties.lc))
            let base = Model.literal + 0x300 * context
            var symbol = 1
            if state >= 7 {
                guard rep0 < written else { return false }
                var matchByte = Int(output[written - rep0 - 1])
                repeat {
                    let matchBit = (matchByte >> 7) & 1
                    matchByte <<= 1
                    let value = bit(base + ((1 + matchBit) << 8) + symbol)
                    symbol = (symbol << 1) | value
                    if matchBit != value { break }
                } while symbol < 0x100
            }
            while symbol < 0x100 {
                symbol = (symbol << 1) | bit(base + symbol)
            }
            output[written] = UInt8(truncatingIfNeeded: symbol)
            written += 1
            return true
        }

        // MARK: Main loop

        mutating func run() -> Bool {
            let first = nextByte()
            for _ in 0..<4 {
                code = (code << 8) | nextByte()
            }
            guard first == 0, code != range else { return false }

            var rep0 = 0, rep1 = 0, rep2 = 0, rep3 = 0
            var state = 0
            let positionMask = (1 << properties.pb) - 1

            while written < size {
                let positionState = written & positionMask
                if bit(Model.isMatch + state * Model.positionStatesMax + positionState) == 0 {
                    guard literal(state: state, rep0: rep0) else { return false }
                    state = state < 4 ? 0 : (state < 10 ? state - 3 : state - 6)
                    continue
                }

                var matchLength: Int
                if bit(Model.isRep + state) != 0 {
                    guard written > 0 else { return false }
                    if bit(Model.isRepG0 + state) == 0 {
                        if bit(Model.isRep0Long + state * Model.positionStatesMax + positionState) == 0 {
                            guard rep0 < written else { return false }
                            state = state < 7 ? 9 : 11
                            output[written] = output[written - rep0 - 1]
                            written += 1
                            continue
                        }
                    } else {
                        let distance: Int
                        if bit(Model.isRepG1 + state) == 0 {
                            distance = rep1
                        } else {
                            if bit(Model.isRepG2 + state) == 0 {
                                distance = rep2
                            } else {
                                distance = rep3
                                rep3 = rep2
                            }
                            rep2 = rep1
                        }
                        rep1 = rep0
                        rep0 = distance
                    }
                    matchLength = length(Model.repLength, positionState: positionState)
                    state = state < 7 ? 8 : 11
                } else {
                    rep3 = rep2
                    rep2 = rep1
                    rep1 = rep0
                    matchLength = length(Model.length, positionState: positionState)
                    state = state < 7 ? 7 : 10
                    let decoded = distance(forLength: matchLength)
                    // chdman writes no end marker, so one before the hunk is full is corruption.
                    guard decoded != 0xFFFF_FFFF else { return false }
                    rep0 = Int(decoded)
                }

                matchLength += Model.matchMinimumLength
                guard rep0 < written, matchLength <= size - written else { return false }
                for _ in 0..<matchLength {
                    output[written] = output[written - rep0 - 1]
                    written += 1
                }
            }
            return true
        }
    }
}
