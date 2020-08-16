// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents an entry from the 7-Zip container.
public struct SevenZipEntry: ContainerEntry {

    public let info: SevenZipEntryInfo

    public let data: Data?

    init(_ entryInfo: SevenZipEntryInfo, _ data: Data?) {
        self.info = entryInfo
        self.data = data
    }

}
