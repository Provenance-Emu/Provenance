// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents an entry from the ZIP container.
public struct ZipEntry: ContainerEntry {

    public let info: ZipEntryInfo

    public let data: Data?

    init(_ entryInfo: ZipEntryInfo, _ data: Data?) {
        self.info = entryInfo
        self.data = data
    }

}
