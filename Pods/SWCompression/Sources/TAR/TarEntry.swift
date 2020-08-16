// Copyright (c) 2020 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

/// Represents an entry from the TAR container.
public struct TarEntry: ContainerEntry {

    public var info: TarEntryInfo

    /**
     Entry's data (`nil` if entry is a directory or data isn't available).

     - Note: Accessing setter of this property causes `info.size` to be updated as well so it remains equal to
     `data.count`. If `data` is set to be `nil` then `info.size` is set to zero.
     */
    public var data: Data? {
        didSet {
            self.info.size = self.data?.count ?? 0
        }
    }

    /**
     Initializes the entry with its info and data. The stored `info.size` will also be updated to be equal to
     `data.count`. If `data` is `nil` then `info.size` will be set to zero.

     - Parameter info: Information about entry.
     - Parameter data: Entry's data; `nil` if entry is a directory or data isn't available.
     */
    public init(info: TarEntryInfo, data: Data?) {
        self.info = info
        self.info.size = data?.count ?? 0
        self.data = data
    }

    func generateContainerData() throws -> Data {
        var out = try self.info.generateContainerData()
        guard let data = self.data
            else { return out }
        out.append(data)
        let paddingSize = data.count.roundTo512() - data.count
        out.append(Data(count: paddingSize))
        return out
    }

}
