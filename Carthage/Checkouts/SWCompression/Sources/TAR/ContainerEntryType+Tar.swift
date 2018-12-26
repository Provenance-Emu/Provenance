// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension ContainerEntryType {

    init(_ fileTypeIndicator: UInt8) {
        switch fileTypeIndicator {
        case 0, 48: // "0"
            self = .regular
        case 49: // "1"
            self = .hardLink
        case 50: // "2"
            self = .symbolicLink
        case 51: // "3"
            self = .characterSpecial
        case 52: // "4"
            self = .blockSpecial
        case 53: // "5"
            self = .directory
        case 54: // "6"
            self = .fifo
        case 55: // "7"
            self = .contiguous
        default:
            self = .unknown
        }
    }

    var fileTypeIndicator: UInt8 {
        switch self {
        case .regular:
            return 48
        case .hardLink:
            return 49
        case .symbolicLink:
            return 50
        case .characterSpecial:
            return 51
        case .blockSpecial:
            return 52
        case .directory:
            return 53
        case .fifo:
            return 54
        case .contiguous:
            return 55
        case .socket:
            return 0
        case .unknown:
            return 0
        }
    }

}
