// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

extension SevenZipCoder: Equatable {

    static func == (lhs: SevenZipCoder, rhs: SevenZipCoder) -> Bool {
        let propertiesEqual: Bool
        if lhs.properties == nil && rhs.properties == nil {
            propertiesEqual = true
        } else if lhs.properties != nil && rhs.properties != nil {
            propertiesEqual = lhs.properties! == rhs.properties!
        } else {
            propertiesEqual = false
        }
        return lhs.id == rhs.id && lhs.numInStreams == rhs.numInStreams &&
            lhs.numOutStreams == rhs.numOutStreams && propertiesEqual
    }

}
