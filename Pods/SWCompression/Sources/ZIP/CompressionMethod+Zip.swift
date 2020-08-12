// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension CompressionMethod {

    init(_ compression: UInt16) {
        switch compression {
        case 0:
            self = .copy
        case 8:
            self = .deflate
        case 12:
            self = .bzip2
        case 14:
            self = .lzma
        default:
            self = .other
        }
    }

}
