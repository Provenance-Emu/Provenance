// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import BitByteData

// While it is tempting to make Provider conform to `IteratorProtocol` and `Sequence` protocols, it is in fact
// impossible to do so, since `TarEntryInfo.init(...)` is throwing and `IteratorProtocol.next()` cannot be throwing.
struct TarEntryInfoProvider {

    private let byteReader: ByteReader
    private var lastGlobalExtendedHeader: TarExtendedHeader?
    private var lastLocalExtendedHeader: TarExtendedHeader?
    private var longLinkName: String?
    private var longName: String?

    init(_ data: Data) {
        self.byteReader = ByteReader(data: data)
    }

    mutating func next() throws -> TarEntryInfo? {
        guard byteReader.bytesLeft >= 1024,
            byteReader.data[byteReader.offset..<byteReader.offset + 1024] != Data(count: 1024)
            else { return nil }

        let info = try TarEntryInfo(byteReader, lastGlobalExtendedHeader, lastLocalExtendedHeader,
                                    longName, longLinkName)
        let dataStartIndex = info.blockStartIndex + 512

        if let specialEntryType = info.specialEntryType {
            switch specialEntryType {
            case .globalExtendedHeader:
                let dataEndIndex = dataStartIndex + info.size!
                lastGlobalExtendedHeader = try TarExtendedHeader(byteReader.data[dataStartIndex..<dataEndIndex])
            case .sunExtendedHeader:
                fallthrough
            case .localExtendedHeader:
                let dataEndIndex = dataStartIndex + info.size!
                lastLocalExtendedHeader = try TarExtendedHeader(byteReader.data[dataStartIndex..<dataEndIndex])
            case .longLinkName:
                byteReader.offset = dataStartIndex
                longLinkName = byteReader.tarCString(maxLength: info.size!)
            case .longName:
                byteReader.offset = dataStartIndex
                longName = byteReader.tarCString(maxLength: info.size!)
            }
            byteReader.offset = dataStartIndex + info.size!.roundTo512()
        } else {
            // Skip file data.
            byteReader.offset = dataStartIndex + info.size!.roundTo512()
            lastLocalExtendedHeader = nil
            longName = nil
            longLinkName = nil
        }
        return info
    }

}
