// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

public extension BZip2 {

    /**
     Represents size of blocks in which data is split during BZip2 compression.
     */
    public enum BlockSize: Int {
        /// 100 KB.
        case one = 1
        /// 200 KB.
        case two = 2
        /// 300 KB.
        case three = 3
        /// 400 KB.
        case four = 4
        /// 500 KB.
        case five = 5
        /// 600 KB.
        case six = 6
        /// 700 KB.
        case seven = 7
        /// 800 KB.
        case eight = 8
        /// 900 KB.
        case nine = 9

        init?(_ headerByte: UInt8) {
            switch headerByte {
            case 0x31:
                self = .one
            case 0x32:
                self = .two
            case 0x33:
                self = .three
            case 0x34:
                self = .four
            case 0x35:
                self = .five
            case 0x36:
                self = .six
            case 0x37:
                self = .seven
            case 0x38:
                self = .eight
            case 0x39:
                self = .nine
            default:
                return nil
            }
        }

        var headerByte: Int {
            return self.rawValue + 0x30
        }

        var sizeInKilobytes: Int {
            return self.rawValue * 100
        }

    }
}
