// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension FileSystemType {

    init(_ versionMadeBy: UInt16) {
        switch (versionMadeBy & 0xFF00) >> 8 {
        case 0, 14:
            self = .fat
        case 3:
            self = .unix
        case 7, 19:
            self = .macintosh
        case 10:
            self = .ntfs
        default:
            self = .other
        }
    }

}
