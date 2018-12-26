// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData
import SWCompression

struct TestZipExtraField: ZipExtraField {

    static let id: UInt16 = 0x0646

    let size: Int
    let location: ZipExtraFieldLocation

    var helloString: String?

    init(_ byteReader: ByteReader, _ size: Int, location: ZipExtraFieldLocation) {
        self.size = size
        self.location = location
        self.helloString = String(data: Data(bytes: byteReader.bytes(count: size)), encoding: .utf8)
    }

}
