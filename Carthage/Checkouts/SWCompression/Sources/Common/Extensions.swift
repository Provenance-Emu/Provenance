// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension UnsignedInteger {

    @inline(__always)
    func toInt() -> Int {
        return Int(truncatingIfNeeded: self)
    }
}

extension Int {

    @inline(__always)
    func toUInt8() -> UInt8 {
        return UInt8(truncatingIfNeeded: UInt(self))
    }

    @inline(__always)
    func roundTo512() -> Int {
        if self >= Int.max - 510 {
            return Int.max
        } else {
            return (self + 511) & (~511)
        }
    }

    /// Returns an integer with reversed order of bits.
    func reversed(bits count: Int) -> Int {
        var a = 1 << 0
        var b = 1 << (count - 1)
        var z = 0
        for i in Swift.stride(from: count - 1, to: -1, by: -2) {
            z |= (self >> i) & a
            z |= (self << i) & b
            a <<= 1
            b >>= 1
        }
        return z
    }

}

extension Date {

    private static let ntfsReferenceDate = DateComponents(calendar: Calendar(identifier: .iso8601),
                                                          timeZone: TimeZone(abbreviation: "UTC"),
                                                          year: 1601, month: 1, day: 1,
                                                          hour: 0, minute: 0, second: 0).date!

    init(_ ntfsTime: UInt64) {
        self.init(timeInterval: TimeInterval(ntfsTime) / 10_000_000, since: .ntfsReferenceDate)
    }

}
