// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension FileSystemType {

    init(_ gzipOS: UInt8) {
        switch gzipOS {
        case 0:
            self = .fat
        case 3:
            self = .unix
        case 7:
            self = .macintosh
        case 11:
            self = .ntfs
        default:
            self = .other
        }
    }

    var osTypeByte: UInt8 {
        switch self {
        case .fat:
            return 0
        case .unix:
            return 3
        case .macintosh:
            return 7
        case .ntfs:
            return 11
        default:
            return 255
        }
    }

}
