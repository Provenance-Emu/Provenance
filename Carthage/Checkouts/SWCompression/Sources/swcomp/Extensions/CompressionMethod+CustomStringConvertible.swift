// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression

extension CompressionMethod: CustomStringConvertible {

    public var description: String {
        switch self {
        case .bzip2:
            return "BZip2"
        case .copy:
            return "none"
        case .deflate:
            return "deflate"
        case .lzma:
            return "LZMA"
        case .lzma2:
            return "LZMA2"
        case .other:
            return "other/unknown"
        }
    }

}
