// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression

extension FileSystemType: CustomStringConvertible {

    public var description: String {
        switch self {
        case .fat:
            return "FAT"
        case .macintosh:
            return "old Macintosh file system"
        case .ntfs:
            return "NTFS"
        case .unix:
            return "UNIX-like"
        case .other:
            return "other/unknown"
        }
    }

}
