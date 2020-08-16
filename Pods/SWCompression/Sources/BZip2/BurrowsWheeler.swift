// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class BurrowsWheeler {

    static func transform(bytes: [Int]) -> ([Int], Int) {
        let doubleBytes = bytes + bytes
        let suffixArray = SuffixArray.make(from: doubleBytes, with: 256)
        var bwt = [Int]()
        bwt.reserveCapacity(bytes.count)
        var pointer = 0
        for i in 1..<suffixArray.count {
            if suffixArray[i] < bytes.count {
                if suffixArray[i] > 0 {
                    bwt.append(bytes[suffixArray[i] - 1])
                } else {
                    bwt.append(bytes.last!)
                }
            } else if suffixArray[i] == bytes.count {
                pointer = (i - 1) / 2
            }
        }
        return (bwt, pointer)
    }

    static func reverse(bytes: [UInt8], _ pointer: Int) -> [UInt8] {
        guard bytes.count > 0
            else { return [] }

        var counts = Array(repeating: 0, count: 256)
        for byte in bytes {
            counts[byte.toInt()] += 1
        }

        var base = Array(repeating: -1, count: 256)
        var sum = 0
        for byteType in 0..<256 {
            if counts[byteType] == 0 {
                continue
            } else {
                base[byteType] = sum
                sum += counts[byteType]
            }
        }

        var pointers = Array(repeating: -1, count: bytes.count)
        for (i, char) in bytes.enumerated() {
            pointers[base[char.toInt()]] = i
            base[char.toInt()] += 1
        }

        var resultBytes = [UInt8]()
        resultBytes.reserveCapacity(bytes.count)

        var end = pointer
        for _ in 0..<bytes.count {
            end = pointers[end]
            resultBytes.append(bytes[end])
        }
        return resultBytes
    }

}
