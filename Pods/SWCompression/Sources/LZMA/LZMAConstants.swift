// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

struct LZMAConstants {
    static let topValue = 1 << 24
    static let numBitModelTotalBits = 11
    static let numMoveBits = 5
    static let probInitValue = (1 << numBitModelTotalBits) / 2
    static let numPosBitsMax = 4
    static let numStates = 12
    static let numLenToPosStates = 4
    static let numAlignBits = 4
    static let startPosModelIndex = 4
    static let endPosModelIndex = 14
    static let numFullDistances = 1 << (endPosModelIndex >> 1)
    static let matchMinLen = 2
    // LZMAConstants.numStates << LZMAConstants.numPosBitsMax = 192
}
