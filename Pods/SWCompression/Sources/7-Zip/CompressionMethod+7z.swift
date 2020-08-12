// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension CompressionMethod {

    init(_ coderID: [UInt8]) {
        if coderID == [0x00] || coderID == [0x04, 0x01, 0x00] {
            self = .copy
        } else if coderID == [0x04, 0x01, 0x08] {
            self = .deflate
        } else if coderID == [0x04, 0x01, 0x0C] || coderID == [0x04, 0x02, 0x02] {
            self = .bzip2
        } else if coderID == [0x21] {
            self = .lzma2
        } else if coderID == [0x03, 0x01, 0x01] {
            self = .lzma
        } else {
            self = .other
        }
    }

}
