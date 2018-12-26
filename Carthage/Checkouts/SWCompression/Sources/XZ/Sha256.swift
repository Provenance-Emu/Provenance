// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

infix operator >>>

@inline(__always)
private func >>> (num: UInt32, count: Int) -> UInt32 {
    // This implementation assumes without checking that `count` is in the 1...31 range.
    return (num >> UInt32(truncatingIfNeeded: count)) | (num << UInt32(truncatingIfNeeded: 32 - count))
}

struct Sha256 {

    private static let k: [UInt32] =
        [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98,
         0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
         0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8,
         0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
         0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819,
         0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
         0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
         0xc67178f2]

    static func hash(data: Data) -> [UInt8] {
        var h0 = 0x6a09e667 as UInt32
        var h1 = 0xbb67ae85 as UInt32
        var h2 = 0x3c6ef372 as UInt32
        var h3 = 0xa54ff53a as UInt32
        var h4 = 0x510e527f as UInt32
        var h5 = 0x9b05688c as UInt32
        var h6 = 0x1f83d9ab as UInt32
        var h7 = 0x5be0cd19 as UInt32

        // Padding
        var bytes = data.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: data.count / MemoryLayout<UInt8>.size))
        }

        let originalLength = bytes.count
        var newLength = originalLength * 8 + 1
        while newLength % 512 != 448 {
            newLength += 1
        }
        newLength /= 8

        bytes.append(0x80)
        for _ in 0..<(newLength - originalLength - 1) {
            bytes.append(0x00)
        }

        // Length
        let bitsLength = UInt64(truncatingIfNeeded: originalLength * 8)
        for i: UInt64 in 0..<8 {
            bytes.append(UInt8(truncatingIfNeeded: (bitsLength & 0xFF << ((7 - i) * 8)) >> ((7 - i) * 8)))
        }

        for i in stride(from: 0, to: bytes.count, by: 64) {
            var w = Array(repeating: 0 as UInt32, count: 64)

            for j in 0..<16 {
                var word = 0 as UInt32
                for k: UInt32 in 0..<4 {
                    word += UInt32(truncatingIfNeeded: bytes[i + j * 4 + k.toInt()]) << ((3 - k) * 8)
                }
                w[j] = word
            }

            for i in 16..<64 {
                let s0 = (w[i - 15] >>> 7) ^ (w[i - 15] >>> 18) ^ (w[i - 15] >> 3)
                let s1 = (w[i - 2] >>> 17) ^ (w[i - 2] >>> 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }

            var a = h0
            var b = h1
            var c = h2
            var d = h3
            var e = h4
            var f = h5
            var g = h6
            var h = h7

            for i in 0..<64 {
                let s1 = (e >>> 6) ^ (e >>> 11) ^ (e >>> 25)
                let ch = (e & f) ^ ((~e) & g)
                let temp1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = (a >>> 2) ^ (a >>> 13) ^ (a >>> 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj

                h = g
                g = f
                f = e
                e = d &+ temp1
                d = c
                c = b
                b = a
                a = temp1 &+ temp2
            }

            h0 = h0 &+ a
            h1 = h1 &+ b
            h2 = h2 &+ c
            h3 = h3 &+ d
            h4 = h4 &+ e
            h5 = h5 &+ f
            h6 = h6 &+ g
            h7 = h7 &+ h
        }

        var result = [UInt8]()
        result.reserveCapacity(32)

        for i: UInt32 in 0..<4 {
            result.append(UInt8(truncatingIfNeeded: (h0 & 0xFF << ((3 - i) * 8)) >> ((3 - i) * 8)))
        }
        for i: UInt32 in 0..<4 {
            result.append(UInt8(truncatingIfNeeded: (h1 & 0xFF << ((3 - i) * 8)) >> ((3 - i) * 8)))
        }
        for i: UInt32 in 0..<4 {
            result.append(UInt8(truncatingIfNeeded: (h2 & 0xFF << ((3 - i) * 8)) >> ((3 - i) * 8)))
        }
        for i: UInt32 in 0..<4 {
            result.append(UInt8(truncatingIfNeeded: (h3 & 0xFF << ((3 - i) * 8)) >> ((3 - i) * 8)))
        }
        for i: UInt32 in 0..<4 {
            result.append(UInt8(truncatingIfNeeded: (h4 & 0xFF << ((3 - i) * 8)) >> ((3 - i) * 8)))
        }
        for i: UInt32 in 0..<4 {
            result.append(UInt8(truncatingIfNeeded: (h5 & 0xFF << ((3 - i) * 8)) >> ((3 - i) * 8)))
        }
        for i: UInt32 in 0..<4 {
            result.append(UInt8(truncatingIfNeeded: (h6 & 0xFF << ((3 - i) * 8)) >> ((3 - i) * 8)))
        }
        for i: UInt32 in 0..<4 {
            result.append(UInt8(truncatingIfNeeded: (h7 & 0xFF << ((3 - i) * 8)) >> ((3 - i) * 8)))
        }

        return result
    }

}
