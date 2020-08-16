// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Suffix Array by Induced Sorting
class SuffixArray {

    private enum SuffixType {
        case sType
        case lType
    }

    private struct State {

        let input: [Int]
        let typemap: [SuffixType]
        let bucketSizes: [Int]
        let bucketHeads: [Int]
        let bucketTails: [Int]

        init(bytes: [Int], alphabetSize: Int) {
            self.input = bytes

            var typemap = Array(repeating: SuffixType.lType, count: bytes.count + 1) // Extra one for empty suffix.
            var bucketSizes = Array(repeating: 0, count: alphabetSize)

            typemap[bytes.count] = .sType // The empty suffix is S type.

            if bytes.count != 0 {
                bucketSizes[bytes[bytes.count - 1]] += 1
                // The suffix containing only the last character must be "larger" than the empty suffix.
                typemap[bytes.count - 1] = .lType
            }

            for i in stride(from: bytes.count - 2, through: 0, by: -1) {
                if bytes[i] > bytes[i + 1] {
                    typemap[i] = .lType
                } else if bytes[i] == bytes[i + 1] && typemap[i + 1] == .lType {
                    typemap[i] = .lType
                } else {
                    typemap[i] = .sType
                }

                bucketSizes[bytes[i]] += 1
            }

            self.typemap = typemap
            self.bucketSizes = bucketSizes

            var bucketHeads = [Int]()
            bucketHeads.reserveCapacity(alphabetSize)
            var bucketTails = [Int]()
            bucketTails.reserveCapacity(alphabetSize)
            var offset = 1
            for size in bucketSizes {
                bucketHeads.append(offset)
                offset += size
                bucketTails.append(offset - 1)
            }

            self.bucketHeads = bucketHeads
            self.bucketTails = bucketTails
        }

    }

    private struct Summary {

        let bytes: [Int]
        let alphabetSize: Int
        let suffixOffsets: [Int]

        init(_ guessedSuffixArray: [Int], _ state: State) {
            var lmsNames = Array(repeating: -1, count: state.input.count + 1)
            var currentName = 0
            lmsNames[guessedSuffixArray[0]] = currentName
            var lastLMSSuffixOffset = guessedSuffixArray[0]

            for i in 1..<guessedSuffixArray.count {
                let suffixOffset = guessedSuffixArray[i]
                guard SuffixArray.isLMSChar(at: suffixOffset, state)
                    else { continue }

                if !SuffixArray.lmsSubstringsAreEqual(lastLMSSuffixOffset, suffixOffset, state) {
                    currentName += 1
                }

                lastLMSSuffixOffset = suffixOffset

                lmsNames[suffixOffset] = currentName
            }

            var summarySuffixOffsets = [Int]()
            var summaryBytes = [Int]()
            for (index, name) in lmsNames.enumerated() {
                guard name != -1
                    else { continue }
                summarySuffixOffsets.append(index)
                summaryBytes.append(name)
            }

            self.suffixOffsets = summarySuffixOffsets
            self.alphabetSize = currentName + 1
            self.bytes = summaryBytes
        }

        func makeSuffixArray() -> [Int] {
            if self.alphabetSize == self.bytes.count {
                var summarySuffixArray = Array(repeating: -1, count: self.bytes.count + 1)
                summarySuffixArray[0] = self.bytes.count

                for i in 0..<self.bytes.count {
                    let y = self.bytes[i]
                    summarySuffixArray[y + 1] = i
                }

                return summarySuffixArray
            } else {
                return SuffixArray.make(from: self.bytes, with: self.alphabetSize)
            }
        }

    }

    static func make(from bytes: [Int], with alphabetSize: Int) -> [Int] {
        let state = State(bytes: bytes, alphabetSize: alphabetSize)

        var guessedSuffixArray = guessLMSSort(state)
        induceSort(&guessedSuffixArray, state)

        let summary = Summary(guessedSuffixArray, state)
        let summarySuffixArray = summary.makeSuffixArray()

        var result = accurateLMSSort(summarySuffixArray, summary, state)
        induceSort(&result, state)

        return result
    }

    private static func isLMSChar(at offset: Int, _ state: State) -> Bool {
        if offset == 0 {
            return false
        }
        return state.typemap[offset] == .sType && state.typemap[offset - 1] == .lType
    }

    private static func lmsSubstringsAreEqual(_ offsetA: Int, _ offsetB: Int, _ state: State) -> Bool {
        if offsetA == state.input.count || offsetB == state.input.count {
            return false
        }

        var i = 0
        while true {
            let aIsLMS = isLMSChar(at: offsetA + i, state)
            let bIsLMS = isLMSChar(at: offsetB + i, state)

            if i > 0 && aIsLMS && bIsLMS { // We reached the ends of both LMS substrings.
                return true
            }

            if aIsLMS != bIsLMS { // We found the end of one LMS substring but not of the other.
                return false
            }

            if state.input[i + offsetA] != state.input[i + offsetB] { // We found different characters in substrings.
                return false
            }

            i += 1
        }
    }

    private static func guessLMSSort(_ state: State) -> [Int] {
        var result = Array(repeating: -1, count: state.input.count + 1)
        var bucketTails = state.bucketTails

        for i in 0..<state.input.count {
            if !isLMSChar(at: i, state) {
                continue
            }

            let bucketIndex = state.input[i]
            result[bucketTails[bucketIndex]] = i
            bucketTails[bucketIndex] -= 1
        }

        result[0] = state.input.count

        return result
    }

    private static func accurateLMSSort(_ summarySuffixArray: [Int], _ summary: Summary, _ state: State) -> [Int] {
        var suffixOffsets = Array(repeating: -1, count: state.input.count + 1)
        var bucketTails = state.bucketTails

        for i in stride(from: summarySuffixArray.count - 1, to: 1, by: -1) {
            let bytesIndex = summary.suffixOffsets[summarySuffixArray[i]]
            let bucketIndex = state.input[bytesIndex]
            suffixOffsets[bucketTails[bucketIndex]] = bytesIndex
            bucketTails[bucketIndex] -= 1
        }

        suffixOffsets[0] = state.input.count

        return suffixOffsets
    }

    private static func induceSort(_ guessedSuffixArray: inout [Int], _ state: State) {
        var bucketHeads = state.bucketHeads
        var bucketTails = state.bucketTails

        for i in 0..<guessedSuffixArray.count {
            let j = guessedSuffixArray[i] - 1
            guard j >= 0 && state.typemap[j] == .lType
                else { continue }

            let bucketIndex = state.input[j]
            guessedSuffixArray[bucketHeads[bucketIndex]] = j
            bucketHeads[bucketIndex] += 1
        }

        for i in stride(from: guessedSuffixArray.count - 1, through: 0, by: -1) {
            let j = guessedSuffixArray[i] - 1
            guard j >= 0 && state.typemap[j] == .sType
                else { continue }

            let bucketIndex = state.input[j]
            guessedSuffixArray[bucketTails[bucketIndex]] = j
            bucketTails[bucketIndex] -= 1
        }
    }

}
